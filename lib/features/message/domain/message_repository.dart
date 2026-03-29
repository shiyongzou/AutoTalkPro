import '../../../core/models/message.dart';

abstract class MessageRepository {
  Future<List<Message>> listMessages(String conversationId);

  Future<void> addMessage(Message message);
}
