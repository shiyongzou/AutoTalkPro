enum EscalationPriority { low, medium, high, critical }

enum EscalationReason {
  riskDetected,
  highValueDeal,
  customerAngry,
  authorityExceeded,
  complexNegotiation,
  customerWaitingTooLong,
  priceFloorBreached,
  repeatedObjection,
  aiConfidenceLow,
  manualRequest,
}

enum EscalationStatus { pending, acknowledged, resolved, dismissed }

class EscalationAlert {
  const EscalationAlert({
    required this.id,
    required this.conversationId,
    required this.customerId,
    required this.reason,
    required this.priority,
    required this.status,
    required this.title,
    required this.detail,
    required this.suggestedAction,
    this.resolvedBy,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String conversationId;
  final String customerId;
  final EscalationReason reason;
  final EscalationPriority priority;
  final EscalationStatus status;
  final String title;
  final String detail;
  final String suggestedAction;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  EscalationAlert copyWith({
    EscalationStatus? status,
    String? resolvedBy,
    DateTime? resolvedAt,
    DateTime? updatedAt,
  }) {
    return EscalationAlert(
      id: id,
      conversationId: conversationId,
      customerId: customerId,
      reason: reason,
      priority: priority,
      status: status ?? this.status,
      title: title,
      detail: detail,
      suggestedAction: suggestedAction,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => status == EscalationStatus.pending;
}
