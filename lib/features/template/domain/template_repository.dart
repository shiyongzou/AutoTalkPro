import '../../../core/models/business_template_version.dart';
import 'template_scope.dart';

class TemplateSaveResult {
  const TemplateSaveResult({required this.ok, this.error, this.record});

  final bool ok;
  final String? error;
  final BusinessTemplateVersion? record;
}

abstract class TemplateRepository {
  Future<TemplateSaveResult> importTemplate({
    required TemplateScope scope,
    required String raw,
  });

  Future<List<BusinessTemplateVersion>> getHistory(
    TemplateScope scope,
    String templateName,
  );

  Future<bool> activateVersion({
    required TemplateScope scope,
    required String templateName,
    required String version,
  });
}
