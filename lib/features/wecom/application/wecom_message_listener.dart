import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/logging/support_logger.dart';
import '../domain/wecom_config.dart';

class WeComIncomingMessage {
  const WeComIncomingMessage({
    required this.msgType,
    required this.content,
    required this.fromUserId,
    required this.toUserId,
    required this.agentId,
    required this.msgId,
    required this.rawPayload,
  });

  final String msgType;
  final String content;
  final String fromUserId;
  final String toUserId;
  final String agentId;
  final String msgId;
  final Map<String, dynamic> rawPayload;

  bool get isText => msgType == 'text';
}

/// 企业微信回调监听器（最小可用版）
///
/// 支持两种输入：
/// 1) 官方XML回调（明文）
/// 2) JSON透传（便于本地联调/中转）
class WeComMessageListener {
  WeComMessageListener({required this.config});

  WeComConfig config;
  HttpServer? _server;
  final _controller = StreamController<WeComIncomingMessage>.broadcast();

  Stream<WeComIncomingMessage> get messages => _controller.stream;

  String get callbackPath => config.callbackPath.trim().isEmpty
      ? '/wecom/callback'
      : config.callbackPath.trim();

  String get callbackUrl =>
      'http://127.0.0.1:${config.callbackPort}$callbackPath';

  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        config.callbackPort,
        shared: true,
      );
      _server!.listen(_handleRequest);
      await SupportLogger.log(
        'wecom.listener',
        'listener_started',
        extra: {
          'callbackUrl': callbackUrl,
          'callbackPath': callbackPath,
          'port': config.callbackPort,
        },
      );
    } catch (e) {
      await SupportLogger.log(
        'wecom.listener',
        'listener_start_failed',
        extra: {'error': e.toString(), 'port': config.callbackPort},
      );
      rethrow;
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path != callbackPath) {
      request.response
        ..statusCode = 404
        ..write('not found')
        ..close();
      return;
    }

    // URL验证（最小实现：原样回显echostr）
    if (request.method == 'GET') {
      final echostr = request.uri.queryParameters['echostr'];
      request.response
        ..statusCode = 200
        ..write(echostr ?? 'ok')
        ..close();
      return;
    }

    if (request.method != 'POST') {
      request.response
        ..statusCode = 405
        ..write('method not allowed')
        ..close();
      return;
    }

    try {
      final rawBody = await utf8.decoder.bind(request).join();
      final contentType = request.headers.contentType?.mimeType ?? '';

      final parsed = contentType.contains('json')
          ? _parseJsonPayload(rawBody)
          : _parseXmlPayload(rawBody);

      if (parsed == null) {
        await SupportLogger.log(
          'wecom.listener',
          'incoming_ignored',
          extra: {
            'reason': 'unsupported_payload',
            'contentType': contentType,
            'bodyPreview': rawBody.length > 120
                ? '${rawBody.substring(0, 120)}...'
                : rawBody,
          },
        );
      } else {
        _controller.add(parsed);
        await SupportLogger.log(
          'wecom.listener',
          'incoming_parsed',
          extra: {
            'msgType': parsed.msgType,
            'fromUserId': parsed.fromUserId,
            'toUserId': parsed.toUserId,
            'agentId': parsed.agentId,
            'msgId': parsed.msgId,
            'contentPreview': parsed.content.length > 80
                ? '${parsed.content.substring(0, 80)}...'
                : parsed.content,
          },
        );
      }

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.text
        ..write('success')
        ..close();
    } catch (e) {
      await SupportLogger.log(
        'wecom.listener',
        'incoming_parse_error',
        extra: {'error': e.toString()},
      );
      request.response
        ..statusCode = 500
        ..write('error: $e')
        ..close();
    }
  }

  WeComIncomingMessage? _parseJsonPayload(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;

    final msgType =
        decoded['MsgType']?.toString() ??
        decoded['msgType']?.toString() ??
        'unknown';
    final content =
        decoded['Content']?.toString() ?? decoded['content']?.toString() ?? '';
    final fromUserId =
        decoded['FromUserName']?.toString() ??
        decoded['fromUserId']?.toString() ??
        '';
    final toUserId =
        decoded['ToUserName']?.toString() ??
        decoded['toUserId']?.toString() ??
        '';
    final agentId =
        decoded['AgentID']?.toString() ??
        decoded['agentId']?.toString() ??
        config.agentId;
    final msgId =
        decoded['MsgId']?.toString() ??
        decoded['msgId']?.toString() ??
        'json_${DateTime.now().microsecondsSinceEpoch}';

    return WeComIncomingMessage(
      msgType: msgType,
      content: content,
      fromUserId: fromUserId,
      toUserId: toUserId,
      agentId: agentId,
      msgId: msgId,
      rawPayload: decoded,
    );
  }

  WeComIncomingMessage? _parseXmlPayload(String body) {
    final msgType = _xmlValue(body, 'MsgType') ?? 'unknown';
    final content = _xmlValue(body, 'Content') ?? '';
    final fromUserId = _xmlValue(body, 'FromUserName') ?? '';
    final toUserId = _xmlValue(body, 'ToUserName') ?? '';
    final agentId = _xmlValue(body, 'AgentID') ?? config.agentId;
    final msgId =
        _xmlValue(body, 'MsgId') ??
        'xml_${DateTime.now().microsecondsSinceEpoch}';

    // 排除事件回调（如关注/取消关注），最小版只关心文本消息
    if (msgType == 'event') {
      return null;
    }

    return WeComIncomingMessage(
      msgType: msgType,
      content: content,
      fromUserId: fromUserId,
      toUserId: toUserId,
      agentId: agentId,
      msgId: msgId,
      rawPayload: {
        'rawXml': body,
        'MsgType': msgType,
        'Content': content,
        'FromUserName': fromUserId,
        'ToUserName': toUserId,
        'AgentID': agentId,
        'MsgId': msgId,
      },
    );
  }

  String? _xmlValue(String xml, String tag) {
    final cdata = RegExp(
      '<$tag><!\\[CDATA\\[(.*?)\\]\\]></$tag>',
      dotAll: true,
    ).firstMatch(xml)?.group(1);
    if (cdata != null) return cdata.trim();

    final plain = RegExp(
      '<$tag>(.*?)</$tag>',
      dotAll: true,
    ).firstMatch(xml)?.group(1);
    return plain?.trim();
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  void updateConfig(WeComConfig newConfig) {
    config = newConfig;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
