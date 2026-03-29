import '../../../core/models/product.dart';
import '../../../core/models/price_rule.dart';

abstract class ProductRepository {
  Future<List<Product>> listProducts({bool activeOnly = true});
  Future<Product?> getProduct(String id);
  Future<void> upsertProduct(Product product);
  Future<List<PriceRule>> getRulesForProduct(String productId);
  Future<List<PriceRule>> getAllActiveRules();
  Future<void> upsertPriceRule(PriceRule rule);
}
