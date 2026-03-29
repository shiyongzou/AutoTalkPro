import '../../../core/models/negotiation_context.dart';

abstract class NegotiationRepository {
  Future<NegotiationContext?> getByConversation(String conversationId);
  Future<void> upsert(NegotiationContext context);
  Future<List<NegotiationContext>> listActive();
}
