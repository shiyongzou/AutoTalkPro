import '../../features/template/domain/business_template.dart';
import '../../features/template/domain/template_scope.dart';

class BusinessTemplateVersion {
  const BusinessTemplateVersion({
    required this.id,
    required this.scope,
    required this.template,
    required this.version,
    required this.importedAt,
    required this.active,
    required this.diffSummary,
  });

  final int id;
  final TemplateScope scope;
  final BusinessTemplate template;
  final String version;
  final DateTime importedAt;
  final bool active;
  final List<String> diffSummary;

  BusinessTemplateVersion copyWith({bool? active}) {
    return BusinessTemplateVersion(
      id: id,
      scope: scope,
      template: template,
      version: version,
      importedAt: importedAt,
      active: active ?? this.active,
      diffSummary: diffSummary,
    );
  }
}
