import 'package:shared_preferences/shared_preferences.dart';

import '../domain/wecom_config.dart';
import '../domain/wecom_config_repository.dart';

class LocalWeComConfigRepository implements WeComConfigRepository {
  LocalWeComConfigRepository({required SharedPreferences prefs})
    : _prefs = prefs;

  final SharedPreferences _prefs;

  static const _kCorpId = 'wecom.corpId';
  static const _kAgentId = 'wecom.agentId';
  static const _kApiBase = 'wecom.apiBase';
  static const _kSecret = 'wecom.secret';
  static const _kCallbackPort = 'wecom.callbackPort';
  static const _kCallbackPath = 'wecom.callbackPath';
  static const _kCallbackUrl = 'wecom.callbackUrl';
  static const _kTunnelPublicBaseUrl = 'wecom.tunnelPublicBaseUrl';

  static Future<LocalWeComConfigRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalWeComConfigRepository(prefs: prefs);
  }

  @override
  Future<WeComConfig> load() async {
    return WeComConfig(
      corpId: _prefs.getString(_kCorpId) ?? '',
      agentId: _prefs.getString(_kAgentId) ?? '',
      secret: _prefs.getString(_kSecret) ?? '',
      apiBase: _prefs.getString(_kApiBase) ?? 'https://qyapi.weixin.qq.com',
      callbackPort: _prefs.getInt(_kCallbackPort) ?? 3003,
      callbackPath: _prefs.getString(_kCallbackPath) ?? '/wecom/callback',
      callbackUrl: _prefs.getString(_kCallbackUrl) ?? '',
      tunnelPublicBaseUrl: _prefs.getString(_kTunnelPublicBaseUrl) ?? '',
    );
  }

  @override
  Future<void> save(WeComConfig config) async {
    await _prefs.setString(_kCorpId, config.corpId.trim());
    await _prefs.setString(_kAgentId, config.agentId.trim());
    await _prefs.setString(_kApiBase, config.apiBase.trim());
    await _prefs.setString(_kSecret, config.secret.trim());
    await _prefs.setInt(_kCallbackPort, config.callbackPort);
    await _prefs.setString(_kCallbackPath, config.callbackPath.trim());
    await _prefs.setString(_kCallbackUrl, config.callbackUrl.trim());
    await _prefs.setString(
      _kTunnelPublicBaseUrl,
      config.tunnelPublicBaseUrl.trim(),
    );
  }
}
