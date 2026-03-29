import '../../../core/models/message.dart';
import '../../../core/models/sentiment_record.dart';

class SentimentAnalyzer {
  const SentimentAnalyzer();

  static const List<String> _positiveKeywords = [
    '好的',
    '可以',
    '没问题',
    '不错',
    '满意',
    '感兴趣',
    '期待',
    '太好了',
    '喜欢',
    '棒',
    '优秀',
    '支持',
    '合作',
    '信任',
    '推荐',
    '点赞',
    '值得',
    '非常好',
    '靠谱',
  ];

  static const List<String> _negativeKeywords = [
    '不满',
    '失望',
    '差',
    '垃圾',
    '骗',
    '坑',
    '后悔',
    '退款',
    '投诉',
    '生气',
    '不行',
    '差劲',
    '恶心',
    '举报',
    '太烂',
    '烂',
    '忽悠',
    '离谱',
  ];

  static const List<String> _urgentKeywords = [
    '急',
    '马上',
    '立刻',
    '紧急',
    '赶紧',
    '等不了',
    '今天必须',
    '立即',
    '尽快',
    '着急',
    '来不及',
  ];

  static const List<String> _buyingSignalKeywords = [
    '怎么付款',
    '合同',
    '签约',
    '购买',
    '开通',
    '下单',
    '可以开始',
    '什么时候能用',
    '试用',
    '先来一个',
    '先开',
    '付定金',
    '打款',
  ];

  static const List<String> _hesitationKeywords = [
    '再想想',
    '考虑一下',
    '回头说',
    '不确定',
    '看看吧',
    '等等',
    '再看',
    '先不',
    '以后再说',
    '晚点',
    '没想好',
    '还在犹豫',
    '要商量',
  ];

  static const List<String> _objectionKeywords = [
    '太贵',
    '价格高',
    '便宜点',
    '打折',
    '优惠',
    '竞品',
    '别家',
    '其他家',
    '不值',
    '功能少',
    '不够用',
    '缺少',
    '没有这个',
    '为什么比',
  ];

  SentimentRecord analyze({
    required String conversationId,
    required Message message,
  }) {
    final text = message.content.toLowerCase();

    final positiveHits = _findHits(text, _positiveKeywords);
    final negativeHits = _findHits(text, _negativeKeywords);
    final urgentHits = _findHits(text, _urgentKeywords);
    final buyingHits = _findHits(text, _buyingSignalKeywords);
    final hesitationHits = _findHits(text, _hesitationKeywords);
    final objectionHits = _findHits(text, _objectionKeywords);

    // 综合判断情绪
    SentimentType sentiment;
    double confidence;

    if (urgentHits.isNotEmpty) {
      sentiment = SentimentType.urgent;
      confidence = 0.85 + urgentHits.length * 0.03;
    } else if (negativeHits.length > positiveHits.length) {
      sentiment = SentimentType.negative;
      confidence = 0.7 + negativeHits.length * 0.05;
    } else if (positiveHits.length > negativeHits.length) {
      sentiment = SentimentType.positive;
      confidence = 0.7 + positiveHits.length * 0.05;
    } else {
      sentiment = SentimentType.neutral;
      confidence = 0.6;
    }

    // 构建情绪标签
    final emotionTags = <String>[];
    if (positiveHits.isNotEmpty) emotionTags.add('积极');
    if (negativeHits.isNotEmpty) emotionTags.add('消极');
    if (urgentHits.isNotEmpty) emotionTags.add('急迫');
    if (buyingHits.isNotEmpty) emotionTags.add('购买意向');
    if (hesitationHits.isNotEmpty) emotionTags.add('犹豫');
    if (objectionHits.isNotEmpty) emotionTags.add('有异议');

    if (emotionTags.isEmpty) emotionTags.add('平淡');

    return SentimentRecord(
      id: 'sent_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      messageId: message.id,
      sentiment: sentiment,
      confidence: confidence.clamp(0.0, 1.0),
      buyingSignals: buyingHits,
      hesitationSignals: hesitationHits,
      objectionPatterns: objectionHits,
      emotionTags: emotionTags,
      createdAt: DateTime.now(),
    );
  }

  List<String> _findHits(String text, List<String> keywords) {
    return keywords.where((k) => text.contains(k)).toList();
  }
}
