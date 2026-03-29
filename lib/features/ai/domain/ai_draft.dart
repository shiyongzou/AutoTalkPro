class AiDraftRequest {
  const AiDraftRequest({
    required this.customerName,
    required this.latestCustomerMessage,
    required this.goalStage,
    required this.style,
    required this.weeklySuggestion,
  });

  final String customerName;
  final String latestCustomerMessage;
  final String goalStage;
  final String style;
  final String weeklySuggestion;
}

class AiDraftResult {
  const AiDraftResult({
    required this.content,
    required this.provider,
    required this.model,
    this.rationale,
  });

  final String content;
  final String provider;
  final String model;
  final String? rationale;
}
