import 'package:flutter_test/flutter_test.dart';
import 'package:tg_ai_sales_desktop/core/models/industry_market_intel.dart';
import 'package:tg_ai_sales_desktop/core/persistence/drift_local_database.dart';
import 'package:tg_ai_sales_desktop/features/knowledge/application/weekly_communication_advisor.dart';
import 'package:tg_ai_sales_desktop/features/knowledge/data/drift_knowledge_center_repository.dart';

void main() {
  test('knowledge center seeds sample intel on fresh db', () async {
    final db = await DriftLocalDatabase.inMemory();
    final repo = DriftKnowledgeCenterRepository(db);

    final rows = await repo.listIntel();

    expect(rows, isNotEmpty);
    expect(rows.any((e) => e.industry == '跨境电商SaaS'), isTrue);
    await db.close();
  });

  test('knowledge center upsert and advisor suggestion works', () async {
    final db = await DriftLocalDatabase.inMemory();
    final repo = DriftKnowledgeCenterRepository(db);
    final advisor = WeeklyCommunicationAdvisor(repository: repo);

    final now = DateTime.now();
    await repo.upsertIntel(
      IndustryMarketIntel(
        id: 'intel_custom_1',
        industry: '游戏出海',
        templateName: 'discover',
        trendSummary: '买量波动加剧，素材迭代速度是关键。',
        priceBand: 'CPA ¥20-¥60',
        competitorHighlights: const ['竞品G支持创意AB自动化'],
        weeklySuggestion: '先确认当前素材迭代频次，再给出低风险AB实验计划。',
        updatedAt: now,
      ),
    );

    final matched = await advisor.suggest(
      industry: '游戏出海',
      templateName: 'discover',
    );
    expect(matched.summary, contains('低风险AB实验计划'));

    final fallback = await advisor.suggest(
      industry: '未知行业',
      templateName: 'discover',
    );
    expect(fallback.summary, isNotEmpty);
    await db.close();
  });
}
