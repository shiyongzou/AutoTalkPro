import 'dart:io';

import 'package:tg_ai_sales_desktop/features/channel/application/channel_manager.dart';
import 'package:tg_ai_sales_desktop/features/channel/domain/channel_adapter.dart';
import 'package:tg_ai_sales_desktop/features/release/application/release_gate_service.dart';
import 'package:tg_ai_sales_desktop/features/telegram/data/mock_telegram_adapter.dart';
import 'package:tg_ai_sales_desktop/features/telegram/domain/telegram_config.dart';
import 'package:tg_ai_sales_desktop/features/wecom/data/wecom_adapter.dart';
import 'package:tg_ai_sales_desktop/features/wecom/domain/wecom_config.dart';

Future<void> main(List<String> args) async {
  final outputPath =
      _argValue(args, '--output') ?? 'docs/reports/latest_gate.json';
  final markdownPath =
      _argValue(args, '--markdown-output') ??
      _argValue(args, '--summary-output') ??
      'docs/reports/latest_gate.md';
  final ciStatus = _argValue(args, '--ci-status') ?? 'unknown';
  final ciDetail = _argValue(args, '--ci-detail') ?? '';

  final thresholds = ReleaseGateThresholds(
    criticalTestCoverageThreshold:
        int.tryParse(_argValue(args, '--coverage-threshold') ?? '70') ?? 70,
    uiTokenCoverageThreshold:
        double.tryParse(_argValue(args, '--ui-token-threshold') ?? '0.9') ??
        0.9,
    uiStyleViolationThreshold:
        int.tryParse(_argValue(args, '--ui-violation-threshold') ?? '0') ?? 0,
  );

  final coverage = double.tryParse(_argValue(args, '--coverage') ?? '');
  final uiTokenCoverage = double.tryParse(
    _argValue(args, '--ui-token-coverage') ?? '',
  );
  final uiViolationCount =
      int.tryParse(_argValue(args, '--ui-violation-count') ?? '0') ?? 0;

  final channelManager = ChannelManager(
    adapters: {
      ChannelType.telegram: const MockTelegramAdapter(),
      ChannelType.wecom: WeComAdapter(config: WeComConfig.stub()),
    },
    initialChannel: ChannelType.telegram,
  );

  final releaseGate = const ReleaseGateService();
  final result = await releaseGate.evaluate(
    channelManager: channelManager,
    telegramConfig: TelegramConfig.defaults(),
    weComConfig: WeComConfig.stub(),
    qaEnabled: true,
    dispatchIdempotencyEnabled: true,
    auditEnabled: true,
    analyzePassed: ciStatus == 'passed',
    testsPassed: ciStatus == 'passed',
    criticalTestCoverage: coverage,
    uiTokenCoverage: uiTokenCoverage,
    uiStyleViolationCount: uiViolationCount,
    thresholds: thresholds,
  );

  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(
    result.toCommercialReportPrettyJson(ciStatus: ciStatus, ciDetail: ciDetail),
  );

  final markdownFile = File(markdownPath);
  await markdownFile.parent.create(recursive: true);
  final summaryText = result.toMarkdownSummary(
    ciStatus: ciStatus,
    ciDetail: ciDetail,
  );
  await markdownFile.writeAsString(summaryText);

  stdout.writeln('wrote gate report -> ${outputFile.path}');
  stdout.writeln('wrote gate summary markdown -> ${markdownFile.path}');
  stdout.writeln(summaryText);
}

String? _argValue(List<String> args, String key) {
  for (var i = 0; i < args.length; i++) {
    final item = args[i];
    if (item == key && i + 1 < args.length) {
      return args[i + 1];
    }
    if (item.startsWith('$key=')) {
      return item.substring(key.length + 1);
    }
  }
  return null;
}
