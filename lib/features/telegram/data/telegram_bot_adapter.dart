import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../channel/domain/channel_adapter.dart';

/// Telegram Bot API 配置
class TelegramBotConfig {
  const TelegramBotConfig({
    required this.botToken,
    this.apiBase = 'https://api.telegram.org',
    this.enabled = false,
  });

  final String botToken;
  final String apiBase;
  final bool enabled;

  String get baseUrl => '$apiBase/bot$botToken';

  static TelegramBotConfig defaults() =>
      const TelegramBotConfig(botToken: '', enabled: false);
}

/// Telegram Bot API 消息
class TgBotMessage {
  const TgBotMessage({
    required this.updateId,
    required this.chatId,
    required this.fromId,
    required this.fromName,
    required this.text,
    required this.date,
  });

  final int updateId;
  final int chatId;
  final int fromId;
  final String fromName;
  final String text;
  final DateTime date;
}

/// Telegram Bot API 适配器 — 真正收发消息
class TelegramBotAdapter implements ChannelAdapter {
  TelegramBotAdapter({required this.config, http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final TelegramBotConfig config;
  final http.Client _client;
  int _lastUpdateId = 0;

  @override
  ChannelType get channelType => ChannelType.telegram;

  @override
  String get displayName => 'Telegram';

  @override
  Future<List<ChannelChatSummary>> listChats() async {
    // Bot API 不支持列出所有聊天，返回最近收到消息的聊天
    final messages = await getUpdates();
    final seen = <int>{};
    final chats = <ChannelChatSummary>[];
    for (final msg in messages) {
      if (seen.add(msg.chatId)) {
        chats.add(
          ChannelChatSummary(
            channel: ChannelType.telegram,
            peerId: msg.chatId.toString(),
            title: msg.fromName,
            lastMessagePreview: msg.text.length > 50
                ? '${msg.text.substring(0, 50)}...'
                : msg.text,
            lastMessageAt: msg.date,
          ),
        );
      }
    }
    return chats;
  }

  @override
  Future<bool> sendMessage({
    required String peerId,
    required String text,
  }) async {
    if (!config.enabled || config.botToken.isEmpty) return false;

    try {
      final response = await _client
          .post(
            Uri.parse('${config.baseUrl}/sendMessage'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'chat_id': peerId, 'text': text}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['ok'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 拉取新消息（长轮询）
  Future<List<TgBotMessage>> getUpdates({int timeout = 5}) async {
    if (!config.enabled || config.botToken.isEmpty) return const [];

    try {
      final params = {
        'offset': (_lastUpdateId + 1).toString(),
        'timeout': timeout.toString(),
        'allowed_updates': '["message"]',
      };

      final response = await _client
          .get(
            Uri.parse(
              '${config.baseUrl}/getUpdates',
            ).replace(queryParameters: params),
          )
          .timeout(Duration(seconds: timeout + 10));

      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(response.body);
      if (decoded['ok'] != true) return const [];

      final results = <TgBotMessage>[];
      final updates = decoded['result'] as List;

      for (final update in updates) {
        final updateId = update['update_id'] as int;
        if (updateId > _lastUpdateId) _lastUpdateId = updateId;

        final message = update['message'];
        if (message == null) continue;

        final chat = message['chat'];
        final from = message['from'];
        final text = message['text'];
        if (chat == null || text == null) continue;

        results.add(
          TgBotMessage(
            updateId: updateId,
            chatId: chat['id'] as int,
            fromId: from?['id'] as int? ?? 0,
            fromName: from?['first_name'] as String? ?? 'Unknown',
            text: text as String,
            date: DateTime.fromMillisecondsSinceEpoch(
              (message['date'] as int) * 1000,
            ),
          ),
        );
      }

      return results;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<ChannelHealthStatus> healthCheck() async {
    final now = DateTime.now();
    if (!config.enabled || config.botToken.isEmpty) {
      return ChannelHealthStatus(
        channel: ChannelType.telegram,
        healthy: false,
        message: 'Telegram Bot 未配置',
        checkedAt: now,
      );
    }

    try {
      final response = await _client
          .get(Uri.parse('${config.baseUrl}/getMe'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['ok'] == true) {
          final botName = decoded['result']?['first_name'] ?? 'Bot';
          return ChannelHealthStatus(
            channel: ChannelType.telegram,
            healthy: true,
            message: 'Telegram Bot 在线 ($botName)',
            checkedAt: now,
          );
        }
      }
      return ChannelHealthStatus(
        channel: ChannelType.telegram,
        healthy: false,
        message: 'Telegram Bot API 响应异常',
        checkedAt: now,
      );
    } catch (e) {
      return ChannelHealthStatus(
        channel: ChannelType.telegram,
        healthy: false,
        message: '连接失败: $e',
        checkedAt: now,
      );
    }
  }
}
