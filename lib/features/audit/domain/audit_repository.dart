import '../../../core/models/audit_log.dart';

abstract class AuditRepository {
  Future<void> add(AuditLog log);

  Future<List<AuditLog>> listByConversation(String conversationId);

  Future<List<AuditLog>> listByRequestId(String requestId);

  Future<List<AuditLog>> query(AuditQuery query);
}
