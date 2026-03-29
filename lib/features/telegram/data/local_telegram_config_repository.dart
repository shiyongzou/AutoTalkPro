import 'package:shared_preferences/shared_preferences.dart';

import '../domain/telegram_config.dart';
import '../domain/telegram_config_repository.dart';

class LocalTelegramConfigRepository implements TelegramConfigRepository {
  LocalTelegramConfigRepository({required SharedPreferences prefs})
    : _prefs = prefs;

  final SharedPreferences _prefs;

  static const _kUseOfficial = 'telegram.useOfficial';
  static const _kApiId = 'telegram.apiId';
  static const _kApiHash = 'telegram.apiHash';
  static const _kPhone = 'telegram.phone';
  static const _kSessionPath = 'telegram.sessionPath';

  static Future<LocalTelegramConfigRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalTelegramConfigRepository(prefs: prefs);
  }

  @override
  Future<TelegramConfig> load() async {
    return TelegramConfig(
      useOfficial: _prefs.getBool(_kUseOfficial) ?? false,
      apiId: _prefs.getString(_kApiId) ?? '',
      apiHash: _prefs.getString(_kApiHash) ?? '',
      phoneNumber: _prefs.getString(_kPhone) ?? '',
      sessionPath: _prefs.getString(_kSessionPath) ?? '',
    );
  }

  @override
  Future<void> save(TelegramConfig config) async {
    await _prefs.setBool(_kUseOfficial, config.useOfficial);
    await _prefs.setString(_kApiId, config.apiId.trim());
    await _prefs.setString(_kApiHash, config.apiHash.trim());
    await _prefs.setString(_kPhone, config.phoneNumber.trim());
    await _prefs.setString(_kSessionPath, (config.sessionPath ?? '').trim());
  }
}
