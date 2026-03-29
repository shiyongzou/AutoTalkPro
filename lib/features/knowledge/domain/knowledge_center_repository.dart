import '../../../core/models/industry_market_intel.dart';

abstract class KnowledgeCenterRepository {
  Future<List<IndustryMarketIntel>> listIntel();

  Future<IndustryMarketIntel?> findByIndustryAndTemplate({
    required String industry,
    required String templateName,
  });

  Future<void> upsertIntel(IndustryMarketIntel intel);
}
