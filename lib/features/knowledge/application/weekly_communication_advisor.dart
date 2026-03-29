import '../../../core/models/industry_market_intel.dart';
import '../domain/knowledge_center_repository.dart';

class WeeklyCommunicationAdvisor {
  WeeklyCommunicationAdvisor({required KnowledgeCenterRepository repository})
    : _repository = repository;

  final KnowledgeCenterRepository _repository;

  Future<WeeklyCommunicationAdvice> suggest({
    required String industry,
    required String templateName,
  }) async {
    final matched = await _repository.findByIndustryAndTemplate(
      industry: industry,
      templateName: templateName,
    );

    if (matched != null) {
      return WeeklyCommunicationAdvice(
        industry: industry,
        templateName: templateName,
        summary: matched.weeklySuggestion,
        sourceIntel: matched,
      );
    }

    final fallback = await _fallbackIndustryIntel(industry: industry);
    if (fallback != null) {
      return WeeklyCommunicationAdvice(
        industry: industry,
        templateName: templateName,
        summary: '${fallback.weeklySuggestion}（模板:$templateName）',
        sourceIntel: fallback,
      );
    }

    return WeeklyCommunicationAdvice(
      industry: industry,
      templateName: templateName,
      summary: '本周建议：先做需求分层，先问预算与上线时间，再给两档方案和一个限时行动点。',
      sourceIntel: null,
    );
  }

  Future<IndustryMarketIntel?> _fallbackIndustryIntel({
    required String industry,
  }) async {
    final all = await _repository.listIntel();
    for (final item in all) {
      if (item.industry == industry) {
        return item;
      }
    }
    return all.isEmpty ? null : all.first;
  }
}

class WeeklyCommunicationAdvice {
  const WeeklyCommunicationAdvice({
    required this.industry,
    required this.templateName,
    required this.summary,
    required this.sourceIntel,
  });

  final String industry;
  final String templateName;
  final String summary;
  final IndustryMarketIntel? sourceIntel;
}
