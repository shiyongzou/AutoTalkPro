import '../../../core/models/business_profile.dart';
import '../../../core/models/message.dart';
import '../../../core/models/product.dart';
import '../../product/domain/product_repository.dart';

class QuickQuoteResult {
  const QuickQuoteResult({
    required this.matched,
    this.product,
    this.replyText,
    this.confidence,
  });

  final bool matched;
  final Product? product;
  final String? replyText;
  final double? confidence;
}

class QuickQuoteService {
  const QuickQuoteService({required this.productRepository});
  final ProductRepository productRepository;

  /// 检测消息是否为询价，如果是则自动匹配产品并生成报价回复
  Future<QuickQuoteResult> tryQuickQuote({
    required Message message,
    required BusinessProfile profile,
  }) async {
    final text = message.content.toLowerCase();

    // 检查是否命中询价关键词
    final isInquiry = profile.priceInquiryKeywords.any(
      (kw) => text.contains(kw.toLowerCase()),
    );

    if (!isInquiry) {
      return const QuickQuoteResult(matched: false);
    }

    // 尝试匹配产品
    final products = await productRepository.listProducts();
    Product? matchedProduct;
    double bestScore = 0;

    for (final product in products) {
      double score = 0;
      final pName = product.name.toLowerCase();
      final pCategory = product.category.toLowerCase();

      // 名称匹配
      if (text.contains(pName)) {
        score += 1.0;
      }
      // 类目匹配
      if (text.contains(pCategory)) {
        score += 0.5;
      }
      // 特征词匹配
      for (final feature in product.features) {
        if (text.contains(feature.toLowerCase())) {
          score += 0.3;
        }
      }
      // 模糊匹配（关键字在产品名中）
      for (final word in text.split(RegExp(r'\s+'))) {
        if (word.length >= 2 && pName.contains(word)) {
          score += 0.4;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        matchedProduct = product;
      }
    }

    // 如果没匹配到具体产品但确实是询价，返回通用回复
    if (matchedProduct == null && products.isNotEmpty) {
      // 交易模式下，返回产品列表
      if (profile.businessType == BusinessType.trading) {
        final list = products
            .take(5)
            .map(
              (p) =>
                  '${p.name} ${profile.currency}${p.basePrice.toStringAsFixed(0)}',
            )
            .join('\n');
        return QuickQuoteResult(
          matched: true,
          replyText: '目前有这些：\n$list\n要哪个？',
          confidence: 0.7,
        );
      }
      return const QuickQuoteResult(matched: false);
    }

    if (matchedProduct == null) {
      return const QuickQuoteResult(matched: false);
    }

    // 生成报价回复
    final replyText = profile.quoteTemplate
        .replaceAll('{product}', matchedProduct.name)
        .replaceAll('{price}', matchedProduct.basePrice.toStringAsFixed(0))
        .replaceAll('{currency}', profile.currency)
        .replaceAll('{unit}', matchedProduct.unit);

    return QuickQuoteResult(
      matched: true,
      product: matchedProduct,
      replyText: replyText,
      confidence: bestScore > 0.8 ? 0.9 : 0.75,
    );
  }
}
