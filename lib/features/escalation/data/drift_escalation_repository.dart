import 'package:drift/drift.dart';

import '../../../core/models/escalation_alert.dart';
import '../../../core/persistence/drift_local_database.dart';
import '../domain/escalation_repository.dart';

class DriftEscalationRepository implements EscalationRepository {
  const DriftEscalationRepository(this._db);
  final DriftLocalDatabase _db;

  @override
  Future<void> add(EscalationAlert alert) async {
    await _db.customStatement(
      '''INSERT INTO escalation_alerts(
        id,conversation_id,customer_id,reason,priority,status,
        title,detail,suggested_action,resolved_by,resolved_at,
        created_at,updated_at
      ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        alert.id, alert.conversationId, alert.customerId,
        alert.reason.name, alert.priority.name, alert.status.name,
        alert.title, alert.detail, alert.suggestedAction,
        alert.resolvedBy,
        alert.resolvedAt?.millisecondsSinceEpoch,
        alert.createdAt.millisecondsSinceEpoch,
        alert.updatedAt.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<void> update(EscalationAlert alert) async {
    await _db.customStatement(
      '''UPDATE escalation_alerts SET
        status=?, resolved_by=?, resolved_at=?, updated_at=?
        WHERE id=?''',
      [
        alert.status.name,
        alert.resolvedBy,
        alert.resolvedAt?.millisecondsSinceEpoch,
        alert.updatedAt.millisecondsSinceEpoch,
        alert.id,
      ],
    );
  }

  @override
  Future<List<EscalationAlert>> listPending() async {
    final rows = await _db.customSelect(
      "SELECT * FROM escalation_alerts WHERE status = 'pending' ORDER BY "
      "CASE priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END, "
      'created_at ASC',
      readsFrom: {},
    ).get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<EscalationAlert>> listByConversation(String conversationId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM escalation_alerts WHERE conversation_id = ? ORDER BY created_at DESC',
      variables: [Variable(conversationId)],
      readsFrom: {},
    ).get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<int> pendingCount() async {
    final row = await _db.customSelect(
      "SELECT COUNT(1) c FROM escalation_alerts WHERE status = 'pending'",
      readsFrom: {},
    ).getSingle();
    return row.read<int>('c');
  }

  @override
  Future<List<EscalationAlert>> listAll({int limit = 50}) async {
    final rows = await _db.customSelect(
      'SELECT * FROM escalation_alerts ORDER BY created_at DESC LIMIT ?',
      variables: [Variable(limit)],
      readsFrom: {},
    ).get();
    return rows.map(_fromRow).toList();
  }

  EscalationAlert _fromRow(QueryRow row) {
    final resolvedAtMs = row.readNullable<int>('resolved_at');
    return EscalationAlert(
      id: row.read<String>('id'),
      conversationId: row.read<String>('conversation_id'),
      customerId: row.read<String>('customer_id'),
      reason: EscalationReason.values.firstWhere(
        (r) => r.name == row.read<String>('reason'),
        orElse: () => EscalationReason.manualRequest,
      ),
      priority: EscalationPriority.values.firstWhere(
        (p) => p.name == row.read<String>('priority'),
        orElse: () => EscalationPriority.medium,
      ),
      status: EscalationStatus.values.firstWhere(
        (s) => s.name == row.read<String>('status'),
        orElse: () => EscalationStatus.pending,
      ),
      title: row.read<String>('title'),
      detail: row.read<String>('detail'),
      suggestedAction: row.read<String>('suggested_action'),
      resolvedBy: row.readNullable<String>('resolved_by'),
      resolvedAt: resolvedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(resolvedAtMs),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('updated_at')),
    );
  }
}
