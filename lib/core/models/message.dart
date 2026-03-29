class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.sentAt,
    required this.riskFlag,
    this.metadata,
  });

  final String id;
  final String conversationId;
  final String role;
  final String content;
  final DateTime sentAt;
  final bool riskFlag;
  final Map<String, dynamic>? metadata;
}
