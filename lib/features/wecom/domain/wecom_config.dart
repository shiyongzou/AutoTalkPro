class WeComConfig {
  const WeComConfig({
    required this.corpId,
    required this.agentId,
    required this.secret,
    this.apiBase = 'https://qyapi.weixin.qq.com',
    this.callbackPort = 3003,
    this.callbackPath = '/wecom/callback',
    this.callbackUrl = '',
    this.tunnelPublicBaseUrl = '',
  });

  factory WeComConfig.stub() {
    return const WeComConfig(corpId: '', agentId: '', secret: '');
  }

  final String corpId;
  final String agentId;
  final String secret;
  final String apiBase;
  final int callbackPort;
  final String callbackPath;
  final String callbackUrl;
  final String tunnelPublicBaseUrl;

  WeComConfig copyWith({
    String? corpId,
    String? agentId,
    String? secret,
    String? apiBase,
    int? callbackPort,
    String? callbackPath,
    String? callbackUrl,
    String? tunnelPublicBaseUrl,
  }) {
    return WeComConfig(
      corpId: corpId ?? this.corpId,
      agentId: agentId ?? this.agentId,
      secret: secret ?? this.secret,
      apiBase: apiBase ?? this.apiBase,
      callbackPort: callbackPort ?? this.callbackPort,
      callbackPath: callbackPath ?? this.callbackPath,
      callbackUrl: callbackUrl ?? this.callbackUrl,
      tunnelPublicBaseUrl: tunnelPublicBaseUrl ?? this.tunnelPublicBaseUrl,
    );
  }

  List<String> validate() {
    final issues = <String>[];
    if (corpId.trim().isEmpty) {
      issues.add('corpId 不能为空');
    }
    if (agentId.trim().isEmpty) {
      issues.add('agentId 不能为空');
    }
    if (secret.trim().isEmpty) {
      issues.add('secret 不能为空');
    }
    if (!apiBase.startsWith('https://')) {
      issues.add('apiBase 必须是 https 地址');
    }
    if (callbackPort <= 0 || callbackPort > 65535) {
      issues.add('callbackPort 必须在 1~65535');
    }
    if (callbackPath.trim().isEmpty || !callbackPath.startsWith('/')) {
      issues.add('callbackPath 必须以 / 开头');
    }
    if (callbackUrl.trim().isNotEmpty) {
      final uri = Uri.tryParse(callbackUrl.trim());
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        issues.add('callbackUrl 必须是有效 URL');
      }
    }
    if (tunnelPublicBaseUrl.trim().isNotEmpty) {
      final uri = Uri.tryParse(tunnelPublicBaseUrl.trim());
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        issues.add('tunnelPublicBaseUrl 必须是有效 URL');
      }
    }
    return issues;
  }

  bool get isValid => validate().isEmpty;
}
