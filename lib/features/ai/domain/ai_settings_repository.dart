import 'ai_provider.dart';

abstract class AiSettingsRepository {
  Future<AiProviderSettings?> load();

  Future<void> save(AiProviderSettings settings);
}
