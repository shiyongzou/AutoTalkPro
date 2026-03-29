class TelegramConfig {
  const TelegramConfig({
    required this.useOfficial,
    required this.apiId,
    required this.apiHash,
    required this.phoneNumber,
    this.sessionPath,
  });

  factory TelegramConfig.defaults() {
    return const TelegramConfig(
      useOfficial: false,
      apiId: '',
      apiHash: '',
      phoneNumber: '',
      sessionPath: '',
    );
  }

  final bool useOfficial;
  final String apiId;
  final String apiHash;
  final String phoneNumber;
  final String? sessionPath;

  TelegramConfig copyWith({
    bool? useOfficial,
    String? apiId,
    String? apiHash,
    String? phoneNumber,
    String? sessionPath,
  }) {
    return TelegramConfig(
      useOfficial: useOfficial ?? this.useOfficial,
      apiId: apiId ?? this.apiId,
      apiHash: apiHash ?? this.apiHash,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      sessionPath: sessionPath ?? this.sessionPath,
    );
  }

  List<String> validate() {
    if (!useOfficial) return const [];
    final issues = <String>[];
    if (apiId.trim().isEmpty) issues.add('apiId 不能为空');
    if (apiHash.trim().isEmpty) issues.add('apiHash 不能为空');
    if (phoneNumber.trim().isEmpty) issues.add('phoneNumber 不能为空');
    return issues;
  }

  bool get isValid => validate().isEmpty;
}
