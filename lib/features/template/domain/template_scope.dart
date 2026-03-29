enum TemplateScopeLevel { system, workspace, agent, customerGroup, customer }

class TemplateScope {
  const TemplateScope({required this.level, this.targetId});

  final TemplateScopeLevel level;
  final String? targetId;

  String get key {
    if (level == TemplateScopeLevel.system) return 'system';
    return '${level.name}:${targetId ?? ''}';
  }

  String get displayName {
    if (level == TemplateScopeLevel.system) return '系统级';
    return '${_scopeLabel(level)}(${targetId ?? '-'})';
  }

  static String _scopeLabel(TemplateScopeLevel level) {
    switch (level) {
      case TemplateScopeLevel.system:
        return '系统级';
      case TemplateScopeLevel.workspace:
        return '工作区级';
      case TemplateScopeLevel.agent:
        return '业务员级';
      case TemplateScopeLevel.customerGroup:
        return '客户组级';
      case TemplateScopeLevel.customer:
        return '单客户级';
    }
  }
}
