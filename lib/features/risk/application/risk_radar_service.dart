import '../../../core/models/message.dart';

class RiskRadarResult {
  const RiskRadarResult({required this.isRisk, required this.hitKeywords});

  final bool isRisk;
  final List<String> hitKeywords;
}

class RiskRadarService {
  const RiskRadarService({
    this.keywords = const ['退款', '投诉', '举报', '合同', '违约', '封号'],
  });

  final List<String> keywords;

  RiskRadarResult inspect(Message message) {
    final hits = keywords
        .where((word) => message.content.contains(word))
        .toList();
    return RiskRadarResult(isRisk: hits.isNotEmpty, hitKeywords: hits);
  }
}
