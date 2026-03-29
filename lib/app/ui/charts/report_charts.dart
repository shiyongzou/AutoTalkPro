import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../app_widgets.dart';
import '../../../core/models/industry_market_intel.dart';
import '../../../features/release/application/release_gate_service.dart';
import '../../../features/report/application/report_dashboard_metrics.dart';
import '../../../features/report/application/report_generator_service.dart';

String stageLabel(String stage) {
  switch (stage) {
    case 'discover':
      return '发现';
    case 'proposal':
      return '提案';
    case 'closing':
      return '成交';
    default:
      return stage;
  }
}

class ReportSnapshotCard extends StatelessWidget {
  const ReportSnapshotCard({required this.summary, super.key});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;

    return AppSurfaceCard(
      padding: EdgeInsets.all(tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPanelHeader(
            title: '报表摘要',
            subtitle: '核心指标与亮点汇总，便于导出前快速复核。',
            trailing: AppStatusTag(label: '已生成', tone: AppStatusTone.success),
          ),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              SizedBox(
                width: 150,
                child: AppMetricTile(
                  label: '总会话',
                  value: '${summary.totalConversations}',
                ),
              ),
              SizedBox(
                width: 150,
                child: AppMetricTile(
                  label: '活跃会话',
                  value: '${summary.activeConversations}',
                  tone: AppStatusTone.success,
                ),
              ),
              SizedBox(
                width: 150,
                child: AppMetricTile(
                  label: '风险会话',
                  value: '${summary.riskConversations}',
                  tone: AppStatusTone.danger,
                ),
              ),
              SizedBox(
                width: 150,
                child: AppMetricTile(
                  label: '消息总量',
                  value: '${summary.totalMessages}',
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Text('亮点', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: tokens.spaceXs),
          ...summary.highlights.map((e) => Text('• $e')),
        ],
      ),
    );
  }
}

class ReleaseGateCard extends StatelessWidget {
  const ReleaseGateCard({required this.result, super.key});

  final ReleaseGateResult result;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppStatusTag(
            label: '商用门禁自检：${result.passed ? '通过' : '阻断'}（${result.score}分）',
            tone: result.passed ? AppStatusTone.success : AppStatusTone.danger,
          ),
          const SizedBox(height: 6),
          Text('生成时间: ${result.generatedAt.toLocal()}'),
          const SizedBox(height: 8),
          ...result.checks.map(
            (c) => Text(
              '${c.pass ? '✅' : '❌'} [${c.severity}] ${c.name} - ${c.message}',
            ),
          ),
          if (result.blockers.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('阻断项：', style: TextStyle(fontWeight: FontWeight.w600)),
            ...result.blockers.map((b) => Text('• $b')),
          ],
        ],
      ),
    );
  }
}

class KpiBarChart extends StatelessWidget {
  const KpiBarChart({required this.summary, super.key});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final scheme = Theme.of(context).colorScheme;
    final maxY = [
      summary.totalConversations.toDouble(),
      summary.activeConversations.toDouble(),
      summary.riskConversations.toDouble(),
      summary.totalMessages.toDouble(),
    ].reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 220,
      child: AppSurfaceCard(
        padding: EdgeInsets.all(tokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('业务指标柱状图', style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: tokens.spaceSm + 2),
            Expanded(
              child: BarChart(
                BarChartData(
                  maxY: maxY == 0 ? 1 : maxY * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final map = {0: '总会话', 1: '活跃', 2: '风险', 3: '消息'};
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(map[value.toInt()] ?? ''),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY <= 4 ? 1 : null,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _bar(
                      0,
                      summary.totalConversations.toDouble(),
                      scheme.primary,
                    ),
                    _bar(
                      1,
                      summary.activeConversations.toDouble(),
                      tokens.success,
                    ),
                    _bar(
                      2,
                      summary.riskConversations.toDouble(),
                      tokens.danger,
                    ),
                    _bar(3, summary.totalMessages.toDouble(), scheme.tertiary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 18,
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class ConversationPieChart extends StatelessWidget {
  const ConversationPieChart({required this.summary, super.key});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final scheme = Theme.of(context).colorScheme;
    final breakdown = buildConversationBreakdown(summary);
    final active = breakdown.activeNonRisk.toDouble();
    final risk = breakdown.risk.toDouble();
    final others = breakdown.others.toDouble();

    return SizedBox(
      height: 260,
      child: AppSurfaceCard(
        padding: EdgeInsets.all(tokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('会话状态占比', style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: tokens.spaceXs),
            Text(
              '分桶口径：活跃非风险 / 风险 / 其他（互斥）',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: tokens.spaceSm + 2),
            Expanded(
              child: breakdown.total <= 0
                  ? const Center(child: Text('会话占比暂无数据'))
                  : Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 32,
                              sections: [
                                PieChartSectionData(
                                  value: active,
                                  title:
                                      '${(active / breakdown.total * 100).toStringAsFixed(0)}%',
                                  color: tokens.success,
                                  radius: 56,
                                ),
                                PieChartSectionData(
                                  value: risk,
                                  title:
                                      '${(risk / breakdown.total * 100).toStringAsFixed(0)}%',
                                  color: tokens.danger,
                                  radius: 56,
                                ),
                                PieChartSectionData(
                                  value: others,
                                  title:
                                      '${(others / breakdown.total * 100).toStringAsFixed(0)}%',
                                  color: scheme.primary,
                                  radius: 56,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: tokens.spaceMd - 2),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PieLegendLine(
                              color: tokens.success,
                              label: '活跃(非风险)',
                              value: active.toInt(),
                            ),
                            SizedBox(height: tokens.spaceXs),
                            PieLegendLine(
                              color: tokens.danger,
                              label: '风险',
                              value: risk.toInt(),
                            ),
                            SizedBox(height: tokens.spaceXs),
                            PieLegendLine(
                              color: scheme.primary,
                              label: '其他',
                              value: others.toInt(),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PieLegendLine extends StatelessWidget {
  const PieLegendLine({
    required this.color,
    required this.label,
    required this.value,
    super.key,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label: $value', style: text),
      ],
    );
  }
}

class StageFunnelChart extends StatelessWidget {
  const StageFunnelChart({required this.summary, super.key});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final scheme = Theme.of(context).colorScheme;

    if (summary.stageFunnel.isEmpty) {
      return SizedBox(
        height: 170,
        child: AppSurfaceCard(
          padding: EdgeInsets.all(tokens.spaceMd),
          child: const Center(child: Text('销售漏斗暂无数据，可先在会话中心沉淀阶段信息。')),
        ),
      );
    }

    final maxY = summary.stageFunnel
        .map((e) => e.count.toDouble())
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 320,
      child: AppSurfaceCard(
        padding: EdgeInsets.all(tokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('销售漏斗（阶段转化）', style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: tokens.spaceXs),
            Text(
              '图例：柱体=阶段会话数；顶部标签=绝对值；下方说明=环节转化率',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: tokens.spaceSm),
            Expanded(
              child: BarChart(
                BarChartData(
                  maxY: maxY <= 0 ? 1 : maxY * 1.25,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= summary.stageFunnel.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            '${summary.stageFunnel[idx].count}',
                            style: Theme.of(context).textTheme.labelSmall,
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= summary.stageFunnel.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              stageLabel(summary.stageFunnel[idx].stage),
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < summary.stageFunnel.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: summary.stageFunnel[i].count.toDouble(),
                            width: 20,
                            color: scheme.tertiary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.spaceSm),
            Wrap(
              spacing: tokens.spaceSm + 2,
              runSpacing: tokens.spaceXs,
              children: summary.stageFunnel
                  .map(
                    (e) => Text(
                      '${stageLabel(e.stage)}: ${e.count} (${(e.conversionFromPrevious * 100).toStringAsFixed(1)}%)',
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class RiskTrendLineChart extends StatelessWidget {
  const RiskTrendLineChart({required this.summary, super.key});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;

    if (summary.riskTrend.isEmpty) {
      return SizedBox(
        height: 200,
        child: AppSurfaceCard(
          padding: EdgeInsets.all(tokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('风险趋势图', style: Theme.of(context).textTheme.titleSmall),
              SizedBox(height: tokens.spaceSm),
              const Expanded(child: Center(child: Text('风险趋势暂无数据'))),
            ],
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final maxY = summary.riskTrend
        .map((e) => e.count.toDouble())
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 260,
      child: AppSurfaceCard(
        padding: EdgeInsets.all(tokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('风险趋势图', style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: tokens.spaceXs),
            Text(
              '按时间观察风险消息波动，便于识别异常峰值。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: tokens.spaceSm + 2),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY <= 0 ? 1 : maxY + 1,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: summary.riskTrend.length > 14 ? 4 : 2,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= summary.riskTrend.length) {
                            return const SizedBox.shrink();
                          }
                          final point = summary.riskTrend[idx];
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${point.date.month}/${point.date.day}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < summary.riskTrend.length; i++)
                          FlSpot(
                            i.toDouble(),
                            summary.riskTrend[i].count.toDouble(),
                          ),
                      ],
                      color: tokens.danger,
                      barWidth: 3,
                      isCurved: true,
                      dotData: FlDotData(show: summary.riskTrend.length <= 14),
                      belowBarData: BarAreaData(
                        show: true,
                        color: tokens.danger.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopRiskConversationCard extends StatelessWidget {
  const TopRiskConversationCard({required this.summary, super.key});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;

    return AppSurfaceCard(
      padding: EdgeInsets.all(tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top 风险会话', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: tokens.spaceSm),
          if (summary.topRiskConversations.isEmpty)
            const Text('暂无风险会话')
          else
            ...summary.topRiskConversations.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: tokens.spaceXs + 2),
                child: Text(
                  '• ${item.title}（${item.conversationId}） 风险消息 ${item.riskMessageCount}/${item.totalMessageCount}，占比 ${(item.riskRatio * 100).toStringAsFixed(1)}%，最新 ${item.latestRiskAt.toLocal()}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class OperationsFunnelCard extends StatelessWidget {
  const OperationsFunnelCard({required this.summary, super.key});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;

    return AppSurfaceCard(
      padding: EdgeInsets.all(tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('运营漏斗卡片', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: tokens.spaceSm),
          if (summary.stageFunnel.isEmpty)
            const Text('暂无漏斗数据')
          else
            Wrap(
              spacing: tokens.spaceSm,
              runSpacing: tokens.spaceSm,
              children: summary.stageFunnel.map((e) {
                return SizedBox(
                  width: 200,
                  child: AppSurfaceCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stageLabel(e.stage),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${e.count}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '环节转化 ${(e.conversionFromPrevious * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class TopRiskCustomerCard extends StatelessWidget {
  const TopRiskCustomerCard({required this.summary, super.key});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;

    return AppSurfaceCard(
      padding: EdgeInsets.all(tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('高风险客户 TopN 卡片', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: tokens.spaceSm),
          if (summary.topRiskCustomers.isEmpty)
            const Text('暂无高风险客户')
          else
            ...summary.topRiskCustomers.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: tokens.spaceXs + 2),
                child: Text(
                  '${index + 1}. ${item.displayName}（${item.customerId}） 风险消息 ${item.riskMessageCount}/${item.totalMessageCount}，关联会话 ${item.conversationCount}，占比 ${(item.riskRatio * 100).toStringAsFixed(1)}%，最新 ${item.latestRiskAt.toLocal()}',
                ),
              );
            }),
        ],
      ),
    );
  }
}

class KnowledgeIntelSummaryCard extends StatelessWidget {
  const KnowledgeIntelSummaryCard({required this.intelList, super.key});

  final List<IndustryMarketIntel> intelList;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;

    return AppSurfaceCard(
      padding: EdgeInsets.all(tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('行业市场情报摘要', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: tokens.spaceSm),
          if (intelList.isEmpty)
            const Text('暂无情报数据')
          else
            ...intelList
                .take(3)
                .map(
                  (item) => Padding(
                    padding: EdgeInsets.only(bottom: tokens.spaceSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item.industry} · 模板 ${item.templateName}'),
                        Text('趋势: ${item.trendSummary}'),
                        Text('价格带: ${item.priceBand}'),
                        Text('建议: ${item.weeklySuggestion}'),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
