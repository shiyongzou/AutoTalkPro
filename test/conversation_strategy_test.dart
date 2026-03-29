import 'package:flutter_test/flutter_test.dart';
import 'package:tg_ai_sales_desktop/core/models/message.dart';
import 'package:tg_ai_sales_desktop/features/conversation/application/intent_classifier_service.dart';
import 'package:tg_ai_sales_desktop/features/conversation/application/response_cadence_policy.dart';

void main() {
  group('IntentClassifierService', () {
    const classifier = IntentClassifierService();

    test('classifies risk complaint intent', () {
      final result = classifier.classify([
        _customerMessage('你们这个服务是骗局吗？我要投诉并退款'),
      ]);

      expect(result.intent, ConversationIntent.riskComplaint);
      expect(result.hitKeywords, contains('投诉'));
    });

    test('classifies business promotion intent', () {
      final result = classifier.classify([
        _customerMessage('你们套餐价格多少？今天可以签合同吗'),
      ]);

      expect(result.intent, ConversationIntent.businessPromotion);
    });

    test('classifies relationship maintenance intent', () {
      final result = classifier.classify([_customerMessage('最近辛苦啦，感谢一直跟进')]);

      expect(result.intent, ConversationIntent.relationshipMaintenance);
    });

    test('uses recent business context for carry-over short reply', () {
      final base = DateTime(2026, 3, 26, 9, 0);
      final result = classifier.classify([
        _customerMessage('你这边套餐报价能给我一份吗', sentAt: base),
        _assistantMessage(
          '可以，我先发你标准版和进阶版方案',
          sentAt: base.add(const Duration(minutes: 1)),
        ),
        _customerMessage(
          '收到，周五再聊细节',
          sentAt: base.add(const Duration(minutes: 3)),
        ),
      ]);

      expect(result.intent, ConversationIntent.businessPromotion);
      expect(result.reason, contains('业务上下文'));
    });

    test('falls back to small talk intent', () {
      final result = classifier.classify([_customerMessage('哈哈在吗')]);

      expect(result.intent, ConversationIntent.smallTalk);
    });
  });

  group('ResponseCadencePolicy', () {
    const policy = ResponseCadencePolicy();
    final now = DateTime(2026, 3, 26, 10, 0);

    test('recommends immediate draft for direct business question', () {
      final decision = policy.evaluate(
        classification: const IntentClassification(
          intent: ConversationIntent.businessPromotion,
          confidence: 0.9,
          reason: 'business',
        ),
        messages: [
          _customerMessage(
            '价格多少？',
            sentAt: now.subtract(const Duration(minutes: 2)),
          ),
        ],
        now: now,
      );

      expect(decision.action, CadenceAction.draftNow);
      expect(decision.suggestedDelay, isNull);
      expect(decision.strategyWeight, 0.9);
    });

    test(
      'adds short pause for non-question business follow-up in active chat',
      () {
        final decision = policy.evaluate(
          classification: const IntentClassification(
            intent: ConversationIntent.businessPromotion,
            confidence: 0.74,
            reason: 'carry-over business',
          ),
          messages: [
            _customerMessage(
              '收到，周五再聊细节',
              sentAt: now.subtract(const Duration(minutes: 4)),
            ),
          ],
          now: now,
        );

        expect(decision.action, CadenceAction.suggestDelay);
        expect(decision.suggestedDelay, const Duration(minutes: 3));
        expect(decision.rhythmHint, contains('轻推进'));
      },
    );

    test('recommends delayed response for relationship maintenance', () {
      final decision = policy.evaluate(
        classification: const IntentClassification(
          intent: ConversationIntent.relationshipMaintenance,
          confidence: 0.8,
          reason: 'relationship',
        ),
        messages: [
          _customerMessage(
            '最近辛苦啦',
            sentAt: now.subtract(const Duration(minutes: 3)),
          ),
        ],
        now: now,
      );

      expect(decision.action, CadenceAction.suggestDelay);
      expect(decision.suggestedDelay, const Duration(minutes: 8));
      expect(decision.strategyWeight, closeTo(0.78, 0.001));
    });

    test(
      'recommends skip for low-value small talk without business context',
      () {
        final decision = policy.evaluate(
          classification: const IntentClassification(
            intent: ConversationIntent.smallTalk,
            confidence: 0.6,
            reason: 'smallTalk',
          ),
          messages: [
            _customerMessage(
              '嗯',
              sentAt: now.subtract(const Duration(minutes: 1)),
            ),
          ],
          now: now,
        );

        expect(decision.action, CadenceAction.suggestSkip);
      },
    );

    test(
      'sample dialogue: small talk keeps business continuity instead of skip',
      () {
        final decision = policy.evaluate(
          classification: const IntentClassification(
            intent: ConversationIntent.smallTalk,
            confidence: 0.68,
            reason: 'short idle ping',
          ),
          messages: [
            _customerMessage(
              '你们套餐价格和开通周期给我一下',
              sentAt: now.subtract(const Duration(minutes: 20)),
            ),
            _assistantMessage(
              '标准版 2999/月，今天确认可当日开通',
              sentAt: now.subtract(const Duration(minutes: 17)),
            ),
            _customerMessage(
              '好的',
              sentAt: now.subtract(const Duration(minutes: 2)),
            ),
          ],
          now: now,
        );

        expect(decision.action, CadenceAction.suggestDelay);
        expect(decision.suggestedDelay, const Duration(minutes: 10));
        expect(decision.reason, contains('业务上下文'));
        expect(decision.rhythmHint, contains('先接住闲聊'));
      },
    );
  });
}

Message _customerMessage(String content, {DateTime? sentAt}) {
  final now = sentAt ?? DateTime.now();
  return Message(
    id: 'm_${content.hashCode}_${now.millisecondsSinceEpoch}',
    conversationId: 'c1',
    role: 'customer',
    content: content,
    sentAt: now,
    riskFlag: false,
  );
}

Message _assistantMessage(String content, {DateTime? sentAt}) {
  final now = sentAt ?? DateTime.now();
  return Message(
    id: 'a_${content.hashCode}_${now.millisecondsSinceEpoch}',
    conversationId: 'c1',
    role: 'assistant',
    content: content,
    sentAt: now,
    riskFlag: false,
  );
}
