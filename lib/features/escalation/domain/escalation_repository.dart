import '../../../core/models/escalation_alert.dart';

abstract class EscalationRepository {
  Future<void> add(EscalationAlert alert);
  Future<void> update(EscalationAlert alert);
  Future<List<EscalationAlert>> listPending();
  Future<List<EscalationAlert>> listByConversation(String conversationId);
  Future<int> pendingCount();
  Future<List<EscalationAlert>> listAll({int limit = 50});
}
