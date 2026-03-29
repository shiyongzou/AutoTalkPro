import 'dart:convert';
import 'dart:io';

import '../../channel/domain/channel_adapter.dart';
import '../domain/wechat_bot_config.dart';

/// 微信机器人适配器 — 基于 wechatbot-webhook HTTP API
class WeChatBotAdapter implements ChannelAdapter {
  WeChatBotAdapter({required this.config});

  final WeChatBotConfig config;

  @override
  ChannelType get channelType => ChannelType.wechat;

  @override
  String get displayName => '微信';

  @override
  Future<List<ChannelChatSummary>> listChats() async => const [];

  /// 用dart:io发请求，避免http包的latin1编码问题
  Future<Map<String, dynamic>?> _post(String url, Map<String, dynamic> body) async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close().timeout(const Duration(seconds: 15));
      final bytes = await response.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
      client.close();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      }
      // ignore: avoid_print
      print('[WeChatAdapter] HTTP ${response.statusCode}: ${utf8.decode(bytes)}');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('[WeChatAdapter] _post异常: $e');
      return null;
    }
  }

  @override
  Future<bool> sendMessage({required String peerId, required String text}) async {
    if (!config.enabled || config.token.isEmpty) {
      // ignore: avoid_print
      print('[WeChatAdapter] 发送跳过: enabled=${config.enabled} tokenEmpty=${config.token.isEmpty}');
      return false;
    }
    // room:前缀 = 群消息
    final isRoom = peerId.startsWith('room:');
    final actualTo = isRoom ? peerId.substring(5) : peerId;
    final body = {
      'to': actualTo,
      'isRoom': isRoom,
      'data': {'type': 'text', 'content': text},
    };
    // ignore: avoid_print
    print('[WeChatAdapter] POST ${config.sendUrl} → to=$actualTo isRoom=$isRoom textLen=${text.length}');
    final result = await _post(config.sendUrl, body);
    // ignore: avoid_print
    print('[WeChatAdapter] 响应: $result');
    return result?['success'] == true;
  }

  /// 发送文件/图片
  Future<bool> sendFileUrl({required String peerId, required String fileUrl, bool isRoom = false}) async {
    if (!config.enabled || config.token.isEmpty) return false;
    final result = await _post(config.sendUrl, {
      'to': peerId,
      'isRoom': isRoom,
      'data': {'type': 'fileUrl', 'content': fileUrl},
    });
    return result?['success'] == true;
  }

  /// 群发
  Future<bool> broadcast({required List<String> recipients, required String text}) async {
    if (!config.enabled || config.token.isEmpty) return false;
    final body = recipients.map((to) => {
      'to': to,
      'data': {'type': 'text', 'content': text},
    }).toList();
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(config.sendUrl));
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close().timeout(const Duration(seconds: 30));
      final bytes = await response.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
      client.close();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(bytes));
        return decoded['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ChannelHealthStatus> healthCheck() async {
    final now = DateTime.now();
    if (!config.enabled || config.token.isEmpty) {
      return ChannelHealthStatus(channel: ChannelType.wechat, healthy: false, message: '微信未配置', checkedAt: now);
    }
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(config.healthUrl));
      final response = await request.close().timeout(const Duration(seconds: 5));
      final bytes = await response.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
      client.close();
      final body = utf8.decode(bytes);
      final isHealthy = body.contains('healthy');
      return ChannelHealthStatus(channel: ChannelType.wechat, healthy: isHealthy, message: isHealthy ? '微信在线' : '微信离线', checkedAt: now);
    } catch (_) {
      return ChannelHealthStatus(channel: ChannelType.wechat, healthy: false, message: '连接失败', checkedAt: now);
    }
  }
}
