class BusinessTemplate {
  BusinessTemplate({
    required this.meta,
    required this.persona,
    required this.script,
    required this.policy,
    required this.kpi,
  });

  final TemplateMeta meta;
  final PersonaConfig persona;
  final ScriptConfig script;
  final PolicyConfig policy;
  final KpiConfig kpi;

  factory BusinessTemplate.fromJson(Map<String, dynamic> json) {
    return BusinessTemplate(
      meta: TemplateMeta.fromJson(_asMap(json['meta'])),
      persona: PersonaConfig.fromJson(_asMap(json['persona'])),
      script: ScriptConfig.fromJson(_asMap(json['script'])),
      policy: PolicyConfig.fromJson(_asMap(json['policy'])),
      kpi: KpiConfig.fromJson(_asMap(json['kpi'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meta': meta.toJson(),
      'persona': persona.toJson(),
      'script': script.toJson(),
      'policy': policy.toJson(),
      'kpi': kpi.toJson(),
    };
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    throw const FormatException('模板字段必须是对象');
  }
}

class TemplateMeta {
  TemplateMeta({
    required this.name,
    required this.industry,
    required this.version,
    required this.author,
    required this.description,
    this.compatibleSchema = '1.0',
  });

  final String name;
  final String industry;
  final String version;
  final String author;
  final String description;
  final String compatibleSchema;

  factory TemplateMeta.fromJson(Map<String, dynamic> json) => TemplateMeta(
    name: _mustString(json, 'name'),
    industry: _mustString(json, 'industry'),
    version: _mustString(json, 'version'),
    author: _mustString(json, 'author'),
    description: _mustString(json, 'description'),
    compatibleSchema: (json['compatibleSchema'] ?? '1.0').toString(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'industry': industry,
    'version': version,
    'author': author,
    'description': description,
    'compatibleSchema': compatibleSchema,
  };
}

class PersonaConfig {
  PersonaConfig({
    required this.role,
    required this.tone,
    required this.style,
    required this.forbiddenPromises,
  });

  final String role;
  final String tone;
  final String style;
  final List<String> forbiddenPromises;

  factory PersonaConfig.fromJson(Map<String, dynamic> json) => PersonaConfig(
    role: _mustString(json, 'role'),
    tone: _mustString(json, 'tone'),
    style: _mustString(json, 'style'),
    forbiddenPromises: _mustStringList(json, 'forbiddenPromises'),
  );

  Map<String, dynamic> toJson() => {
    'role': role,
    'tone': tone,
    'style': style,
    'forbiddenPromises': forbiddenPromises,
  };
}

class ScriptConfig {
  ScriptConfig({required this.goals, required this.stages});

  final List<String> goals;
  final List<ScriptStage> stages;

  factory ScriptConfig.fromJson(Map<String, dynamic> json) {
    final rawStages = json['stages'];
    if (rawStages is! List) {
      throw const FormatException('script.stages 必须是数组');
    }
    return ScriptConfig(
      goals: _mustStringList(json, 'goals'),
      stages: rawStages
          .map((e) => ScriptStage.fromJson(_mustMap(e, 'stage item')))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'goals': goals,
    'stages': stages.map((e) => e.toJson()).toList(),
  };
}

class ScriptStage {
  ScriptStage({
    required this.key,
    required this.description,
    required this.enterWhen,
    required this.exitWhen,
  });

  final String key;
  final String description;
  final List<String> enterWhen;
  final List<String> exitWhen;

  factory ScriptStage.fromJson(Map<String, dynamic> json) => ScriptStage(
    key: _mustString(json, 'key'),
    description: _mustString(json, 'description'),
    enterWhen: _mustStringList(json, 'enterWhen'),
    exitWhen: _mustStringList(json, 'exitWhen'),
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'description': description,
    'enterWhen': enterWhen,
    'exitWhen': exitWhen,
  };
}

class PolicyConfig {
  PolicyConfig({
    required this.mode,
    required this.handoffRules,
    required this.riskKeywords,
  });

  final String mode;
  final List<String> handoffRules;
  final List<String> riskKeywords;

  factory PolicyConfig.fromJson(Map<String, dynamic> json) => PolicyConfig(
    mode: _mustString(json, 'mode'),
    handoffRules: _mustStringList(json, 'handoffRules'),
    riskKeywords: _mustStringList(json, 'riskKeywords'),
  );

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'handoffRules': handoffRules,
    'riskKeywords': riskKeywords,
  };
}

class KpiConfig {
  KpiConfig({required this.metrics, required this.reportCadence});

  final List<String> metrics;
  final List<String> reportCadence;

  factory KpiConfig.fromJson(Map<String, dynamic> json) => KpiConfig(
    metrics: _mustStringList(json, 'metrics'),
    reportCadence: _mustStringList(json, 'reportCadence'),
  );

  Map<String, dynamic> toJson() => {
    'metrics': metrics,
    'reportCadence': reportCadence,
  };
}

String _mustString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('字段 $key 必须是非空字符串');
}

List<String> _mustStringList(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! List) throw FormatException('字段 $key 必须是字符串数组');
  final list = value
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (list.isEmpty) throw FormatException('字段 $key 不能为空');
  return list;
}

Map<String, dynamic> _mustMap(dynamic value, String name) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException('$name 必须是对象');
}
