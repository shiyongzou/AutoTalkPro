import '../../../core/models/sentiment_record.dart';

abstract class SentimentRepository {
  Future<void> add(SentimentRecord record);
  Future<List<SentimentRecord>> listByConversation(String conversationId);
  Future<SentimentRecord?> getLatest(String conversationId);
}
