enum ChannelType { telegram, wecom, wechat }

class ChannelChatSummary {
  const ChannelChatSummary({
    required this.channel,
    required this.peerId,
    required this.title,
    required this.lastMessagePreview,
    required this.lastMessageAt,
  });

  final ChannelType channel;
  final String peerId;
  final String title;
  final String lastMessagePreview;
  final DateTime lastMessageAt;
}

class ChannelHealthStatus {
  const ChannelHealthStatus({
    required this.channel,
    required this.healthy,
    required this.message,
    required this.checkedAt,
    this.details = const {},
  });

  final ChannelType channel;
  final bool healthy;
  final String message;
  final DateTime checkedAt;
  final Map<String, dynamic> details;
}

abstract class ChannelAdapter {
  ChannelType get channelType;

  String get displayName;

  Future<List<ChannelChatSummary>> listChats();

  Future<bool> sendMessage({required String peerId, required String text});

  Future<ChannelHealthStatus> healthCheck();
}
