/// 微信机器人配置 (基于 wechatbot-webhook)
class WeChatBotConfig {
  const WeChatBotConfig({
    required this.apiBase,
    required this.token,
    this.recvdMsgApiUrl,
    this.enabled = false,
  });

  /// wechatbot-webhook 服务地址，如 http://localhost:3001
  final String apiBase;

  /// 认证Token
  final String token;

  /// 接收消息的回调URL（本机webhook地址）
  final String? recvdMsgApiUrl;

  /// 是否启用
  final bool enabled;

  String get sendUrl => '${apiBase.replaceAll(RegExp(r'/+$'), '')}/webhook/msg/v2?token=$token';
  String get loginUrl => '${apiBase.replaceAll(RegExp(r'/+$'), '')}/login?token=$token';
  String get healthUrl => '${apiBase.replaceAll(RegExp(r'/+$'), '')}/healthz?token=$token';

  static WeChatBotConfig defaults() => const WeChatBotConfig(
    apiBase: 'http://localhost:3001',
    token: '',
    enabled: false,
  );
}
