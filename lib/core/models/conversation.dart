class Conversation {
  const Conversation({
    required this.id,
    required this.customerId,
    required this.title,
    required this.status,
    required this.goalStage,
    required this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
    this.autopilotMode = 'manual',
    this.negotiationId,
  });

  final String id;
  final String customerId;
  final String title;
  final String status;
  final String goalStage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String autopilotMode; // 'manual', 'semiAuto', 'auto'
  final String? negotiationId;

  Conversation copyWith({
    String? title,
    String? status,
    String? goalStage,
    DateTime? lastMessageAt,
    DateTime? updatedAt,
    String? autopilotMode,
    String? negotiationId,
  }) {
    return Conversation(
      id: id,
      customerId: customerId,
      title: title ?? this.title,
      status: status ?? this.status,
      goalStage: goalStage ?? this.goalStage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      autopilotMode: autopilotMode ?? this.autopilotMode,
      negotiationId: negotiationId ?? this.negotiationId,
    );
  }
}
