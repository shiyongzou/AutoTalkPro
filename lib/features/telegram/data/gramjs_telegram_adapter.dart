import '../../channel/domain/channel_adapter.dart';
import '../application/telegram_service_manager.dart';

/// 真实的Telegram适配器——通过本地GramJS服务收发消息
class GramJsTelegramAdapter implements ChannelAdapter {
  GramJsTelegramAdapter({TelegramServiceManager? manager})
    : _manager = manager ?? TelegramServiceManager();

  final TelegramServiceManager _manager;

  @override
  ChannelType get channelType => ChannelType.telegram;

  @override
  String get displayName => 'Telegram';

  @override
  Future<List<ChannelChatSummary>> listChats() async {
    return const [];
  }

  @override
  Future<bool> sendMessage({
    required String peerId,
    required String text,
  }) async {
    return _manager.sendMessage(peerId: peerId, text: text);
  }

  @override
  Future<ChannelHealthStatus> healthCheck() async {
    final now = DateTime.now();
    final running = await _manager.isRunning();
    if (!running) {
      return ChannelHealthStatus(
        channel: ChannelType.telegram,
        healthy: false,
        message: 'Telegram服务未运行',
        checkedAt: now,
      );
    }
    final loggedIn = await _manager.isLoggedIn();
    return ChannelHealthStatus(
      channel: ChannelType.telegram,
      healthy: loggedIn,
      message: loggedIn ? 'Telegram已连接' : 'Telegram未登录',
      checkedAt: now,
    );
  }
}
