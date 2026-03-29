import 'report_generator_service.dart';

class ReportConversationBreakdown {
  const ReportConversationBreakdown({
    required this.activeNonRisk,
    required this.risk,
    required this.others,
  });

  final int activeNonRisk;
  final int risk;
  final int others;

  int get total => activeNonRisk + risk + others;
}

ReportConversationBreakdown buildConversationBreakdown(ReportSummary summary) {
  final total = summary.totalConversations;
  if (total <= 0) {
    return const ReportConversationBreakdown(
      activeNonRisk: 0,
      risk: 0,
      others: 0,
    );
  }

  final risk = summary.riskConversations.clamp(0, total);
  final activeNonRisk = (summary.activeConversations - risk).clamp(0, total);
  final others = (total - activeNonRisk - risk).clamp(0, total);

  return ReportConversationBreakdown(
    activeNonRisk: activeNonRisk,
    risk: risk,
    others: others,
  );
}
