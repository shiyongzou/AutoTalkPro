import '../../../core/models/product.dart';
import '../../../core/models/price_rule.dart';
import '../domain/product_repository.dart';

class PriceQuote {
  const PriceQuote({
    required this.product,
    required this.originalPrice,
    required this.quotedPrice,
    required this.discountPercent,
    required this.appliedRule,
    required this.requiresApproval,
    required this.approvalLevel,
    required this.isAboveFloor,
  });

  final Product product;
  final double originalPrice;
  final double quotedPrice;
  final double discountPercent;
  final String? appliedRule;
  final bool requiresApproval;
  final String approvalLevel;
  final bool isAboveFloor;
}

class PricingEngine {
  const PricingEngine({required this.productRepository});
  final ProductRepository productRepository;

  /// 根据产品ID和数量，计算最优报价
  Future<PriceQuote?> computeQuote({
    required String productId,
    required int quantity,
    double? customerBudget,
  }) async {
    final product = await productRepository.getProduct(productId);
    if (product == null || !product.isActive) return null;

    final rules = await productRepository.getRulesForProduct(productId);
    final validRules = rules
        .where((r) => r.isCurrentlyValid)
        .where((r) => quantity >= r.minQuantity && quantity <= r.maxQuantity)
        .toList()
      ..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));

    if (validRules.isEmpty) {
      return PriceQuote(
        product: product,
        originalPrice: product.basePrice * quantity,
        quotedPrice: product.basePrice * quantity,
        discountPercent: 0,
        appliedRule: null,
        requiresApproval: false,
        approvalLevel: 'auto',
        isAboveFloor: true,
      );
    }

    // 如果客户有预算，选择最接近但不低于底价的规则
    PriceRule bestRule = validRules.first;
    if (customerBudget != null) {
      for (final rule in validRules) {
        final price = product.basePrice * (1 - rule.discountPercent / 100) * quantity;
        if (price <= customerBudget && price >= product.floorPrice * quantity) {
          bestRule = rule;
          break;
        }
      }
    }

    final quotedPrice = product.basePrice * (1 - bestRule.discountPercent / 100) * quantity;
    final isAboveFloor = quotedPrice >= product.floorPrice * quantity;

    return PriceQuote(
      product: product,
      originalPrice: product.basePrice * quantity,
      quotedPrice: quotedPrice,
      discountPercent: bestRule.discountPercent,
      appliedRule: bestRule.ruleName,
      requiresApproval: bestRule.requiresApproval,
      approvalLevel: bestRule.approvalLevel,
      isAboveFloor: isAboveFloor,
    );
  }

  /// 计算让步报价（在当前价格基础上给出一个让步）
  Future<PriceQuote?> computeConcession({
    required String productId,
    required int quantity,
    required double currentPrice,
    required int concessionStep,
  }) async {
    final product = await productRepository.getProduct(productId);
    if (product == null) return null;

    // 每次让步递减（第1次让5%，第2次让3%，第3次让2%…）
    final stepPercent = [5.0, 3.0, 2.0, 1.0, 0.5];
    final percent = concessionStep < stepPercent.length
        ? stepPercent[concessionStep]
        : 0.5;

    final concessionAmount = currentPrice * percent / 100;
    final newPrice = currentPrice - concessionAmount;
    final floorTotal = product.floorPrice * quantity;
    final actualPrice = newPrice < floorTotal ? floorTotal : newPrice;
    final totalDiscount = product.basePrice * quantity > 0
        ? (1 - actualPrice / (product.basePrice * quantity)) * 100
        : 0.0;

    final needsApproval = totalDiscount > 20;

    return PriceQuote(
      product: product,
      originalPrice: product.basePrice * quantity,
      quotedPrice: actualPrice,
      discountPercent: totalDiscount,
      appliedRule: '让步第${concessionStep + 1}步(-${percent.toStringAsFixed(1)}%)',
      requiresApproval: needsApproval,
      approvalLevel: needsApproval ? 'manager' : 'auto',
      isAboveFloor: actualPrice >= floorTotal,
    );
  }

  /// 格式化报价文本（给AI用）
  String formatQuoteForAi(PriceQuote quote) {
    final buf = StringBuffer();
    buf.writeln('产品: ${quote.product.name}');
    buf.writeln('原价: ¥${quote.originalPrice.toStringAsFixed(0)}');
    buf.writeln('报价: ¥${quote.quotedPrice.toStringAsFixed(0)}');
    if (quote.discountPercent > 0) {
      buf.writeln('折扣: ${quote.discountPercent.toStringAsFixed(1)}%');
    }
    if (quote.appliedRule != null) {
      buf.writeln('适用规则: ${quote.appliedRule}');
    }
    buf.writeln('底价保护: ${quote.isAboveFloor ? "通过" : "警告-已触底"}');
    if (quote.requiresApproval) {
      buf.writeln('需审批: ${quote.approvalLevel}级');
    }
    buf.writeln('产品亮点: ${quote.product.features.join('、')}');
    return buf.toString();
  }
}
