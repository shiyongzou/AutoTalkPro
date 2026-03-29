enum NegotiationStage {
  opening,
  exploring,
  proposing,
  countering,
  closing,
  won,
  lost,
  stalled,
}

class NegotiationContext {
  const NegotiationContext({
    required this.id,
    required this.conversationId,
    required this.customerId,
    required this.stage,
    required this.productIds,
    required this.customerBudgetLow,
    required this.customerBudgetHigh,
    required this.ourOfferPrice,
    required this.customerOfferPrice,
    required this.concessionCount,
    required this.maxConcessions,
    required this.dealScore,
    required this.keyObjections,
    required this.agreedTerms,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String conversationId;
  final String customerId;
  final NegotiationStage stage;
  final List<String> productIds;
  final double? customerBudgetLow;
  final double? customerBudgetHigh;
  final double? ourOfferPrice;
  final double? customerOfferPrice;
  final int concessionCount;
  final int maxConcessions;
  final double dealScore; // 0.0 ~ 1.0
  final List<String> keyObjections;
  final List<String> agreedTerms;
  final DateTime createdAt;
  final DateTime updatedAt;

  NegotiationContext copyWith({
    NegotiationStage? stage,
    double? customerBudgetLow,
    double? customerBudgetHigh,
    double? ourOfferPrice,
    double? customerOfferPrice,
    int? concessionCount,
    double? dealScore,
    List<String>? keyObjections,
    List<String>? agreedTerms,
    DateTime? updatedAt,
  }) {
    return NegotiationContext(
      id: id,
      conversationId: conversationId,
      customerId: customerId,
      stage: stage ?? this.stage,
      productIds: productIds,
      customerBudgetLow: customerBudgetLow ?? this.customerBudgetLow,
      customerBudgetHigh: customerBudgetHigh ?? this.customerBudgetHigh,
      ourOfferPrice: ourOfferPrice ?? this.ourOfferPrice,
      customerOfferPrice: customerOfferPrice ?? this.customerOfferPrice,
      concessionCount: concessionCount ?? this.concessionCount,
      maxConcessions: maxConcessions,
      dealScore: dealScore ?? this.dealScore,
      keyObjections: keyObjections ?? this.keyObjections,
      agreedTerms: agreedTerms ?? this.agreedTerms,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get canConcede => concessionCount < maxConcessions;

  bool get isTerminal =>
      stage == NegotiationStage.won || stage == NegotiationStage.lost;
}
