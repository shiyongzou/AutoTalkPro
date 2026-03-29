import 'package:flutter/material.dart';

import '../../app_context.dart';
import '../app_theme.dart';
import '../app_widgets.dart';
import '../../../core/models/product.dart';
import '../../../core/models/price_rule.dart';

class ProductCatalogPage extends StatefulWidget {
  const ProductCatalogPage({required this.appContext, super.key});

  final AppContext appContext;

  @override
  State<ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _ProductCatalogPageState extends State<ProductCatalogPage> {
  List<Product> products = const [];
  Map<String, List<PriceRule>> rulesMap = const {};
  String? selectedProductId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _showProductForm({Product? existing}) async {
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final categoryCtl = TextEditingController(
      text: existing?.category ?? '标准套餐',
    );
    final descCtl = TextEditingController(text: existing?.description ?? '');
    final basePriceCtl = TextEditingController(
      text: existing?.basePrice.toStringAsFixed(0) ?? '',
    );
    final floorPriceCtl = TextEditingController(
      text: existing?.floorPrice.toStringAsFixed(0) ?? '',
    );
    final unitCtl = TextEditingController(text: existing?.unit ?? '月');
    final featuresCtl = TextEditingController(
      text: existing?.features.join('、') ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? '新增产品' : '编辑产品'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(
                    labelText: '产品名称 *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryCtl,
                  decoration: const InputDecoration(
                    labelText: '类目',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtl,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: basePriceCtl,
                        decoration: const InputDecoration(
                          labelText: '基准价 *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: floorPriceCtl,
                        decoration: const InputDecoration(
                          labelText: '底价 *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: unitCtl,
                        decoration: const InputDecoration(
                          labelText: '单位',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: featuresCtl,
                  decoration: const InputDecoration(
                    labelText: '功能亮点(顿号分隔)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtl.text.trim().isEmpty ||
                  basePriceCtl.text.trim().isEmpty ||
                  floorPriceCtl.text.trim().isEmpty) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(const SnackBar(content: Text('名称、基准价和底价为必填项')));
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final now = DateTime.now();
    final features = featuresCtl.text
        .trim()
        .split(RegExp(r'[、,，]'))
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
    final product = Product(
      id: existing?.id ?? 'prod_${now.microsecondsSinceEpoch}',
      name: nameCtl.text.trim(),
      category: categoryCtl.text.trim(),
      description: descCtl.text.trim(),
      basePrice: double.tryParse(basePriceCtl.text.trim()) ?? 0,
      floorPrice: double.tryParse(floorPriceCtl.text.trim()) ?? 0,
      unit: unitCtl.text.trim(),
      features: features,
      isActive: true,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await widget.appContext.productRepository.upsertProduct(product);
    await _load();
  }

  Future<void> _load() async {
    final prods = await widget.appContext.productRepository.listProducts();
    final rMap = <String, List<PriceRule>>{};
    for (final p in prods) {
      rMap[p.id] = await widget.appContext.productRepository.getRulesForProduct(
        p.id,
      );
    }
    if (!mounted) return;
    setState(() {
      products = prods;
      rulesMap = rMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppPanelHeader(
            title: '产品与定价',
            subtitle: '管理你的产品目录和价格规则。点击产品展开查看折扣规则，AI报价时会自动引用这里的价格。',
          ),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              SizedBox(
                width: 140,
                child: AppMetricTile(label: '产品数', value: '${products.length}'),
              ),
              SizedBox(
                width: 140,
                child: AppMetricTile(
                  label: '价格规则',
                  value:
                      '${rulesMap.values.fold<int>(0, (s, l) => s + l.length)}',
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceSm),
          Wrap(
            spacing: tokens.spaceSm,
            children: [
              FilledButton.icon(
                onPressed: _showProductForm,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('新增产品'),
              ),
              OutlinedButton(onPressed: _load, child: const Text('刷新')),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('暂无产品数据'))
                : ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      final rules = rulesMap[p.id] ?? [];
                      final isSelected = selectedProductId == p.id;
                      return _ProductCard(
                        product: p,
                        rules: rules,
                        isExpanded: isSelected,
                        onTap: () => setState(() {
                          selectedProductId = isSelected ? null : p.id;
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.rules,
    required this.isExpanded,
    required this.onTap,
  });

  final Product product;
  final List<PriceRule> rules;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;

    return Card(
      margin: EdgeInsets.only(bottom: tokens.spaceSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          product.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${product.basePrice.toStringAsFixed(0)}/${product.unit}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        '底价 ¥${product.floorPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: product.features
                    .map(
                      (f) => Chip(
                        label: Text(f, style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
              if (isExpanded && rules.isNotEmpty) ...[
                SizedBox(height: tokens.spaceMd),
                const Divider(height: 1),
                SizedBox(height: tokens.spaceSm),
                Text(
                  '价格规则',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: tokens.spaceSm),
                ...rules.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.ruleName,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        AppStatusTag(
                          label: '-${r.discountPercent.toStringAsFixed(0)}%',
                          tone: AppStatusTone.success,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${r.minQuantity}-${r.maxQuantity}${product.unit}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (r.requiresApproval)
                          AppStatusTag(
                            label: '需${r.approvalLevel}审批',
                            tone: AppStatusTone.warning,
                          )
                        else
                          const AppStatusTag(
                            label: '自动',
                            tone: AppStatusTone.success,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
