class AuditLog {
  const AuditLog({
    required this.id,
    required this.conversationId,
    required this.stage,
    required this.status,
    required this.detail,
    required this.createdAt,
    this.requestId,
    this.operator,
    this.channel,
    this.templateVersion,
    this.model,
    this.latencyMs,
  });

  final String id;
  final String conversationId;
  final String stage;
  final String status;
  final Map<String, dynamic> detail;
  final DateTime createdAt;
  final String? requestId;
  final String? operator;
  final String? channel;
  final String? templateVersion;
  final String? model;
  final int? latencyMs;
}

class AuditQuery {
  const AuditQuery({
    this.conversationId,
    this.requestId,
    this.channel,
    this.stage,
    this.status,
    this.limit = 50,
  });

  final String? conversationId;
  final String? requestId;
  final String? channel;
  final String? stage;
  final String? status;
  final int limit;
}
