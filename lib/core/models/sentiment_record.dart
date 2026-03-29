enum SentimentType { positive, negative, neutral, urgent }

class SentimentRecord {
  const SentimentRecord({
    required this.id,
    required this.conversationId,
    required this.messageId,
    required this.sentiment,
    required this.confidence,
    required this.buyingSignals,
    required this.hesitationSignals,
    required this.objectionPatterns,
    required this.emotionTags,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String messageId;
  final SentimentType sentiment;
  final double confidence;
  final List<String> buyingSignals;
  final List<String> hesitationSignals;
  final List<String> objectionPatterns;
  final List<String> emotionTags;
  final DateTime createdAt;

  bool get hasBuyingSignal => buyingSignals.isNotEmpty;
  bool get hasObjection => objectionPatterns.isNotEmpty;
  bool get isUrgent => sentiment == SentimentType.urgent;
}
