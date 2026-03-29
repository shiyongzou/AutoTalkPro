import '../../../core/models/message.dart';

enum ConversationIntent {
  smallTalk,
  relationshipMaintenance,
  businessPromotion,
  riskComplaint,
}

class IntentClassification {
  const IntentClassification({
    required this.intent,
    required this.confidence,
    required this.reason,
    this.hitKeywords = const [],
  });

  final ConversationIntent intent;
  final double confidence;
  final String reason;
  final List<String> hitKeywords;
}

class IntentClassifierService {
  const IntentClassifierService();

  static const List<String> _riskKeywords = [
    '投诉',
    '退款',
    '维权',
    '被骗',
    '骗子',
    '虚假',
    '差评',
    '不满意',
    '生气',
    '封号',
    '异常扣费',
  ];

  static const List<String> _businessKeywords = [
    '价格',
    '报价',
    '套餐',
    '下单',
    '购买',
    '合同',
    '付款',
    '折扣',
    '开通',
    '试用',
    '发票',
    '交付',
  ];

  static const List<String> _relationshipKeywords = [
    '辛苦',
    '谢谢',
    '感谢',
    '最近',
    '节日',
    '在忙吗',
    '问候',
    '祝',
    '关照',
  ];

  static const List<String> _smallTalkKeywords = [
    '在吗',
    '哈哈',
    '吃饭',
    '天气',
    '忙啥',
    '表情',
    'ok',
    '嗯',
    '好的',
    '收到',
  ];

  static const Set<String> _carryOverTokens = {
    '收到',
    '好的',
    'ok',
    '明白',
    '行',
    '可以',
    '那就',
    '回头',
    '再聊',
    '周五',
    '明天',
  };

  IntentClassification classify(List<Message> messages) {
    final customerMessages = messages
        .where((message) => message.role == 'customer')
        .toList(growable: false);

    if (customerMessages.isEmpty) {
      return const IntentClassification(
        intent: ConversationIntent.smallTalk,
        confidence: 0.4,
        reason: '缺少客户有效输入，默认归类为闲聊。',
      );
    }

    final sorted = [...customerMessages]
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

    final latestCustomerMessage = sorted.last;
    final text = latestCustomerMessage.content.trim();
    final normalized = text.toLowerCase();

    if (normalized.isEmpty) {
      return const IntentClassification(
        intent: ConversationIntent.smallTalk,
        confidence: 0.4,
        reason: '缺少客户有效输入，默认归类为闲聊。',
      );
    }

    final contextText = _recentContextText(sorted);

    final riskHits = _hitKeywords(normalized, _riskKeywords);
    if (riskHits.isNotEmpty) {
      return IntentClassification(
        intent: ConversationIntent.riskComplaint,
        confidence: 0.92,
        reason: '命中风险/投诉关键词，建议优先人工介入。',
        hitKeywords: riskHits,
      );
    }

    final riskContextHits = _hitKeywords(contextText, _riskKeywords);
    if (_isCarryOverReply(normalized) && riskContextHits.isNotEmpty) {
      return IntentClassification(
        intent: ConversationIntent.riskComplaint,
        confidence: 0.76,
        reason: '当前话术较短，但上文存在风险/投诉语义，建议按风险优先。',
        hitKeywords: riskContextHits,
      );
    }

    final businessHits = _hitKeywords(normalized, _businessKeywords);
    if (businessHits.isNotEmpty || _looksLikeBusinessQuestion(normalized)) {
      return IntentClassification(
        intent: ConversationIntent.businessPromotion,
        confidence: businessHits.isNotEmpty ? 0.88 : 0.72,
        reason: '命中业务推进语义，建议保持明确推进。',
        hitKeywords: businessHits,
      );
    }

    final businessContextHits = _hitKeywords(contextText, _businessKeywords);
    if (_isCarryOverReply(normalized) && businessContextHits.isNotEmpty) {
      return IntentClassification(
        intent: ConversationIntent.businessPromotion,
        confidence: 0.74,
        reason: '当前消息偏确认语气，但承接了近几轮业务上下文。',
        hitKeywords: businessContextHits,
      );
    }

    final relationHits = _hitKeywords(normalized, _relationshipKeywords);
    if (relationHits.isNotEmpty) {
      return IntentClassification(
        intent: ConversationIntent.relationshipMaintenance,
        confidence: 0.78,
        reason: '命中关系维护语义，建议轻量回应并保持节奏。',
        hitKeywords: relationHits,
      );
    }

    final relationContextHits = _hitKeywords(
      contextText,
      _relationshipKeywords,
    );
    if (_isCarryOverReply(normalized) && relationContextHits.isNotEmpty) {
      return IntentClassification(
        intent: ConversationIntent.relationshipMaintenance,
        confidence: 0.68,
        reason: '当前消息较短，但延续了关系维护语境。',
        hitKeywords: relationContextHits,
      );
    }

    final smallTalkHits = _hitKeywords(normalized, _smallTalkKeywords);
    return IntentClassification(
      intent: ConversationIntent.smallTalk,
      confidence: smallTalkHits.isNotEmpty ? 0.75 : 0.58,
      reason: '未命中强业务信号，归类为闲聊。',
      hitKeywords: smallTalkHits,
    );
  }

  List<String> _hitKeywords(String text, List<String> keywords) {
    return keywords
        .where((keyword) => text.contains(keyword))
        .toList(growable: false);
  }

  bool _looksLikeBusinessQuestion(String text) {
    return text.contains('?') ||
        text.contains('？') ||
        text.contains('多久') ||
        text.contains('怎么') ||
        text.contains('能不能') ||
        text.contains('可以吗');
  }

  bool _isCarryOverReply(String text) {
    if (text.isEmpty) return false;
    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    if (normalized.length <= 4) return true;
    return _carryOverTokens.any(normalized.contains);
  }

  String _recentContextText(List<Message> sortedCustomerMessages) {
    if (sortedCustomerMessages.length <= 1) return '';
    final startIndex = sortedCustomerMessages.length > 4
        ? sortedCustomerMessages.length - 4
        : 0;
    final contextMessages = sortedCustomerMessages.sublist(
      startIndex,
      sortedCustomerMessages.length - 1,
    );

    return contextMessages
        .map((message) => message.content.toLowerCase())
        .join(' ');
  }
}
