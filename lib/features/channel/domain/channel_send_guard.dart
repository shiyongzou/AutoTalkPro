class ChannelSendGuardResult {
  const ChannelSendGuardResult._({
    required this.allowed,
    this.reason,
    this.details = const {},
  });

  factory ChannelSendGuardResult.allow({
    Map<String, dynamic> details = const {},
  }) {
    return ChannelSendGuardResult._(allowed: true, details: details);
  }

  factory ChannelSendGuardResult.block(
    String reason, {
    Map<String, dynamic> details = const {},
  }) {
    return ChannelSendGuardResult._(
      allowed: false,
      reason: reason,
      details: details,
    );
  }

  final bool allowed;
  final String? reason;
  final Map<String, dynamic> details;
}

abstract class ChannelSendGuard {
  Future<ChannelSendGuardResult> checkBeforeSend({
    required String peerId,
    required String text,
  });
}
