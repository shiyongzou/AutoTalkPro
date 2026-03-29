import 'package:flutter_test/flutter_test.dart';

import 'package:tg_ai_sales_desktop/features/channel/application/channel_manager.dart';
import 'package:tg_ai_sales_desktop/features/channel/domain/channel_adapter.dart';
import 'package:tg_ai_sales_desktop/features/release/application/release_gate_service.dart';
import 'package:tg_ai_sales_desktop/features/telegram/data/mock_telegram_adapter.dart';
import 'package:tg_ai_sales_desktop/features/telegram/data/official_telegram_adapter.dart';
import 'package:tg_ai_sales_desktop/features/telegram/domain/telegram_config.dart';
import 'package:tg_ai_sales_desktop/features/wecom/data/wecom_adapter.dart';
import 'package:tg_ai_sales_desktop/features/wecom/domain/wecom_config.dart';

void main() {
  test('release gate blocks when active channel health fails', () async {
    final manager = ChannelManager(
      adapters: {
        ChannelType.telegram: const MockTelegramAdapter(),
        ChannelType.wecom: WeComAdapter(config: WeComConfig.stub()),
      },
      initialChannel: ChannelType.wecom,
    );

    final service = const ReleaseGateService();
    final result = await service.evaluate(
      channelManager: manager,
      telegramConfig: TelegramConfig.defaults(),
      weComConfig: WeComConfig.stub(),
      qaEnabled: true,
      dispatchIdempotencyEnabled: true,
      auditEnabled: true,
    );

    expect(result.passed, isFalse);
    expect(result.blockers.join(','), contains('当前通道健康检查'));
  });

  test(
    'release gate blocks when official telegram send readiness fails',
    () async {
      final officialTelegram = OfficialTelegramAdapter(
        config: const TelegramConfig(
          useOfficial: true,
          apiId: '10001',
          apiHash: 'hash',
          phoneNumber: '+85512345678',
        ),
      );

      final manager = ChannelManager(
        adapters: {
          ChannelType.telegram: officialTelegram,
          ChannelType.wecom: WeComAdapter(
            config: const WeComConfig(
              corpId: 'corp',
              agentId: '1000002',
              secret: 'sec',
            ),
          ),
        },
        initialChannel: ChannelType.telegram,
      );

      final service = const ReleaseGateService();
      final result = await service.evaluate(
        channelManager: manager,
        telegramConfig: const TelegramConfig(
          useOfficial: true,
          apiId: '10001',
          apiHash: 'hash',
          phoneNumber: '+85512345678',
        ),
        weComConfig: const WeComConfig(
          corpId: 'corp',
          agentId: '1000002',
          secret: 'sec',
        ),
        qaEnabled: true,
        dispatchIdempotencyEnabled: true,
        auditEnabled: true,
      );

      expect(result.passed, isFalse);
      expect(result.blockers.join(','), contains('当前通道发送就绪检查'));

      final readyCheck = result.checks.firstWhere(
        (c) => c.name == '当前通道发送就绪检查(telegram)',
      );
      expect(readyCheck.pass, isFalse);
      expect(readyCheck.message, contains('未登录'));
    },
  );

  test(
    'release gate exposes active channel config completeness check',
    () async {
      final manager = ChannelManager(
        adapters: {
          ChannelType.telegram: const MockTelegramAdapter(),
          ChannelType.wecom: WeComAdapter(config: WeComConfig.stub()),
        },
        initialChannel: ChannelType.wecom,
      );

      final service = const ReleaseGateService();
      final result = await service.evaluate(
        channelManager: manager,
        telegramConfig: TelegramConfig.defaults(),
        weComConfig: WeComConfig.stub(),
        qaEnabled: true,
        dispatchIdempotencyEnabled: true,
        auditEnabled: true,
      );

      final configCheck = result.checks.firstWhere(
        (c) => c.name == '配置完整性（当前激活通道）',
      );
      expect(configCheck.pass, isFalse);
    },
  );

  test(
    'release gate supports configurable coverage threshold placeholder',
    () async {
      final manager = ChannelManager(
        adapters: {
          ChannelType.telegram: const MockTelegramAdapter(),
          ChannelType.wecom: WeComAdapter(config: WeComConfig.stub()),
        },
        initialChannel: ChannelType.telegram,
      );

      final service = const ReleaseGateService();
      final result = await service.evaluate(
        channelManager: manager,
        telegramConfig: TelegramConfig.defaults(),
        weComConfig: WeComConfig.stub(),
        qaEnabled: true,
        dispatchIdempotencyEnabled: true,
        auditEnabled: true,
        criticalTestCoverage: 76,
        thresholds: const ReleaseGateThresholds(
          criticalTestCoverageThreshold: 80,
        ),
      );

      final coverageCheck = result.checks.firstWhere(
        (c) => c.name == '关键测试覆盖率阈值',
      );
      expect(coverageCheck.pass, isFalse);
      expect(coverageCheck.message, contains('阈值 80%'));
    },
  );

  test('release gate exposes quantified ui style consistency check', () async {
    final manager = ChannelManager(
      adapters: {
        ChannelType.telegram: const MockTelegramAdapter(),
        ChannelType.wecom: WeComAdapter(config: WeComConfig.stub()),
      },
      initialChannel: ChannelType.telegram,
    );

    final service = const ReleaseGateService();
    final result = await service.evaluate(
      channelManager: manager,
      telegramConfig: TelegramConfig.defaults(),
      weComConfig: WeComConfig.stub(),
      qaEnabled: true,
      dispatchIdempotencyEnabled: true,
      auditEnabled: true,
      uiStyleConsistencyPassed: true,
      uiStyleViolationCount: 2,
      uiTokenCoverage: 0.88,
      thresholds: const ReleaseGateThresholds(uiTokenCoverageThreshold: 0.9),
    );

    final uiCheck = result.checks.firstWhere((c) => c.name == 'UI风格一致性');
    expect(uiCheck.pass, isFalse);
    expect(uiCheck.severity, 'P1');
    expect(uiCheck.message, contains('违规 2 项'));
    expect(uiCheck.message, contains('阈值 90%'));
  });

  test('release gate supports configurable ui violation threshold', () async {
    final manager = ChannelManager(
      adapters: {
        ChannelType.telegram: const MockTelegramAdapter(),
        ChannelType.wecom: WeComAdapter(config: WeComConfig.stub()),
      },
      initialChannel: ChannelType.telegram,
    );

    final service = const ReleaseGateService();
    final result = await service.evaluate(
      channelManager: manager,
      telegramConfig: TelegramConfig.defaults(),
      weComConfig: WeComConfig.stub(),
      qaEnabled: true,
      dispatchIdempotencyEnabled: true,
      auditEnabled: true,
      uiStyleConsistencyPassed: true,
      uiStyleViolationCount: 2,
      uiTokenCoverage: 0.92,
      thresholds: const ReleaseGateThresholds(
        uiStyleViolationThreshold: 3,
        uiTokenCoverageThreshold: 0.9,
      ),
    );

    final uiCheck = result.checks.firstWhere((c) => c.name == 'UI风格一致性');
    expect(uiCheck.pass, isTrue);
    expect(uiCheck.message, contains('阈值 3 项'));
  });

  test(
    'release gate blocks when secure credential storage check fails',
    () async {
      final manager = ChannelManager(
        adapters: {
          ChannelType.telegram: const MockTelegramAdapter(),
          ChannelType.wecom: WeComAdapter(config: WeComConfig.stub()),
        },
        initialChannel: ChannelType.telegram,
      );

      final service = const ReleaseGateService();
      final result = await service.evaluate(
        channelManager: manager,
        telegramConfig: TelegramConfig.defaults(),
        weComConfig: WeComConfig.stub(),
        qaEnabled: true,
        dispatchIdempotencyEnabled: true,
        auditEnabled: true,
        credentialSecureStorageEnabled: false,
      );

      expect(result.passed, isFalse);
      expect(result.blockers.join(','), contains('凭据安全存储'));
    },
  );

  test('release gate blocks when analyze or tests are not passed', () async {
    final manager = ChannelManager(
      adapters: {
        ChannelType.telegram: const MockTelegramAdapter(),
        ChannelType.wecom: WeComAdapter(config: WeComConfig.stub()),
      },
      initialChannel: ChannelType.telegram,
    );

    final service = const ReleaseGateService();
    final result = await service.evaluate(
      channelManager: manager,
      telegramConfig: TelegramConfig.defaults(),
      weComConfig: WeComConfig.stub(),
      qaEnabled: true,
      dispatchIdempotencyEnabled: true,
      auditEnabled: true,
      analyzePassed: false,
      testsPassed: false,
    );

    expect(result.passed, isFalse);
    expect(result.blockers.join(','), contains('质量门禁(analyze)'));
    expect(result.blockers.join(','), contains('质量门禁(test)'));
  });

  test(
    'release gate applies threshold object for coverage/ui placeholders',
    () async {
      final manager = ChannelManager(
        adapters: {
          ChannelType.telegram: const MockTelegramAdapter(),
          ChannelType.wecom: WeComAdapter(config: WeComConfig.stub()),
        },
        initialChannel: ChannelType.telegram,
      );

      final service = const ReleaseGateService();
      final result = await service.evaluate(
        channelManager: manager,
        telegramConfig: TelegramConfig.defaults(),
        weComConfig: WeComConfig.stub(),
        qaEnabled: true,
        dispatchIdempotencyEnabled: true,
        auditEnabled: true,
        criticalTestCoverage: 74,
        uiStyleViolationCount: 2,
        uiTokenCoverage: 0.85,
        thresholds: const ReleaseGateThresholds(
          criticalTestCoverageThreshold: 75,
          uiTokenCoverageThreshold: 0.9,
          uiStyleViolationThreshold: 1,
        ),
      );

      final coverageCheck = result.checks.firstWhere(
        (c) => c.name == '关键测试覆盖率阈值',
      );
      final uiCheck = result.checks.firstWhere((c) => c.name == 'UI风格一致性');

      expect(coverageCheck.pass, isFalse);
      expect(coverageCheck.message, contains('阈值 75%'));
      expect(uiCheck.pass, isFalse);
      expect(uiCheck.message, contains('阈值 1 项'));
      expect(uiCheck.message, contains('阈值 90%'));
    },
  );

  test(
    'release gate can export markdown summary with blocker details',
    () async {
      final manager = ChannelManager(
        adapters: {
          ChannelType.telegram: const MockTelegramAdapter(),
          ChannelType.wecom: WeComAdapter(config: WeComConfig.stub()),
        },
        initialChannel: ChannelType.telegram,
      );

      final service = const ReleaseGateService();
      final result = await service.evaluate(
        channelManager: manager,
        telegramConfig: TelegramConfig.defaults(),
        weComConfig: WeComConfig.stub(),
        qaEnabled: true,
        dispatchIdempotencyEnabled: true,
        auditEnabled: true,
        analyzePassed: false,
        testsPassed: true,
      );

      final markdown = result.toMarkdownSummary(
        ciStatus: 'failed',
        ciDetail: 'ci gate failed',
      );

      expect(markdown, contains('# Commercial Release Gate Summary'));
      expect(markdown, contains('## Blocking items (P0)'));
      expect(markdown, contains('质量门禁(analyze)'));
      expect(markdown, contains('## All checks'));
    },
  );
}
