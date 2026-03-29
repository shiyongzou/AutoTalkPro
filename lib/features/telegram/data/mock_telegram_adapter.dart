import '../../channel/domain/channel_adapter.dart';
import '../domain/telegram_adapter.dart';

class MockTelegramAdapter implements TelegramAdapter {
  const MockTelegramAdapter();

  @override
  ChannelType get channelType => ChannelType.telegram;

  @override
  String get displayName => 'Telegram Mock';

  @override
  Future<List<TelegramChatSummary>> listChats() async {
    final now = DateTime.now();
    return [
      ChannelChatSummary(
        channel: channelType,
        peerId: 'tg_1001',
        title: '客户A',
        lastMessagePreview: '今天能给报价吗？',
        lastMessageAt: now.subtract(const Duration(minutes: 12)),
      ),
      ChannelChatSummary(
        channel: channelType,
        peerId: 'tg_1002',
        title: '客户B',
        lastMessagePreview: '我需要看一个案例',
        lastMessageAt: now.subtract(const Duration(hours: 1, minutes: 5)),
      ),
    ];
  }

  @override
  Future<bool> sendMessage({
    required String peerId,
    required String text,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return text.trim().isNotEmpty && peerId.trim().isNotEmpty;
  }

  @override
  Future<ChannelHealthStatus> healthCheck() async {
    return ChannelHealthStatus(
      channel: channelType,
      healthy: true,
      message: 'Telegram Mock 运行正常',
      checkedAt: DateTime.now(),
      details: const {'mode': 'mock'},
    );
  }
}
