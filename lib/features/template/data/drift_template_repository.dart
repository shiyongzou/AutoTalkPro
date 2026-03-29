import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/models/business_template_version.dart';
import '../../../core/persistence/drift_local_database.dart';
import '../application/template_import_service.dart';
import '../domain/business_template.dart';
import '../domain/template_repository.dart';
import '../domain/template_scope.dart';

class DriftTemplateRepository implements TemplateRepository {
  DriftTemplateRepository(this._db, this._importService);

  final DriftLocalDatabase _db;
  final TemplateImportService _importService;

  @override
  Future<List<BusinessTemplateVersion>> getHistory(
    TemplateScope scope,
    String templateName,
  ) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT * FROM business_template_versions
      WHERE scope_level = ?
        AND IFNULL(scope_target_id, '') = ?
        AND template_name = ?
      ORDER BY imported_at DESC
      ''',
          variables: [
            Variable.withString(scope.level.name),
            Variable.withString(scope.targetId ?? ''),
            Variable.withString(templateName),
          ],
          readsFrom: {},
        )
        .get();

    return rows.map((row) => _rowToVersion(row)).toList();
  }

  @override
  Future<TemplateSaveResult> importTemplate({
    required TemplateScope scope,
    required String raw,
  }) async {
    final parsed = _importService.parseJson(raw);
    if (!parsed.ok || parsed.template == null) {
      return TemplateSaveResult(ok: false, error: parsed.error ?? '模板解析失败');
    }

    final template = parsed.template!;
    final existing = await getHistory(scope, template.meta.name);
    if (existing.any((e) => e.version == template.meta.version)) {
      return const TemplateSaveResult(ok: false, error: '同作用域下该模板版本已存在');
    }

    final active = existing
        .where((e) => e.active)
        .cast<BusinessTemplateVersion?>()
        .firstWhere((e) => e != null, orElse: () => null);
    final diff = _buildDiff(active?.template, template);

    await _db.transaction(() async {
      await _db.customStatement(
        '''
        UPDATE business_template_versions
        SET is_active = 0
        WHERE scope_level = ?
          AND IFNULL(scope_target_id, '') = ?
          AND template_name = ?
        ''',
        [scope.level.name, scope.targetId ?? '', template.meta.name],
      );

      await _db.customStatement(
        '''
        INSERT INTO business_template_versions(
          scope_level,
          scope_target_id,
          template_name,
          version,
          is_active,
          imported_at,
          diff_summary_json,
          template_json
        ) VALUES (?,?,?,?,?,?,?,?)
        ''',
        [
          scope.level.name,
          scope.targetId,
          template.meta.name,
          template.meta.version,
          1,
          DateTime.now().millisecondsSinceEpoch,
          jsonEncode(diff),
          jsonEncode(template.toJson()),
        ],
      );
    });

    final refreshed = await getHistory(scope, template.meta.name);
    return TemplateSaveResult(ok: true, record: refreshed.first);
  }

  @override
  Future<bool> activateVersion({
    required TemplateScope scope,
    required String templateName,
    required String version,
  }) async {
    final history = await getHistory(scope, templateName);
    if (!history.any((e) => e.version == version)) {
      return false;
    }

    await _db.transaction(() async {
      await _db.customStatement(
        '''
        UPDATE business_template_versions
        SET is_active = CASE WHEN version = ? THEN 1 ELSE 0 END
        WHERE scope_level = ?
          AND IFNULL(scope_target_id, '') = ?
          AND template_name = ?
        ''',
        [version, scope.level.name, scope.targetId ?? '', templateName],
      );
    });

    return true;
  }

  BusinessTemplateVersion _rowToVersion(QueryRow row) {
    final scopeLevel = TemplateScopeLevel.values.byName(
      row.read<String>('scope_level'),
    );
    final targetId = row.readNullable<String>('scope_target_id');
    final template = BusinessTemplate.fromJson(
      jsonDecode(row.read<String>('template_json')) as Map<String, dynamic>,
    );

    return BusinessTemplateVersion(
      id: row.read<int>('id'),
      scope: TemplateScope(level: scopeLevel, targetId: targetId),
      template: template,
      version: row.read<String>('version'),
      importedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('imported_at'),
      ),
      active: row.read<int>('is_active') == 1,
      diffSummary: (jsonDecode(row.read<String>('diff_summary_json')) as List)
          .map((e) => e.toString())
          .toList(),
    );
  }

  List<String> _buildDiff(BusinessTemplate? oldT, BusinessTemplate newT) {
    if (oldT == null) return const ['首次导入'];

    final changes = <String>[];

    void changed(String field, Object? a, Object? b) {
      if ('$a' != '$b') changes.add(field);
    }

    changed('meta.description', oldT.meta.description, newT.meta.description);
    changed('persona.role', oldT.persona.role, newT.persona.role);
    changed('persona.tone', oldT.persona.tone, newT.persona.tone);
    changed('persona.style', oldT.persona.style, newT.persona.style);
    changed(
      'persona.forbiddenPromises',
      oldT.persona.forbiddenPromises.join('|'),
      newT.persona.forbiddenPromises.join('|'),
    );
    changed(
      'script.goals',
      oldT.script.goals.join('|'),
      newT.script.goals.join('|'),
    );
    changed(
      'script.stages',
      oldT.script.stages.map((e) => e.key).join('|'),
      newT.script.stages.map((e) => e.key).join('|'),
    );
    changed('policy.mode', oldT.policy.mode, newT.policy.mode);
    changed(
      'policy.handoffRules',
      oldT.policy.handoffRules.join('|'),
      newT.policy.handoffRules.join('|'),
    );
    changed(
      'policy.riskKeywords',
      oldT.policy.riskKeywords.join('|'),
      newT.policy.riskKeywords.join('|'),
    );
    changed(
      'kpi.metrics',
      oldT.kpi.metrics.join('|'),
      newT.kpi.metrics.join('|'),
    );
    changed(
      'kpi.reportCadence',
      oldT.kpi.reportCadence.join('|'),
      newT.kpi.reportCadence.join('|'),
    );

    return changes.isEmpty ? const ['无变更'] : changes;
  }
}
