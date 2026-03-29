import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/models/industry_market_intel.dart';
import '../../../core/persistence/drift_local_database.dart';
import '../domain/knowledge_center_repository.dart';

class DriftKnowledgeCenterRepository implements KnowledgeCenterRepository {
  DriftKnowledgeCenterRepository(this._db);

  final DriftLocalDatabase _db;

  @override
  Future<List<IndustryMarketIntel>> listIntel() async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM knowledge_center_intel ORDER BY updated_at DESC',
          readsFrom: {},
        )
        .get();

    return rows.map(_mapIntel).toList();
  }

  @override
  Future<IndustryMarketIntel?> findByIndustryAndTemplate({
    required String industry,
    required String templateName,
  }) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT * FROM knowledge_center_intel
      WHERE industry = ? AND template_name = ?
      LIMIT 1
      ''',
          variables: [
            Variable.withString(industry),
            Variable.withString(templateName),
          ],
          readsFrom: {},
        )
        .get();

    if (rows.isEmpty) return null;
    return _mapIntel(rows.first);
  }

  @override
  Future<void> upsertIntel(IndustryMarketIntel intel) async {
    await _db.customStatement(
      '''
      INSERT INTO knowledge_center_intel(
        id,
        industry,
        template_name,
        trend_summary,
        price_band,
        competitor_highlights_json,
        weekly_suggestion,
        updated_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        industry=excluded.industry,
        template_name=excluded.template_name,
        trend_summary=excluded.trend_summary,
        price_band=excluded.price_band,
        competitor_highlights_json=excluded.competitor_highlights_json,
        weekly_suggestion=excluded.weekly_suggestion,
        updated_at=excluded.updated_at
      ''',
      [
        intel.id,
        intel.industry,
        intel.templateName,
        intel.trendSummary,
        intel.priceBand,
        jsonEncode(intel.competitorHighlights),
        intel.weeklySuggestion,
        intel.updatedAt.millisecondsSinceEpoch,
      ],
    );
  }

  IndustryMarketIntel _mapIntel(QueryRow row) {
    return IndustryMarketIntel(
      id: row.read<String>('id'),
      industry: row.read<String>('industry'),
      templateName: row.read<String>('template_name'),
      trendSummary: row.read<String>('trend_summary'),
      priceBand: row.read<String>('price_band'),
      competitorHighlights:
          (jsonDecode(row.read<String>('competitor_highlights_json')) as List)
              .map((e) => e.toString())
              .toList(),
      weeklySuggestion: row.read<String>('weekly_suggestion'),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('updated_at'),
      ),
    );
  }
}
