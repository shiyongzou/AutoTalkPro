import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ai_provider.dart';
import '../domain/ai_settings_repository.dart';

class LocalAiSettingsRepository implements AiSettingsRepository {
  LocalAiSettingsRepository({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  static const _kProvider = 'ai.provider';
  static const _kModel = 'ai.model';
  static const _kApiBase = 'ai.apiBase';
  static const _kTemperature = 'ai.temperature';
  static const _kApiKey = 'ai.apiKey';

  static Future<LocalAiSettingsRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalAiSettingsRepository(prefs: prefs);
  }

  @override
  Future<AiProviderSettings?> load() async {
    final providerRaw = _prefs.getString(_kProvider);
    final model = _prefs.getString(_kModel);
    if (providerRaw == null || model == null || model.trim().isEmpty) {
      return null;
    }

    final provider = AiProviderType.values
        .where((e) => e.name == providerRaw)
        .cast<AiProviderType?>()
        .firstWhere((e) => e != null, orElse: () => null);
    if (provider == null) return null;

    return AiProviderSettings(
      provider: provider,
      model: model,
      apiBase: _prefs.getString(_kApiBase),
      apiKey: _prefs.getString(_kApiKey),
      temperature: _readTemperature(),
    );
  }

  double _readTemperature() {
    try {
      return _prefs.getDouble(_kTemperature) ?? 0.7;
    } catch (_) {
      // defaults write存的是String，getDouble会报错
      final str = _prefs.getString(_kTemperature);
      if (str != null) return double.tryParse(str) ?? 0.7;
      return 0.7;
    }
  }

  @override
  Future<void> save(AiProviderSettings settings) async {
    await _prefs.setString(_kProvider, settings.provider.name);
    await _prefs.setString(_kModel, settings.model);

    if (settings.apiBase == null || settings.apiBase!.trim().isEmpty) {
      await _prefs.remove(_kApiBase);
    } else {
      await _prefs.setString(_kApiBase, settings.apiBase!.trim());
    }

    await _prefs.setDouble(_kTemperature, settings.temperature);

    if (settings.apiKey == null || settings.apiKey!.trim().isEmpty) {
      await _prefs.remove(_kApiKey);
    } else {
      await _prefs.setString(_kApiKey, settings.apiKey!.trim());
    }
  }
}
