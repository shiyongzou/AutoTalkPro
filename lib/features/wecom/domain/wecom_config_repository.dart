import 'wecom_config.dart';

abstract class WeComConfigRepository {
  Future<WeComConfig> load();

  Future<void> save(WeComConfig config);
}
