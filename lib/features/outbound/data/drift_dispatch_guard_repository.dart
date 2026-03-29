import 'package:drift/drift.dart';

import '../../../core/persistence/drift_local_database.dart';
import '../domain/dispatch_guard_repository.dart';

class DriftDispatchGuardRepository implements DispatchGuardRepository {
  DriftDispatchGuardRepository(this._db);

  final DriftLocalDatabase _db;

  @override
  Future<bool> tryReserve({
    required String requestId,
    required String conversationId,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.customStatement(
        '''
        INSERT INTO dispatch_guards(request_id, conversation_id, status, created_at, updated_at)
        VALUES (?, ?, 'reserved', ?, ?)
        ''',
        [requestId, conversationId, now, now],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> markStatus({
    required String requestId,
    required String status,
  }) async {
    await _db.customStatement(
      '''
      UPDATE dispatch_guards
      SET status = ?, updated_at = ?
      WHERE request_id = ?
      ''',
      [status, DateTime.now().millisecondsSinceEpoch, requestId],
    );
  }

  @override
  Future<String?> getStatus(String requestId) async {
    final rows = await _db
        .customSelect(
          'SELECT status FROM dispatch_guards WHERE request_id = ? LIMIT 1',
          variables: [Variable.withString(requestId)],
          readsFrom: {},
        )
        .get();
    if (rows.isEmpty) return null;
    return rows.first.read<String>('status');
  }

  @override
  Future<int> recoverStuckSending({required Duration olderThan}) async {
    final threshold = DateTime.now().subtract(olderThan).millisecondsSinceEpoch;

    final rows = await _db
        .customSelect(
          '''
      SELECT request_id FROM dispatch_guards
      WHERE status = 'sending' AND updated_at < ?
      ''',
          variables: [Variable.withInt(threshold)],
          readsFrom: {},
        )
        .get();

    if (rows.isEmpty) return 0;

    await _db.customStatement(
      '''
      UPDATE dispatch_guards
      SET status = 'failed', updated_at = ?
      WHERE status = 'sending' AND updated_at < ?
      ''',
      [DateTime.now().millisecondsSinceEpoch, threshold],
    );

    return rows.length;
  }
}
