/// 业务类型
enum BusinessType {
  sales, // 传统销售（SaaS、实体商品等长周期）
  trading, // 交易/代购（短片、虚拟物品等快速交易）
  service, // 服务类（咨询、定制开发等）
}

/// 交易模式
enum TransactionMode {
  subscription, // 订阅制（月付/年付）
  oneTime, // 一次性购买
  negotiable, // 可议价
}

/// 交付方式
enum DeliveryMethod {
  digital, // 数字交付（链接、文件、网盘）
  physical, // 实物寄送
  service, // 服务交付
  instant, // 即时交付（当场给）
}

class BusinessProfile {
  const BusinessProfile({
    required this.id,
    required this.name,
    required this.businessType,
    required this.transactionMode,
    required this.deliveryMethod,
    required this.personaName,
    required this.personaStyle,
    required this.personaRules,
    required this.greetingTemplate,
    required this.quoteTemplate,
    required this.closingTemplate,
    required this.priceInquiryKeywords,
    required this.buyIntentKeywords,
    required this.riskKeywords,
    required this.currency,
    required this.autoQuoteEnabled,
    required this.quickReplyEnabled,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final BusinessType businessType;
  final TransactionMode transactionMode;
  final DeliveryMethod deliveryMethod;

  // AI 人设
  final String personaName;
  final String personaStyle; // 如 "专业简洁" / "热情友好" / "老练话少"
  final List<String> personaRules; // 额外行为规则

  // 话术模板
  final String greetingTemplate; // 首次招呼
  final String quoteTemplate; // 报价话术
  final String closingTemplate; // 成交话术

  // 关键词配置
  final List<String> priceInquiryKeywords; // 问价关键词
  final List<String> buyIntentKeywords; // 购买意向关键词
  final List<String> riskKeywords; // 风险关键词

  final String currency; // '¥', '$', 'USDT' 等
  final bool autoQuoteEnabled; // 自动报价
  final bool quickReplyEnabled; // 快速回复模式

  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 默认SaaS销售配置
  static BusinessProfile defaultSales() {
    final now = DateTime.now();
    return BusinessProfile(
      id: 'bp_default_sales',
      name: 'SaaS销售',
      businessType: BusinessType.sales,
      transactionMode: TransactionMode.subscription,
      deliveryMethod: DeliveryMethod.digital,
      personaName: '小助',
      personaStyle: '专业简洁，目标导向，温和有推动力',
      personaRules: const ['先建立信任再谈业务', '价格讨论时先强调价值再报价', '不承诺绝对性结果'],
      greetingTemplate: '您好！感谢关注，我是{persona}，有什么可以帮您的？',
      quoteTemplate: '这个方案{product}的价格是{price}/{unit}，现在还有优惠活动~',
      closingTemplate: '好的，那我这边安排合同流程，您确认下信息~',
      priceInquiryKeywords: const ['价格', '报价', '多少钱', '费用', '收费', '套餐', '怎么收'],
      buyIntentKeywords: const ['购买', '下单', '开通', '合同', '签约', '付款', '试用'],
      riskKeywords: const ['投诉', '退款', '举报', '维权', '骗', '差评'],
      currency: '¥',
      autoQuoteEnabled: false,
      quickReplyEnabled: false,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 交易/代购配置（短片、虚拟商品等）
  static BusinessProfile defaultTrading() {
    final now = DateTime.now();
    return BusinessProfile(
      id: 'bp_default_trading',
      name: '资源交易',
      businessType: BusinessType.trading,
      transactionMode: TransactionMode.negotiable,
      deliveryMethod: DeliveryMethod.digital,
      personaName: '老板',
      personaStyle: '简洁直接，老练不废话，报价干脆',
      personaRules: const [
        '直接报价不啰嗦',
        '客户问什么答什么，不主动推销',
        '确认付款后才发货',
        '不透露货源和成本',
        '遇到砍价适当让步但有底线',
      ],
      greetingTemplate: '在的，需要什么？',
      quoteTemplate: '{product} {price}{currency}，要的话说一声',
      closingTemplate: '好，{price}{currency}，付了我马上发',
      priceInquiryKeywords: const [
        '多少钱',
        '怎么卖',
        '什么价',
        '价格',
        '收吗',
        '有没有',
        '多少',
        '几块',
        '贵不贵',
        '便宜',
        '打包价',
        '批发',
        '怎么收',
        '收费',
        '要多少',
        '报个价',
      ],
      buyIntentKeywords: const [
        '要了',
        '来一个',
        '买',
        '要',
        '付了',
        '转了',
        '发我',
        '给我',
        '拿',
        '收',
        '打款',
        '下单',
        '可以',
        '行',
        '就这个',
        '成交',
      ],
      riskKeywords: const ['骗子', '举报', '报警', '假的', '骗', '投诉', '退钱'],
      currency: '¥',
      autoQuoteEnabled: true,
      quickReplyEnabled: true,
      isActive: false,
      createdAt: now,
      updatedAt: now,
    );
  }
}
