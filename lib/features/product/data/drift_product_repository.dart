import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/models/product.dart';
import '../../../core/models/price_rule.dart';
import '../../../core/persistence/drift_local_database.dart';
import '../domain/product_repository.dart';

class DriftProductRepository implements ProductRepository {
  const DriftProductRepository(this._db);
  final DriftLocalDatabase _db;

  @override
  Future<List<Product>> listProducts({bool activeOnly = true}) async {
    final where = activeOnly ? 'WHERE is_active = 1' : '';
    final rows = await _db.customSelect(
      'SELECT * FROM products $where ORDER BY name',
      readsFrom: {},
    ).get();
    return rows.map(_rowToProduct).toList();
  }

  @override
  Future<Product?> getProduct(String id) async {
    final rows = await _db.customSelect(
      'SELECT * FROM products WHERE id = ?',
      variables: [Variable(id)],
      readsFrom: {},
    ).get();
    if (rows.isEmpty) return null;
    return _rowToProduct(rows.first);
  }

  @override
  Future<void> upsertProduct(Product product) async {
    await _db.customStatement(
      '''INSERT OR REPLACE INTO products(id,name,category,description,base_price,floor_price,unit,features_json,is_active,created_at,updated_at,transaction_type,stock,delivery_method,tags_json)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        product.id, product.name, product.category, product.description,
        product.basePrice, product.floorPrice, product.unit,
        jsonEncode(product.features), product.isActive ? 1 : 0,
        product.createdAt.millisecondsSinceEpoch,
        product.updatedAt.millisecondsSinceEpoch,
        product.transactionType, product.stock,
        product.deliveryMethod, jsonEncode(product.tags),
      ],
    );
  }

  @override
  Future<List<PriceRule>> getRulesForProduct(String productId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM price_rules WHERE product_id = ? AND is_active = 1',
      variables: [Variable(productId)],
      readsFrom: {},
    ).get();
    return rows.map(_rowToRule).toList();
  }

  @override
  Future<List<PriceRule>> getAllActiveRules() async {
    final rows = await _db.customSelect(
      'SELECT * FROM price_rules WHERE is_active = 1',
      readsFrom: {},
    ).get();
    return rows.map(_rowToRule).toList();
  }

  @override
  Future<void> upsertPriceRule(PriceRule rule) async {
    await _db.customStatement(
      '''INSERT OR REPLACE INTO price_rules(id,product_id,rule_name,discount_percent,min_quantity,max_quantity,valid_from,valid_to,requires_approval,approval_level,is_active)
         VALUES (?,?,?,?,?,?,?,?,?,?,?)''',
      [
        rule.id, rule.productId, rule.ruleName, rule.discountPercent,
        rule.minQuantity, rule.maxQuantity,
        rule.validFrom.millisecondsSinceEpoch,
        rule.validTo.millisecondsSinceEpoch,
        rule.requiresApproval ? 1 : 0, rule.approvalLevel,
        rule.isActive ? 1 : 0,
      ],
    );
  }

  Product _rowToProduct(QueryRow row) {
    final featuresRaw = row.read<String>('features_json');
    final features = (jsonDecode(featuresRaw) as List).cast<String>();
    final tagsRaw = row.readNullable<String>('tags_json');
    final tags = tagsRaw != null
        ? (jsonDecode(tagsRaw) as List).cast<String>()
        : <String>[];
    return Product(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      category: row.read<String>('category'),
      description: row.read<String>('description'),
      basePrice: row.read<double>('base_price'),
      floorPrice: row.read<double>('floor_price'),
      unit: row.read<String>('unit'),
      features: features,
      isActive: row.read<int>('is_active') == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('updated_at')),
      transactionType: row.readNullable<String>('transaction_type') ?? 'oneTime',
      stock: row.readNullable<int>('stock'),
      deliveryMethod: row.readNullable<String>('delivery_method') ?? 'digital',
      tags: tags,
    );
  }

  PriceRule _rowToRule(QueryRow row) {
    return PriceRule(
      id: row.read<String>('id'),
      productId: row.read<String>('product_id'),
      ruleName: row.read<String>('rule_name'),
      discountPercent: row.read<double>('discount_percent'),
      minQuantity: row.read<int>('min_quantity'),
      maxQuantity: row.read<int>('max_quantity'),
      validFrom: DateTime.fromMillisecondsSinceEpoch(row.read<int>('valid_from')),
      validTo: DateTime.fromMillisecondsSinceEpoch(row.read<int>('valid_to')),
      requiresApproval: row.read<int>('requires_approval') == 1,
      approvalLevel: row.read<String>('approval_level'),
      isActive: row.read<int>('is_active') == 1,
    );
  }
}
