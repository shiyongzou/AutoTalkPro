import 'package:flutter_test/flutter_test.dart';

import 'package:tg_ai_sales_desktop/features/channel/application/channel_manager.dart';
import 'package:tg_ai_sales_desktop/features/channel/domain/channel_adapter.dart';
import 'package:tg_ai_sales_desktop/features/telegram/data/mock_telegram_adapter.dart';
import 'package:tg_ai_sales_desktop/features/telegram/data/official_telegram_adapter.dart';
import 'package:tg_ai_sales_desktop/features/telegram/domain/telegram_config.dart';
import 'package:tg_ai_sales_desktop/features/wecom/data/wecom_adapter.dart';
import 'package:tg_ai_sales_desktop/features/wecom/domain/wecom_config.dart';

void main() {
  test('channel manager can switch between telegram and wecom', () async {
    final manager = ChannelManager(
      adapters: {
        ChannelType.telegram: const MockTelegramAdapter(),
        ChannelType.wecom: WeComAdapter(config: WeComConfig.stub()),
      },
      initialChannel: ChannelType.telegram,
    );

    expect(manager.activeChannel, ChannelType.telegram);
    expect(manager.activeAdapter.channelType, ChannelType.telegram);

    await manager.switchTo(ChannelType.wecom);

    expect(manager.activeChannel, ChannelType.wecom);
    expect(manager.activeAdapter.channelType, ChannelType.wecom);
  });

  test('wecom config validation reports missing official credentials', () {
    final config = WeComConfig.stub();

    expect(config.isValid, isFalse);
    expect(config.validate().join(','), contains('corpId'));
    expect(config.validate().join(','), contains('agentId'));
    expect(config.validate().join(','), contains('secret'));
  });

  test('wecom adapter health check fails on invalid config', () async {
    final adapter = WeComAdapter(config: WeComConfig.stub());

    final health = await adapter.healthCheck();

    expect(health.healthy, isFalse);
    expect(health.message, contains('配置不完整'));
  });

  test('official telegram adapter health check requires config', () async {
    final adapter = OfficialTelegramAdapter(
      config: TelegramConfig.defaults().copyWith(useOfficial: true),
    );
    final health = await adapter.healthCheck();

    expect(health.healthy, isFalse);
    expect(health.message, contains('配置不完整'));
  });

  test('channel manager can update adapter at runtime', () async {
    final manager = ChannelManager(
      adapters: {ChannelType.telegram: const MockTelegramAdapter()},
      initialChannel: ChannelType.telegram,
    );

    final official = OfficialTelegramAdapter(
      config: const TelegramConfig(
        useOfficial: true,
        apiId: '12345',
        apiHash: 'hash',
        phoneNumber: '+85512345678',
        sessionPath: '/tmp/tg.session',
      ),
    );

    manager.updateAdapter(official);

    expect(manager.activeAdapter.displayName, contains('Official'));
  });
}
