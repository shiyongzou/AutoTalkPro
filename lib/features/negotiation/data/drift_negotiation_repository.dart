import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/models/negotiation_context.dart';
import '../../../core/persistence/drift_local_database.dart';
import '../domain/negotiation_repository.dart';

class DriftNegotiationRepository implements NegotiationRepository {
  const DriftNegotiationRepository(this._db);
  final DriftLocalDatabase _db;

  @override
  Future<NegotiationContext?> getByConversation(String conversationId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM negotiation_contexts WHERE conversation_id = ? ORDER BY updated_at DESC LIMIT 1',
          variables: [Variable(conversationId)],
          readsFrom: {},
        )
        .get();
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<void> upsert(NegotiationContext ctx) async {
    await _db.customStatement(
      '''INSERT OR REPLACE INTO negotiation_contexts(
        id,conversation_id,customer_id,stage,product_ids_json,
        customer_budget_low,customer_budget_high,our_offer_price,customer_offer_price,
        concession_count,max_concessions,deal_score,
        key_objections_json,agreed_terms_json,created_at,updated_at
      ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        ctx.id,
        ctx.conversationId,
        ctx.customerId,
        ctx.stage.name,
        jsonEncode(ctx.productIds),
        ctx.customerBudgetLow,
        ctx.customerBudgetHigh,
        ctx.ourOfferPrice,
        ctx.customerOfferPrice,
        ctx.concessionCount,
        ctx.maxConcessions,
        ctx.dealScore,
        jsonEncode(ctx.keyObjections),
        jsonEncode(ctx.agreedTerms),
        ctx.createdAt.millisecondsSinceEpoch,
        ctx.updatedAt.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<List<NegotiationContext>> listActive() async {
    final rows = await _db
        .customSelect(
          "SELECT * FROM negotiation_contexts WHERE stage NOT IN ('won','lost') ORDER BY updated_at DESC",
          readsFrom: {},
        )
        .get();
    return rows.map(_fromRow).toList();
  }

  NegotiationContext _fromRow(QueryRow row) {
    return NegotiationContext(
      id: row.read<String>('id'),
      conversationId: row.read<String>('conversation_id'),
      customerId: row.read<String>('customer_id'),
      stage: NegotiationStage.values.firstWhere(
        (s) => s.name == row.read<String>('stage'),
        orElse: () => NegotiationStage.opening,
      ),
      productIds: (jsonDecode(row.read<String>('product_ids_json')) as List)
          .cast<String>(),
      customerBudgetLow: row.readNullable<double>('customer_budget_low'),
      customerBudgetHigh: row.readNullable<double>('customer_budget_high'),
      ourOfferPrice: row.readNullable<double>('our_offer_price'),
      customerOfferPrice: row.readNullable<double>('customer_offer_price'),
      concessionCount: row.read<int>('concession_count'),
      maxConcessions: row.read<int>('max_concessions'),
      dealScore: row.read<double>('deal_score'),
      keyObjections:
          (jsonDecode(row.read<String>('key_objections_json')) as List)
              .cast<String>(),
      agreedTerms: (jsonDecode(row.read<String>('agreed_terms_json')) as List)
          .cast<String>(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at'),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('updated_at'),
      ),
    );
  }
}
