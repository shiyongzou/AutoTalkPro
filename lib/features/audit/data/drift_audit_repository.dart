import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/models/audit_log.dart';
import '../../../core/persistence/drift_local_database.dart';
import '../domain/audit_repository.dart';

class DriftAuditRepository implements AuditRepository {
  DriftAuditRepository(this._db);

  final DriftLocalDatabase _db;

  @override
  Future<void> add(AuditLog log) async {
    await _db.customStatement(
      '''
      INSERT INTO audit_logs(
        id,
        conversation_id,
        stage,
        status,
        request_id,
        operator,
        channel,
        template_version,
        model,
        latency_ms,
        detail_json,
        created_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        stage=excluded.stage,
        status=excluded.status,
        request_id=excluded.request_id,
        operator=excluded.operator,
        channel=excluded.channel,
        template_version=excluded.template_version,
        model=excluded.model,
        latency_ms=excluded.latency_ms,
        detail_json=excluded.detail_json,
        created_at=excluded.created_at
      ''',
      [
        log.id,
        log.conversationId,
        log.stage,
        log.status,
        log.requestId,
        log.operator,
        log.channel,
        log.templateVersion,
        log.model,
        log.latencyMs,
        jsonEncode(log.detail),
        log.createdAt.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<List<AuditLog>> listByConversation(String conversationId) {
    return query(AuditQuery(conversationId: conversationId));
  }

  @override
  Future<List<AuditLog>> listByRequestId(String requestId) {
    return query(AuditQuery(requestId: requestId));
  }

  @override
  Future<List<AuditLog>> query(AuditQuery query) async {
    final whereClauses = <String>[];
    final variables = <Variable>[];

    void addEquals(String column, String? value) {
      if (value == null || value.trim().isEmpty) return;
      whereClauses.add('$column = ?');
      variables.add(Variable.withString(value.trim()));
    }

    void addWithDetailFallback({
      required String column,
      required String detailKey,
      required String? value,
    }) {
      if (value == null || value.trim().isEmpty) return;
      whereClauses.add(
        '($column = ? OR json_extract(detail_json, "\$.$detailKey") = ?)',
      );
      variables.add(Variable.withString(value.trim()));
      variables.add(Variable.withString(value.trim()));
    }

    addEquals('conversation_id', query.conversationId);
    addWithDetailFallback(
      column: 'request_id',
      detailKey: 'requestId',
      value: query.requestId,
    );
    addWithDetailFallback(
      column: 'channel',
      detailKey: 'channel',
      value: query.channel,
    );
    addEquals('stage', query.stage);
    addEquals('status', query.status);

    final whereSql = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final limit = query.limit <= 0 ? 50 : query.limit;

    final rows = await _db
        .customSelect(
          '''
      SELECT * FROM audit_logs
      $whereSql
      ORDER BY created_at DESC
      LIMIT ?
      ''',
          variables: [...variables, Variable.withInt(limit)],
          readsFrom: {},
        )
        .get();

    return rows.map(_fromRow).toList();
  }

  AuditLog _fromRow(QueryRow r) {
    final detail =
        jsonDecode(r.read<String>('detail_json')) as Map<String, dynamic>;
    final latencyFromDetail =
        (detail['latencyMs'] as int?) ??
        (detail['durationMs'] as int?) ??
        (detail['dispatchDurationMs'] as int?);

    return AuditLog(
      id: r.read<String>('id'),
      conversationId: r.read<String>('conversation_id'),
      stage: r.read<String>('stage'),
      status: r.read<String>('status'),
      requestId:
          r.readNullable<String>('request_id') ??
          detail['requestId']?.toString(),
      operator:
          r.readNullable<String>('operator') ?? detail['operator']?.toString(),
      channel:
          r.readNullable<String>('channel') ?? detail['channel']?.toString(),
      templateVersion:
          r.readNullable<String>('template_version') ??
          detail['templateVersion']?.toString(),
      model: r.readNullable<String>('model') ?? detail['model']?.toString(),
      latencyMs: r.readNullable<int>('latency_ms') ?? latencyFromDetail,
      detail: detail,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at')),
    );
  }
}
