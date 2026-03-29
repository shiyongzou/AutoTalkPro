import 'package:flutter_test/flutter_test.dart';
import 'package:tg_ai_sales_desktop/features/report/application/report_dashboard_metrics.dart';
import 'package:tg_ai_sales_desktop/features/report/application/report_generator_service.dart';

void main() {
  ReportSummary makeSummary({
    required int total,
    required int active,
    required int risk,
  }) {
    return ReportSummary(
      period: ReportPeriod.daily,
      generatedAt: DateTime(2026, 3, 26),
      totalConversations: total,
      activeConversations: active,
      riskConversations: risk,
      totalMessages: 0,
      highlights: const [],
      stageFunnel: const [],
      riskTrend: const [],
      topRiskConversations: const [],
      topRiskCustomers: const [],
    );
  }

  test('breakdown keeps mutually exclusive buckets and preserves total', () {
    final summary = makeSummary(total: 10, active: 7, risk: 4);

    final result = buildConversationBreakdown(summary);

    expect(result.activeNonRisk, 3);
    expect(result.risk, 4);
    expect(result.others, 3);
    expect(result.total, 10);
  });

  test('breakdown clamps invalid inputs safely', () {
    final summary = makeSummary(total: 5, active: 2, risk: 9);

    final result = buildConversationBreakdown(summary);

    expect(result.risk, 5);
    expect(result.activeNonRisk, 0);
    expect(result.others, 0);
    expect(result.total, 5);
  });
}
