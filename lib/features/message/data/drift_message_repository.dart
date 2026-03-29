import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/models/message.dart';
import '../../../core/persistence/drift_local_database.dart';
import '../domain/message_repository.dart';

class DriftMessageRepository implements MessageRepository {
  DriftMessageRepository(this._db);

  final DriftLocalDatabase _db;

  @override
  Future<void> addMessage(Message message) async {
    await _db.customStatement(
      '''
      INSERT INTO messages(id, conversation_id, role, content, sent_at, risk_flag, metadata_json)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        content=excluded.content,
        risk_flag=excluded.risk_flag,
        metadata_json=excluded.metadata_json
      ''',
      [
        message.id,
        message.conversationId,
        message.role,
        message.content,
        message.sentAt.millisecondsSinceEpoch,
        message.riskFlag ? 1 : 0,
        message.metadata == null ? null : jsonEncode(message.metadata),
      ],
    );
  }

  @override
  Future<List<Message>> listMessages(String conversationId) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT * FROM messages
      WHERE conversation_id = ?
      ORDER BY sent_at ASC
      ''',
          variables: [Variable.withString(conversationId)],
          readsFrom: {},
        )
        .get();

    return rows
        .map(
          (r) => Message(
            id: r.read<String>('id'),
            conversationId: r.read<String>('conversation_id'),
            role: r.read<String>('role'),
            content: r.read<String>('content'),
            sentAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('sent_at')),
            riskFlag: r.read<int>('risk_flag') == 1,
            metadata: r.readNullable<String>('metadata_json') == null
                ? null
                : (jsonDecode(r.read<String>('metadata_json'))
                      as Map<String, dynamic>),
          ),
        )
        .toList();
  }
}
