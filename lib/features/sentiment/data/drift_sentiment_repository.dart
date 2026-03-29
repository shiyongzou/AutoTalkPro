import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/models/sentiment_record.dart';
import '../../../core/persistence/drift_local_database.dart';
import '../domain/sentiment_repository.dart';

class DriftSentimentRepository implements SentimentRepository {
  const DriftSentimentRepository(this._db);
  final DriftLocalDatabase _db;

  @override
  Future<void> add(SentimentRecord record) async {
    await _db.customStatement(
      '''INSERT OR REPLACE INTO sentiment_records(
        id,conversation_id,message_id,sentiment,confidence,
        buying_signals_json,hesitation_signals_json,objection_patterns_json,
        emotion_tags_json,created_at
      ) VALUES (?,?,?,?,?,?,?,?,?,?)''',
      [
        record.id,
        record.conversationId,
        record.messageId,
        record.sentiment.name,
        record.confidence,
        jsonEncode(record.buyingSignals),
        jsonEncode(record.hesitationSignals),
        jsonEncode(record.objectionPatterns),
        jsonEncode(record.emotionTags),
        record.createdAt.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<List<SentimentRecord>> listByConversation(
    String conversationId,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM sentiment_records WHERE conversation_id = ? ORDER BY created_at DESC',
          variables: [Variable(conversationId)],
          readsFrom: {},
        )
        .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<SentimentRecord?> getLatest(String conversationId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM sentiment_records WHERE conversation_id = ? ORDER BY created_at DESC LIMIT 1',
          variables: [Variable(conversationId)],
          readsFrom: {},
        )
        .get();
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  SentimentRecord _fromRow(QueryRow row) {
    return SentimentRecord(
      id: row.read<String>('id'),
      conversationId: row.read<String>('conversation_id'),
      messageId: row.read<String>('message_id'),
      sentiment: SentimentType.values.firstWhere(
        (s) => s.name == row.read<String>('sentiment'),
        orElse: () => SentimentType.neutral,
      ),
      confidence: row.read<double>('confidence'),
      buyingSignals:
          (jsonDecode(row.read<String>('buying_signals_json')) as List)
              .cast<String>(),
      hesitationSignals:
          (jsonDecode(row.read<String>('hesitation_signals_json')) as List)
              .cast<String>(),
      objectionPatterns:
          (jsonDecode(row.read<String>('objection_patterns_json')) as List)
              .cast<String>(),
      emotionTags: (jsonDecode(row.read<String>('emotion_tags_json')) as List)
          .cast<String>(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at'),
      ),
    );
  }
}
