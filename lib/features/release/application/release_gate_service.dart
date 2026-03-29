import 'dart:convert';

import '../../channel/application/channel_manager.dart';
import '../../channel/domain/channel_adapter.dart';
import '../../channel/domain/channel_send_guard.dart';
import '../../telegram/domain/telegram_config.dart';
import '../../wecom/domain/wecom_config.dart';

class ReleaseGateCheck {
  const ReleaseGateCheck({
    required this.name,
    required this.pass,
    required this.severity,
    required this.message,
  });

  final String name;
  final bool pass;
  final String severity; // P0/P1/P2
  final String message;

  Map<String, dynamic> toJson() => {
    'name': name,
    'pass': pass,
    'severity': severity,
    'message': message,
  };
}

class ReleaseGateResult {
  const ReleaseGateResult({
    required this.passed,
    required this.score,
    required this.blockers,
    required this.checks,
    required this.generatedAt,
  });

  final bool passed;
  final int score;
  final List<String> blockers;
  final List<ReleaseGateCheck> checks;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() => {
    'passed': passed,
    'score': score,
    'blockers': blockers,
    'checks': checks.map((c) => c.toJson()).toList(growable: false),
    'generatedAt': generatedAt.toIso8601String(),
  };

  Map<String, dynamic> toCommercialReportJson({
    required String ciStatus,
    required String ciDetail,
  }) => {
    'schema': 'commercial_gate.v1',
    'generatedAt': generatedAt.toIso8601String(),
    'ciGate': {'status': ciStatus, 'detail': ciDetail},
    'commercialReleaseGate': toJson(),
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  String toCommercialReportPrettyJson({
    required String ciStatus,
    required String ciDetail,
  }) => const JsonEncoder.withIndent(
    '  ',
  ).convert(toCommercialReportJson(ciStatus: ciStatus, ciDetail: ciDetail));

  String toReadableSummary({
    required String ciStatus,
    required String ciDetail,
  }) {
    final buffer = StringBuffer()
      ..writeln('== Commercial Release Gate Summary ==')
      ..writeln('generatedAt: ${generatedAt.toIso8601String()}')
      ..writeln('ciGate: $ciStatus${ciDetail.isNotEmpty ? ' ($ciDetail)' : ''}')
      ..writeln('result: ${passed ? 'PASSED' : 'BLOCKED'} (score=$score)')
      ..writeln('checks: ${checks.length}, blockers: ${blockers.length}')
      ..writeln();

    if (blockers.isNotEmpty) {
      buffer.writeln('Blocking items (P0):');
      for (final blocker in blockers) {
        buffer.writeln('  - $blocker');
      }
      buffer.writeln();
    }

    buffer.writeln('All checks:');
    for (final check in checks) {
      final icon = check.pass ? '✅' : '❌';
      buffer.writeln(
        '  $icon [${check.severity}] ${check.name}: ${check.message}',
      );
    }

    return buffer.toString();
  }

  String toMarkdownSummary({
    required String ciStatus,
    required String ciDetail,
  }) {
    final buffer = StringBuffer()
      ..writeln('# Commercial Release Gate Summary')
      ..writeln()
      ..writeln('- generatedAt: `${generatedAt.toIso8601String()}`')
      ..writeln(
        '- ciGate: `$ciStatus${ciDetail.isNotEmpty ? ' ($ciDetail)' : ''}`',
      )
      ..writeln('- result: **${passed ? 'PASSED' : 'BLOCKED'}** (score=$score)')
      ..writeln('- checks: `${checks.length}`')
      ..writeln('- blockers: `${blockers.length}`')
      ..writeln();

    buffer.writeln('## Blocking items (P0)');
    if (blockers.isEmpty) {
      buffer.writeln('- None');
    } else {
      for (final blocker in blockers) {
        buffer.writeln('- $blocker');
      }
    }
    buffer.writeln();

    buffer.writeln('## All checks');
    for (final check in checks) {
      final icon = check.pass ? '✅' : '❌';
      buffer.writeln(
        '- $icon [${check.severity}] **${check.name}**: ${check.message}',
      );
    }

    return buffer.toString();
  }
}

class ReleaseGateThresholds {
  const ReleaseGateThresholds({
    this.criticalTestCoverageThreshold = 70,
    this.uiTokenCoverageThreshold = 0.9,
    this.uiStyleViolationThreshold = 0,
  });

  final int criticalTestCoverageThreshold;
  final double uiTokenCoverageThreshold;
  final int uiStyleViolationThreshold;
}

class ReleaseGateService {
  const ReleaseGateService();

  Future<ReleaseGateResult> evaluate({
    required ChannelManager channelManager,
    required TelegramConfig telegramConfig,
    required WeComConfig weComConfig,
    required bool qaEnabled,
    required bool dispatchIdempotencyEnabled,
    required bool auditEnabled,
    bool credentialSecureStorageEnabled = true,
    bool analyzePassed = true,
    bool testsPassed = true,
    bool uiStyleConsistencyPassed = true,
    int uiStyleViolationCount = 0,
    double? uiTokenCoverage,
    double? criticalTestCoverage,
    ReleaseGateThresholds thresholds = const ReleaseGateThresholds(),
  }) async {
    final checks = <ReleaseGateCheck>[];

    checks.add(
      ReleaseGateCheck(
        name: '发送前QA拦截',
        pass: qaEnabled,
        severity: 'P0',
        message: qaEnabled ? '已启用' : '未启用',
      ),
    );

    checks.add(
      ReleaseGateCheck(
        name: '幂等防重链路',
        pass: dispatchIdempotencyEnabled,
        severity: 'P0',
        message: dispatchIdempotencyEnabled ? '已启用' : '未启用',
      ),
    );

    checks.add(
      ReleaseGateCheck(
        name: '审计链路',
        pass: auditEnabled,
        severity: 'P0',
        message: auditEnabled ? '已启用' : '未启用',
      ),
    );

    checks.add(
      ReleaseGateCheck(
        name: '凭据安全存储',
        pass: credentialSecureStorageEnabled,
        severity: 'P0',
        message: credentialSecureStorageEnabled ? '已启用' : '未启用（需改为安全存储）',
      ),
    );

    checks.add(
      ReleaseGateCheck(
        name: '质量门禁(analyze)',
        pass: analyzePassed,
        severity: 'P0',
        message: analyzePassed ? '通过' : '失败',
      ),
    );

    checks.add(
      ReleaseGateCheck(
        name: '质量门禁(test)',
        pass: testsPassed,
        severity: 'P0',
        message: testsPassed ? '通过' : '失败',
      ),
    );

    final activeHealth = await channelManager.checkActiveHealth();
    checks.add(
      ReleaseGateCheck(
        name: '当前通道健康检查(${activeHealth.channel.name})',
        pass: activeHealth.healthy,
        severity: 'P0',
        message: activeHealth.message,
      ),
    );

    final activeAdapter = channelManager.activeAdapter;
    if (activeAdapter case ChannelSendGuard guardedAdapter) {
      final guard = await guardedAdapter.checkBeforeSend(
        peerId: '__release_probe_peer__',
        text: 'release probe',
      );
      checks.add(
        ReleaseGateCheck(
          name: '当前通道发送就绪检查(${activeAdapter.channelType.name})',
          pass: guard.allowed,
          severity: 'P0',
          message: guard.allowed ? '发送前置校验通过' : (guard.reason ?? '发送前置校验未通过'),
        ),
      );
    } else {
      checks.add(
        ReleaseGateCheck(
          name: '当前通道发送就绪检查(${activeAdapter.channelType.name})',
          pass: true,
          severity: 'P1',
          message: '当前适配器未实现发送前置校验接口（建议补齐 ChannelSendGuard）',
        ),
      );
    }

    final telegramConfigComplete =
        !telegramConfig.useOfficial || telegramConfig.isValid;
    checks.add(
      ReleaseGateCheck(
        name: 'Telegram官方配置',
        pass: telegramConfigComplete,
        severity: 'P1',
        message: telegramConfig.useOfficial
            ? (telegramConfigComplete ? '完整' : '不完整')
            : '当前未启用官方模式',
      ),
    );

    final weComConfigComplete = weComConfig.isValid;
    checks.add(
      ReleaseGateCheck(
        name: 'WeCom官方配置',
        pass: weComConfigComplete,
        severity: 'P1',
        message: weComConfigComplete ? '完整' : weComConfig.validate().join('；'),
      ),
    );

    final activeChannelConfigComplete = switch (channelManager.activeChannel) {
      ChannelType.telegram => telegramConfigComplete,
      ChannelType.wecom => weComConfigComplete,
      ChannelType.wechat => true,
    };
    checks.add(
      ReleaseGateCheck(
        name: '配置完整性（当前激活通道）',
        pass: activeChannelConfigComplete,
        severity: 'P1',
        message: activeChannelConfigComplete ? '当前激活通道配置完整' : '当前激活通道关键配置缺失',
      ),
    );

    final hasUiCoverage = uiTokenCoverage != null;
    final uiCoveragePass =
        !hasUiCoverage ||
        uiTokenCoverage >= thresholds.uiTokenCoverageThreshold;
    final uiViolationPass =
        uiStyleViolationCount <= thresholds.uiStyleViolationThreshold;
    final uiStylePass =
        uiStyleConsistencyPassed && uiViolationPass && uiCoveragePass;
    final uiCoveragePercent = hasUiCoverage
        ? '${(uiTokenCoverage * 100).toStringAsFixed(1)}%'
        : '未提供';
    final uiThresholdPercent =
        '${(thresholds.uiTokenCoverageThreshold * 100).toStringAsFixed(0)}%';

    checks.add(
      ReleaseGateCheck(
        name: 'UI风格一致性',
        pass: uiStylePass,
        severity: 'P1',
        message: uiStylePass
            ? '通过（违规 $uiStyleViolationCount 项/阈值 ${thresholds.uiStyleViolationThreshold} 项，Design Token 覆盖率 $uiCoveragePercent）'
            : '未通过（违规 $uiStyleViolationCount 项/阈值 ${thresholds.uiStyleViolationThreshold} 项，Design Token 覆盖率 $uiCoveragePercent，阈值 $uiThresholdPercent）',
      ),
    );

    final hasCoverage = criticalTestCoverage != null;
    final coveragePass =
        !hasCoverage ||
        criticalTestCoverage >= thresholds.criticalTestCoverageThreshold;
    checks.add(
      ReleaseGateCheck(
        name: '关键测试覆盖率阈值',
        pass: coveragePass,
        severity: 'P1',
        message: hasCoverage
            ? '${criticalTestCoverage.toStringAsFixed(1)}% / 阈值 ${thresholds.criticalTestCoverageThreshold}%'
            : '占位检查：未接入覆盖率采集（配置阈值 ${thresholds.criticalTestCoverageThreshold}%）',
      ),
    );

    final blockers = checks
        .where((c) => c.severity == 'P0' && !c.pass)
        .map((c) => '${c.name}: ${c.message}')
        .toList(growable: false);

    final passedCount = checks.where((c) => c.pass).length;
    final score = ((passedCount / checks.length) * 100).round();

    return ReleaseGateResult(
      passed: blockers.isEmpty,
      score: score,
      blockers: blockers,
      checks: checks,
      generatedAt: DateTime.now(),
    );
  }
}
