import '../domain/ai_provider.dart';
import '../domain/ai_settings_repository.dart';

class InMemoryAiSettingsRepository implements AiSettingsRepository {
  AiProviderSettings? _settings;

  @override
  Future<AiProviderSettings?> load() async => _settings;

  @override
  Future<void> save(AiProviderSettings settings) async {
    _settings = settings;
  }
}
