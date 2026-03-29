/// 话术分类
enum SalesScriptCategory {
  greeting,    // 开场白
  quote,       // 报价
  objection,   // 异议处理
  closing,     // 成交
  followUp,    // 跟进
  afterSales,  // 售后
  custom,      // 自定义
}

class ScriptTemplate {
  const ScriptTemplate({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.tags,
    this.useCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final SalesScriptCategory category;
  final String title;
  final String content;
  final List<String> tags;
  final int useCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get categoryLabel {
    switch (category) {
      case SalesScriptCategory.greeting: return '开场白';
      case SalesScriptCategory.quote: return '报价';
      case SalesScriptCategory.objection: return '异议处理';
      case SalesScriptCategory.closing: return '成交';
      case SalesScriptCategory.followUp: return '跟进';
      case SalesScriptCategory.afterSales: return '售后';
      case SalesScriptCategory.custom: return '自定义';
    }
  }
}
