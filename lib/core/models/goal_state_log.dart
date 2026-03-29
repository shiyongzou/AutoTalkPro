class GoalStateLog {
  const GoalStateLog({
    required this.id,
    required this.conversationId,
    required this.stage,
    required this.event,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String stage;
  final String event;
  final String note;
  final DateTime createdAt;
}
