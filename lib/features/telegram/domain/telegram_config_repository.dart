import 'telegram_config.dart';

abstract class TelegramConfigRepository {
  Future<TelegramConfig> load();

  Future<void> save(TelegramConfig config);
}
