class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.basePrice,
    required this.floorPrice,
    required this.unit,
    required this.features,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.transactionType = 'oneTime',
    this.stock,
    this.deliveryMethod = 'digital',
    this.tags = const [],
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final double basePrice;
  final double floorPrice;
  final String unit;
  final List<String> features;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // V3: 交易扩展字段
  final String transactionType; // 'subscription', 'oneTime', 'negotiable'
  final int? stock; // null = 不限库存
  final String deliveryMethod; // 'digital', 'physical', 'service', 'instant'
  final List<String> tags; // 额外标签用于搜索匹配

  double get discountFloorPercent =>
      basePrice > 0 ? (floorPrice / basePrice * 100) : 100;

  bool get hasStock => stock == null || stock! > 0;
  bool get isNegotiable => transactionType == 'negotiable';
}
