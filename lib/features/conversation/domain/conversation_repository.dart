import '../../../core/models/conversation.dart';
import '../../../core/models/customer_profile.dart';

abstract class ConversationRepository {
  Future<List<Conversation>> listConversations();

  Future<Conversation?> getConversationById(String conversationId);

  Future<void> upsertConversation(Conversation conversation);

  Future<List<CustomerProfile>> listCustomers();

  Future<void> upsertCustomer(CustomerProfile profile);
}
