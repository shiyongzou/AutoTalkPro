import 'package:flutter_test/flutter_test.dart';

import 'package:tg_ai_sales_desktop/core/models/audit_log.dart';
import 'package:tg_ai_sales_desktop/core/persistence/drift_local_database.dart';
import 'package:tg_ai_sales_desktop/features/audit/data/drift_audit_repository.dart';

void main() {
  test(
    'drift audit repository persists enriched fields and supports filters',
    () async {
      final db = await DriftLocalDatabase.inMemory();
      addTearDown(db.close);

      final repo = DriftAuditRepository(db);
      final now = DateTime.now();

      await db.customStatement(
        'INSERT INTO conversations(id, customer_id, title, status, goal_stage, last_message_at, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?)',
        [
          'conv_1',
          'cust_1',
          'c1',
          'active',
          'discover',
          now.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch,
        ],
      );
      await db.customStatement(
        'INSERT INTO conversations(id, customer_id, title, status, goal_stage, last_message_at, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?)',
        [
          'conv_2',
          'cust_2',
          'c2',
          'active',
          'discover',
          now.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch,
        ],
      );

      await repo.add(
        AuditLog(
          id: 'a1',
          conversationId: 'conv_1',
          stage: 'send',
          status: 'success',
          requestId: 'req_1',
          operator: 'ops_1',
          channel: 'telegram',
          templateVersion: 't1',
          model: 'm1',
          latencyMs: 88,
          detail: const {'foo': 'bar'},
          createdAt: now,
        ),
      );

      await repo.add(
        AuditLog(
          id: 'a2',
          conversationId: 'conv_2',
          stage: 'qa',
          status: 'blocked',
          requestId: 'req_2',
          operator: 'ops_2',
          channel: 'wecom',
          templateVersion: 't2',
          model: 'm2',
          latencyMs: 120,
          detail: const {'foo': 'baz'},
          createdAt: now.add(const Duration(milliseconds: 1)),
        ),
      );

      final byRequest = await repo.listByRequestId('req_1');
      expect(byRequest.length, 1);
      expect(byRequest.single.operator, 'ops_1');
      expect(byRequest.single.channel, 'telegram');
      expect(byRequest.single.templateVersion, 't1');
      expect(byRequest.single.model, 'm1');
      expect(byRequest.single.latencyMs, 88);

      final filtered = await repo.query(
        const AuditQuery(channel: 'wecom', status: 'blocked', limit: 10),
      );
      expect(filtered.length, 1);
      expect(filtered.single.id, 'a2');
    },
  );
}
