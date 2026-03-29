class PriceRule {
  const PriceRule({
    required this.id,
    required this.productId,
    required this.ruleName,
    required this.discountPercent,
    required this.minQuantity,
    required this.maxQuantity,
    required this.validFrom,
    required this.validTo,
    required this.requiresApproval,
    required this.approvalLevel,
    required this.isActive,
  });

  final String id;
  final String productId;
  final String ruleName;
  final double discountPercent;
  final int minQuantity;
  final int maxQuantity;
  final DateTime validFrom;
  final DateTime validTo;
  final bool requiresApproval;
  final String approvalLevel; // 'auto', 'manager', 'director', 'vp'
  final bool isActive;

  bool get isCurrentlyValid {
    final now = DateTime.now();
    return isActive && now.isAfter(validFrom) && now.isBefore(validTo);
  }
}
