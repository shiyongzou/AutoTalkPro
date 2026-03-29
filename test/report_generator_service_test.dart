import 'package:flutter_test/flutter_test.dart';

import 'package:tg_ai_sales_desktop/core/models/conversation.dart';
import 'package:tg_ai_sales_desktop/core/models/customer_profile.dart';
import 'package:tg_ai_sales_desktop/core/models/message.dart';
import 'package:tg_ai_sales_desktop/features/conversation/domain/conversation_repository.dart';
import 'package:tg_ai_sales_desktop/features/message/domain/message_repository.dart';
import 'package:tg_ai_sales_desktop/features/report/application/report_generator_service.dart';

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository(this.conversations);

  final List<Conversation> conversations;

  @override
  Future<Conversation?> getConversationById(String conversationId) async {
    for (final item in conversations) {
      if (item.id == conversationId) return item;
    }
    return null;
  }

  @override
  Future<List<Conversation>> listConversations() async => conversations;

  @override
  Future<List<CustomerProfile>> listCustomers() async => const [];

  @override
  Future<void> upsertConversation(Conversation conversation) async {}

  @override
  Future<void> upsertCustomer(CustomerProfile profile) async {}
}

class _FakeMessageRepository implements MessageRepository {
  _FakeMessageRepository(this.messagesByConversation);

  final Map<String, List<Message>> messagesByConversation;

  @override
  Future<void> addMessage(Message message) async {}

  @override
  Future<List<Message>> listMessages(String conversationId) async {
    return messagesByConversation[conversationId] ?? const [];
  }
}

void main() {
  test(
    'build includes funnel, risk trend and top risk conversations',
    () async {
      final now = DateTime.now();
      final conversations = [
        Conversation(
          id: 'c1',
          customerId: 'u1',
          title: '会话1',
          status: 'open',
          goalStage: 'discover',
          lastMessageAt: now,
          createdAt: now.subtract(const Duration(days: 3)),
          updatedAt: now,
        ),
        Conversation(
          id: 'c2',
          customerId: 'u2',
          title: '会话2',
          status: 'open',
          goalStage: 'proposal',
          lastMessageAt: now,
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now,
        ),
        Conversation(
          id: 'c3',
          customerId: 'u3',
          title: '会话3',
          status: 'open',
          goalStage: 'closing',
          lastMessageAt: now.subtract(const Duration(days: 8)),
          createdAt: now.subtract(const Duration(days: 8)),
          updatedAt: now.subtract(const Duration(days: 8)),
        ),
      ];

      final messages = {
        'c1': [
          Message(
            id: 'm1',
            conversationId: 'c1',
            role: 'customer',
            content: 'hello',
            sentAt: now.subtract(const Duration(days: 1)),
            riskFlag: true,
          ),
          Message(
            id: 'm2',
            conversationId: 'c1',
            role: 'assistant',
            content: 'ok',
            sentAt: now,
            riskFlag: false,
          ),
        ],
        'c2': [
          Message(
            id: 'm3',
            conversationId: 'c2',
            role: 'customer',
            content: 'price',
            sentAt: now.subtract(const Duration(days: 2)),
            riskFlag: true,
          ),
          Message(
            id: 'm4',
            conversationId: 'c2',
            role: 'customer',
            content: 'refund',
            sentAt: now.subtract(const Duration(days: 2, hours: 1)),
            riskFlag: true,
          ),
        ],
        'c3': [
          Message(
            id: 'm5',
            conversationId: 'c3',
            role: 'assistant',
            content: 'safe',
            sentAt: now.subtract(const Duration(days: 10)),
            riskFlag: false,
          ),
        ],
      };

      final service = ReportGeneratorService(
        conversationRepository: _FakeConversationRepository(conversations),
        messageRepository: _FakeMessageRepository(messages),
      );

      final summary = await service.build(ReportPeriod.daily);

      expect(summary.totalConversations, 3);
      expect(summary.activeConversations, 2);
      expect(summary.riskConversations, 2);
      expect(summary.totalMessages, 5);

      expect(summary.stageFunnel.length, 3);
      expect(summary.stageFunnel[0].stage, 'discover');
      expect(summary.stageFunnel[1].stage, 'proposal');
      expect(summary.stageFunnel[2].stage, 'closing');
      expect(summary.stageFunnel[0].conversionFromPrevious, 1.0);

      expect(summary.riskTrend.length, 7);
      final riskTotal = summary.riskTrend.fold<int>(
        0,
        (sum, p) => sum + p.count,
      );
      expect(riskTotal, 3);

      expect(summary.topRiskConversations.length, 2);
      expect(summary.topRiskConversations.first.conversationId, 'c2');
      expect(summary.topRiskConversations.first.riskMessageCount, 2);

      expect(summary.topRiskCustomers.length, 2);
      expect(summary.topRiskCustomers.first.customerId, 'u2');
      expect(summary.topRiskCustomers.first.riskMessageCount, 2);

      expect(summary.toJson()['stageFunnel'], isA<List<dynamic>>());
      expect(summary.toJson()['topRiskCustomers'], isA<List<dynamic>>());
      final markdown = summary.toMarkdown();
      expect(markdown, contains('## 漏斗阶段转化'));
      expect(markdown, contains('## 风险趋势'));
      expect(markdown, contains('## Top 风险会话'));
      expect(markdown, contains('## Top 高风险客户'));
      expect(markdown, contains('会话2（c2）风险消息 2/2'));
    },
  );
}
