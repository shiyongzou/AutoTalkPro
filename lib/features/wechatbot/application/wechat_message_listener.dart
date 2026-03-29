import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/logging/support_logger.dart';

/// 微信收到的消息
class WeChatIncomingMessage {
  const WeChatIncomingMessage({
    required this.type,
    required this.content,
    required this.fromId,
    required this.fromName,
    required this.roomId,
    required this.roomName,
    required this.isMentioned,
    required this.isSelf,
    required this.rawSource,
  });

  final String type; // text, file, urlLink, friendship, unknown
  final String content; // 文本内容
  final String fromId; // 发送者ID
  final String fromName; // 发送者昵称
  final String? roomId; // 群ID（私聊为null）
  final String? roomName; // 群名
  final bool isMentioned; // 是否@了机器人
  final bool isSelf; // 是否自己发的
  final Map<String, dynamic> rawSource;

  bool get isPrivate => roomId == null || roomId!.isEmpty;
  bool get isText => type == 'text';
  bool get isFriendRequest => type == 'friendship';
}

/// 本地HTTP服务器，接收wechatbot-webhook的消息回调
class WeChatMessageListener {
  WeChatMessageListener({this.callbackPort = 3002});

  final int callbackPort;
  HttpServer? _server;
  final _controller = StreamController<WeChatIncomingMessage>.broadcast();

  /// 消息流——UI和autopilot订阅这个
  Stream<WeChatIncomingMessage> get messages => _controller.stream;

  /// 回调URL（告诉wechatbot-webhook把消息POST到这里）
  String get callbackUrl => 'http://localhost:$callbackPort/callback';

  /// 启动本地回调服务器
  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        callbackPort,
        shared: true,
      );
      _server!.listen(_handleRequest);
      await SupportLogger.log(
        'wechat.listener',
        'listener_started',
        extra: {'callbackUrl': callbackUrl, 'port': callbackPort},
      );
    } catch (e) {
      // 端口已被占用（上次没关干净），忽略
      await SupportLogger.log(
        'wechat.listener',
        'listener_start_failed',
        extra: {'error': e.toString(), 'port': callbackPort},
      );
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // ignore: avoid_print
    print(
      '[WeChatListener] ${request.method} ${request.uri.path} from ${request.connectionInfo?.remoteAddress.address}',
    );

    if (request.method != 'POST' || request.uri.path != '/callback') {
      request.response
        ..statusCode = 404
        ..write('not found')
        ..close();
      return;
    }

    try {
      // wechatbot-webhook 发的是 multipart/form-data
      final contentType = request.headers.contentType;
      String? type;
      String? content;
      String? sourceJson;
      String? isMentioned;
      String? isMsgFromSelf;

      if (contentType?.mimeType == 'multipart/form-data') {
        // 解析multipart
        final boundary = contentType!.parameters['boundary']!;
        final body = await utf8.decoder.bind(request).join();
        final parts = body.split('--$boundary');

        for (final part in parts) {
          if (part.contains('name="type"')) {
            type = _extractFormValue(part);
          } else if (part.contains('name="content"')) {
            content = _extractFormValue(part);
          } else if (part.contains('name="source"')) {
            sourceJson = _extractFormValue(part);
          } else if (part.contains('name="isMentioned"')) {
            isMentioned = _extractFormValue(part);
          } else if (part.contains('name="isMsgFromSelf"')) {
            isMsgFromSelf = _extractFormValue(part);
          }
        }
      } else {
        // JSON fallback
        final body = await utf8.decoder.bind(request).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        type = json['type']?.toString();
        content = json['content']?.toString();
        sourceJson = json['source']?.toString();
        isMentioned = json['isMentioned']?.toString();
        isMsgFromSelf = json['isMsgFromSelf']?.toString();
      }

      // 解析source
      Map<String, dynamic> source = {};
      if (sourceJson != null && sourceJson.isNotEmpty) {
        try {
          source = jsonDecode(sourceJson) as Map<String, dynamic>;
        } catch (_) {}
      }

      final from = source['from'] as Map<String, dynamic>? ?? {};
      final fromPayload = from['payload'] as Map<String, dynamic>? ?? {};
      final room = source['room'];
      final roomData = room is Map<String, dynamic> ? room : null;
      final roomPayload = roomData?['payload'] as Map<String, dynamic>? ?? {};

      final sourceMentioned = source['isMentioned'];
      final sourceIsSelf = source['isMsgFromSelf'];
      final roomIdRaw = roomData?['id']?.toString();
      final roomId =
          (roomIdRaw == null ||
              roomIdRaw.isEmpty ||
              roomIdRaw == 'null' ||
              roomIdRaw == 'undefined')
          ? null
          : roomIdRaw;

      // 发送时需要用 alias(wxid) 或 name，而不是内部哈希ID
      // wechatbot-webhook 按 name/alias 查找联系人
      final fromAlias = fromPayload['alias']?.toString() ?? '';
      final fromName = fromPayload['name']?.toString() ?? '';
      final fromIdRaw = from['id']?.toString() ?? '';
      // 优先用alias(wxid)，其次name，最后才用内部id
      final effectiveFromId = fromAlias.isNotEmpty
          ? fromAlias
          : fromName.isNotEmpty
          ? fromName
          : fromIdRaw;

      // 群名：先从 payload.topic，再从顶层 topic
      final roomTopic =
          roomPayload['topic']?.toString() ?? roomData?['topic']?.toString();

      // ignore: avoid_print
      print(
        '[WeChatListener] from解析: id=$fromIdRaw alias=$fromAlias name=$fromName → effectiveId=$effectiveFromId roomTopic=$roomTopic',
      );

      final message = WeChatIncomingMessage(
        type: type ?? 'unknown',
        content: content ?? '',
        fromId: effectiveFromId,
        fromName: fromName.isNotEmpty ? fromName : fromAlias,
        roomId: roomId,
        roomName: roomTopic,
        isMentioned: _parseBool(isMentioned) || _parseBool(sourceMentioned),
        isSelf: _parseBool(isMsgFromSelf) || _parseBool(sourceIsSelf),
        rawSource: source,
      );

      await SupportLogger.log(
        'wechat.listener',
        'incoming_parsed',
        extra: {
          'type': message.type,
          'isPrivate': message.isPrivate,
          'isMentioned': message.isMentioned,
          'isSelf': message.isSelf,
          'fromId': message.fromId,
          'roomId': message.roomId,
          'contentPreview': message.content.length > 80
              ? '${message.content.substring(0, 80)}...'
              : message.content,
        },
      );

      // ignore: avoid_print
      print(
        '[WeChatListener] 解析完成: type=${message.type} isPrivate=${message.isPrivate} isMentioned=${message.isMentioned} isSelf=${message.isSelf} fromId=${message.fromId} roomId=${message.roomId} content=${message.content.length > 50 ? message.content.substring(0, 50) : message.content}',
      );

      // 不处理自己发的消息
      if (!message.isSelf) {
        // ignore: avoid_print
        print('[WeChatListener] → 转发到消息流');
        _controller.add(message);
      } else {
        await SupportLogger.log(
          'wechat.listener',
          'incoming_ignored_self',
          extra: {'fromId': message.fromId, 'roomId': message.roomId},
        );
      }

      // 返回成功（不自动回复，由autopilot处理）
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'success': true}))
        ..close();
    } catch (e) {
      await SupportLogger.log(
        'wechat.listener',
        'incoming_parse_error',
        extra: {'error': e.toString()},
      );
      request.response
        ..statusCode = 500
        ..write('error: $e')
        ..close();
    }
  }

  String _extractFormValue(String part) {
    // multipart form data: header\r\n\r\nvalue\r\n
    final idx = part.indexOf('\r\n\r\n');
    if (idx == -1) return '';
    return part.substring(idx + 4).trim();
  }

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    final v = value.toString().trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes' || v == 'y';
  }

  /// 停止服务器
  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
