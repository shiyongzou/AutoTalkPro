import 'dart:convert';

import '../domain/business_template.dart';

class TemplateImportResult {
  const TemplateImportResult({required this.ok, this.template, this.error});

  final bool ok;
  final BusinessTemplate? template;
  final String? error;
}

class TemplateImportService {
  TemplateImportResult parseJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const TemplateImportResult(ok: false, error: '模板根节点必须是 JSON 对象');
      }

      final template = BusinessTemplate.fromJson(decoded);
      final stageKeys = template.script.stages.map((e) => e.key).toSet();
      if (stageKeys.length != template.script.stages.length) {
        return const TemplateImportResult(
          ok: false,
          error: 'script.stages 存在重复 key',
        );
      }

      if (!{'L1', 'L2', 'L3'}.contains(template.policy.mode)) {
        return const TemplateImportResult(
          ok: false,
          error: 'policy.mode 只能是 L1/L2/L3',
        );
      }

      return TemplateImportResult(ok: true, template: template);
    } on FormatException catch (e) {
      return TemplateImportResult(ok: false, error: e.message);
    } catch (e) {
      return TemplateImportResult(ok: false, error: '模板解析失败：$e');
    }
  }
}
