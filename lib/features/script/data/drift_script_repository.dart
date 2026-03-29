import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/models/script_template.dart';
import '../../../core/persistence/drift_local_database.dart';
import '../domain/script_repository.dart';

class DriftScriptRepository implements ScriptRepository {
  const DriftScriptRepository(this._db);
  final DriftLocalDatabase _db;

  @override
  Future<void> upsert(ScriptTemplate script) async {
    await _db.customStatement(
      '''INSERT OR REPLACE INTO script_templates(id,category,title,content,tags_json,use_count,created_at,updated_at)
         VALUES (?,?,?,?,?,?,?,?)''',
      [
        script.id,
        script.category.name,
        script.title,
        script.content,
        jsonEncode(script.tags),
        script.useCount,
        script.createdAt.millisecondsSinceEpoch,
        script.updatedAt.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<void> delete(String id) async {
    await _db.customStatement('DELETE FROM script_templates WHERE id = ?', [
      id,
    ]);
  }

  @override
  Future<List<ScriptTemplate>> listAll() async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM script_templates ORDER BY use_count DESC, updated_at DESC',
          readsFrom: {},
        )
        .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<ScriptTemplate>> listByCategory(
    SalesScriptCategory category,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM script_templates WHERE category = ? ORDER BY use_count DESC',
          variables: [Variable(category.name)],
          readsFrom: {},
        )
        .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> incrementUseCount(String id) async {
    await _db.customStatement(
      'UPDATE script_templates SET use_count = use_count + 1 WHERE id = ?',
      [id],
    );
  }

  ScriptTemplate _fromRow(QueryRow row) {
    return ScriptTemplate(
      id: row.read<String>('id'),
      category: SalesScriptCategory.values.firstWhere(
        (c) => c.name == row.read<String>('category'),
        orElse: () => SalesScriptCategory.custom,
      ),
      title: row.read<String>('title'),
      content: row.read<String>('content'),
      tags: (jsonDecode(row.read<String>('tags_json')) as List).cast<String>(),
      useCount: row.read<int>('use_count'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at'),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('updated_at'),
      ),
    );
  }
}
