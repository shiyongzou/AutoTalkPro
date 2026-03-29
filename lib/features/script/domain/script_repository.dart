import '../../../core/models/script_template.dart';

abstract class ScriptRepository {
  Future<void> upsert(ScriptTemplate script);
  Future<void> delete(String id);
  Future<List<ScriptTemplate>> listAll();
  Future<List<ScriptTemplate>> listByCategory(SalesScriptCategory category);
  Future<void> incrementUseCount(String id);
}
