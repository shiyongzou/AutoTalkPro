import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/models/conversation.dart';
import '../../../core/models/customer_profile.dart';
import '../../../core/persistence/drift_local_database.dart';
import '../domain/conversation_repository.dart';

class DriftConversationRepository implements ConversationRepository {
  DriftConversationRepository(this._db);

  final DriftLocalDatabase _db;

  Conversation _rowToConversation(QueryRow r) {
    return Conversation(
      id: r.read<String>('id'),
      customerId: r.read<String>('customer_id'),
      title: r.read<String>('title'),
      status: r.read<String>('status'),
      goalStage: r.read<String>('goal_stage'),
      lastMessageAt: r.readNullable<int>('last_message_at') == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r.read<int>('last_message_at')),
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at')),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('updated_at')),
      autopilotMode: r.readNullable<String>('autopilot_mode') ?? 'manual',
      negotiationId: r.readNullable<String>('negotiation_id'),
    );
  }

  @override
  Future<List<Conversation>> listConversations() async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM conversations ORDER BY updated_at DESC',
          readsFrom: {},
        )
        .get();
    return rows.map(_rowToConversation).toList();
  }

  @override
  Future<Conversation?> getConversationById(String conversationId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM conversations WHERE id = ? LIMIT 1',
          variables: [Variable.withString(conversationId)],
          readsFrom: {},
        )
        .get();
    if (rows.isEmpty) return null;
    return _rowToConversation(rows.first);
  }

  @override
  Future<void> upsertConversation(Conversation conversation) async {
    await _db.customStatement(
      '''
      INSERT INTO conversations(id, customer_id, title, status, goal_stage, last_message_at, created_at, updated_at, autopilot_mode, negotiation_id)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        customer_id=excluded.customer_id,
        title=excluded.title,
        status=excluded.status,
        goal_stage=excluded.goal_stage,
        last_message_at=excluded.last_message_at,
        updated_at=excluded.updated_at,
        autopilot_mode=excluded.autopilot_mode,
        negotiation_id=excluded.negotiation_id
      ''',
      [
        conversation.id,
        conversation.customerId,
        conversation.title,
        conversation.status,
        conversation.goalStage,
        conversation.lastMessageAt?.millisecondsSinceEpoch,
        conversation.createdAt.millisecondsSinceEpoch,
        conversation.updatedAt.millisecondsSinceEpoch,
        conversation.autopilotMode,
        conversation.negotiationId,
      ],
    );
  }

  CustomerProfile _rowToCustomer(QueryRow r) {
    return CustomerProfile(
      id: r.read<String>('id'),
      name: r.read<String>('name'),
      segment: r.read<String>('segment'),
      tags: (jsonDecode(r.read<String>('tags_json')) as List)
          .map((e) => e.toString())
          .toList(),
      lastContactAt: r.readNullable<int>('last_contact_at') == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r.read<int>('last_contact_at')),
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at')),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('updated_at')),
      company: r.readNullable<String>('company'),
      email: r.readNullable<String>('email'),
      phone: r.readNullable<String>('phone'),
      industry: r.readNullable<String>('industry'),
      budgetLevel: r.readNullable<String>('budget_level'),
      isDecisionMaker: (r.readNullable<int>('is_decision_maker') ?? 0) == 1,
      lifeCycleStage: r.readNullable<String>('life_cycle_stage') ?? 'lead',
      riskScore: r.readNullable<int>('risk_score') ?? 0,
      notes: r.readNullable<String>('notes'),
      preferredChannel: r.readNullable<String>('preferred_channel'),
      totalRevenue: r.readNullable<double>('total_revenue') ?? 0,
    );
  }

  @override
  Future<List<CustomerProfile>> listCustomers() async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM customer_profiles ORDER BY updated_at DESC',
          readsFrom: {},
        )
        .get();
    return rows.map(_rowToCustomer).toList();
  }

  @override
  Future<void> upsertCustomer(CustomerProfile profile) async {
    await _db.customStatement(
      '''
      INSERT INTO customer_profiles(id, name, segment, tags_json, last_contact_at, created_at, updated_at,
        company, email, phone, industry, budget_level, is_decision_maker, life_cycle_stage, risk_score, notes, preferred_channel, total_revenue)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name=excluded.name, segment=excluded.segment, tags_json=excluded.tags_json,
        last_contact_at=excluded.last_contact_at, updated_at=excluded.updated_at,
        company=excluded.company, email=excluded.email, phone=excluded.phone,
        industry=excluded.industry, budget_level=excluded.budget_level,
        is_decision_maker=excluded.is_decision_maker, life_cycle_stage=excluded.life_cycle_stage,
        risk_score=excluded.risk_score, notes=excluded.notes,
        preferred_channel=excluded.preferred_channel, total_revenue=excluded.total_revenue
      ''',
      [
        profile.id, profile.name, profile.segment, jsonEncode(profile.tags),
        profile.lastContactAt?.millisecondsSinceEpoch,
        profile.createdAt.millisecondsSinceEpoch,
        profile.updatedAt.millisecondsSinceEpoch,
        profile.company, profile.email, profile.phone,
        profile.industry, profile.budgetLevel,
        profile.isDecisionMaker ? 1 : 0, profile.lifeCycleStage,
        profile.riskScore, profile.notes,
        profile.preferredChannel, profile.totalRevenue,
      ],
    );
  }
}
