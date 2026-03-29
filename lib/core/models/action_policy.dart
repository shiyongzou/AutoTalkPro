class ActionPolicy {
  const ActionPolicy({
    required this.id,
    required this.name,
    required this.level,
    required this.rules,
    required this.isEnabled,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String level;
  final List<String> rules;
  final bool isEnabled;
  final DateTime updatedAt;
}
