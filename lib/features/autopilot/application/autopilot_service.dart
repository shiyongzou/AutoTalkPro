import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/conversation.dart';
import '../../../core/models/message.dart';
import '../../../core/models/negotiation_context.dart';
import '../../../core/models/sentiment_record.dart';
import '../../ai/application/ai_conversation_engine.dart';
import '../../conversation/application/intent_classifier_service.dart';
import '../../conversation/application/response_cadence_policy.dart';
import '../../escalation/application/escalation_service.dart';
import '../../message/domain/message_repository.dart';
import '../../negotiation/application/negotiation_engine.dart';
import '../../product/application/pricing_engine.dart';
import '../../qa/application/message_qa_service.dart';
import '../../sentiment/application/sentiment_analyzer.dart';
import '../../sentiment/domain/sentiment_repository.dart';

enum AutopilotMode { auto, semiAuto, manual }

class AutopilotResult {
  const AutopilotResult({
    required this.reply,
    required this.sentiment,
    required this.negotiation,
    required this.intentClassification,
    required this.cadenceDecision,
    required this.escalationResult,
    required this.qaResult,
    required this.autoSend,
    required this.holdReason,
  });

  final ConversationReply reply;
  final SentimentRecord sentiment;
  final NegotiationContext? negotiation;
  final IntentClassification intentClassification;
  final CadenceDecision cadenceDecision;
  final EscalationCheckResult escalationResult;
  final QaCheckResult? qaResult;
  final bool autoSend;
  final String? holdReason;
}

class AutopilotService {
  const AutopilotService({
    required this.aiEngine,
    required this.sentimentAnalyzer,
    required this.sentimentRepository,
    required this.negotiationEngine,
    required this.escalationService,
    required this.intentClassifier,
    required this.cadencePolicy,
    required this.qaService,
    required this.pricingEngine,
    required this.messageRepository,
    this.autoSendConfidenceThreshold = 0.7,
  });

  final AiConversationEngine aiEngine;
  final SentimentAnalyzer sentimentAnalyzer;
  final SentimentRepository sentimentRepository;
  final NegotiationEngine negotiationEngine;
  final EscalationService escalationService;
  final IntentClassifierService intentClassifier;
  final ResponseCadencePolicy cadencePolicy;
  final MessageQaService qaService;
  final PricingEngine pricingEngine;
  final MessageRepository messageRepository;
  final double autoSendConfidenceThreshold;

  /// 处理收到的客户消息，运行完整的 AI 销售管线
  Future<AutopilotResult> processIncomingMessage({
    required Conversation conversation,
    required Message incomingMessage,
    required AutopilotMode mode,
    NegotiationContext? existingNegotiation,
  }) async {
    // ── Step 1: 情绪分析 ──
    final sentiment = sentimentAnalyzer.analyze(
      conversationId: conversation.id,
      message: incomingMessage,
    );
    await sentimentRepository.add(sentiment);

    // ── Step 2: 意图识别 ──
    final allMessages = await messageRepository.listMessages(conversation.id);
    // 避免重复：如果消息已经在DB中（调用方已persist），不再追加
    final alreadyInDb = allMessages.any((m) => m.id == incomingMessage.id);
    final messagesWithIncoming = alreadyInDb
        ? allMessages
        : [...allMessages, incomingMessage];
    final intentClassification = intentClassifier.classify(messagesWithIncoming);

    // ── Step 3: 节奏策略 ──
    final cadenceDecision = cadencePolicy.evaluate(
      classification: intentClassification,
      messages: messagesWithIncoming,
    );

    // ── Step 4: 谈判引擎 ──
    NegotiationContext? negotiation = existingNegotiation;
    NegotiationDecision? negotiationDecision;
    String? priceQuoteInfo;

    if (negotiation != null) {
      negotiationDecision = await negotiationEngine.processMessage(
        context: negotiation,
        customerMessage: incomingMessage,
      );
      negotiation = negotiationDecision.updatedContext;
      if (negotiationDecision.priceQuote != null) {
        priceQuoteInfo = pricingEngine.formatQuoteForAi(
          negotiationDecision.priceQuote!,
        );
      }
    }

    // ── Step 5: 读取当前人设 ──
    String? personaPrompt;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('personas');
      final activeIdx = prefs.getInt('active_persona');
      if (raw != null && activeIdx != null) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        if (activeIdx < list.length) {
          final p = list[activeIdx];
          final buf = StringBuffer();
          // 读取字段，把字面量\n替换成真正的换行
          String clean(String? s) => (s ?? '').replaceAll(r'\n', '\n').trim();

          if (clean(p['profession']).isNotEmpty) {
            buf.writeln('你的职业是: ${clean(p['profession'])}');
          }
          if (clean(p['expertise']).isNotEmpty) {
            buf.writeln(clean(p['expertise']));
          }
          if (clean(p['aiName']).isNotEmpty) {
            buf.writeln('你的名字是: ${clean(p['aiName'])}');
          }
          if (clean(p['style']).isNotEmpty) {
            buf.writeln('说话风格: ${clean(p['style'])}');
          }
          final rules = (p['rules'] as List?)?.cast<String>() ?? [];
          for (final r in rules) {
            if (clean(r).isNotEmpty) buf.writeln(clean(r));
          }
          personaPrompt = buf.toString().trim();
        }
      }
    } catch (_) {}

    // ── Step 6: AI 生成回复 ──
    final reply = await aiEngine.generateReply(
      customerName: conversation.customerId,
      conversationHistory: messagesWithIncoming,
      goalStage: conversation.goalStage,
      negotiation: negotiation,
      latestSentiment: sentiment,
      priceQuoteInfo: priceQuoteInfo,
      personaPrompt: personaPrompt,
    );

    // ── Step 6: QA 检查 ──
    final qaResult = qaService.evaluate(
      text: reply.content,
      conversationId: conversation.id,
      peerId: conversation.customerId,
    );

    // ── Step 7: 升级检查 ──
    final escalationResult = await escalationService.evaluate(
      conversationId: conversation.id,
      customerId: conversation.customerId,
      message: incomingMessage,
      sentiment: sentiment,
      negotiation: negotiation,
      negotiationEscalateReason: negotiationDecision?.shouldEscalate == true
          ? negotiationDecision?.escalateReason
          : null,
      aiConfidence: reply.confidence,
    );

    // ── Step 8: 决定是否自动发送 ──
    bool autoSend = false;
    String? holdReason;

    if (mode == AutopilotMode.manual) {
      // 手动模式：生成回复但不发，塞到输入框让用户确认
      holdReason = '手动模式';
    } else if (mode == AutopilotMode.auto) {
      // 全自动：只要QA通过就发，不管置信度
      if (!qaResult.pass) {
        holdReason = 'QA拦截: ${qaResult.blockReasons.join("；")}';
      } else {
        autoSend = true;
      }
    } else if (mode == AutopilotMode.semiAuto) {
      // 半自动：QA通过+置信度够+无风险才发
      if (!qaResult.pass) {
        holdReason = 'QA拦截: ${qaResult.blockReasons.join("；")}';
      } else if (escalationResult.shouldEscalate) {
        holdReason = '触发升级';
      } else if (reply.confidence >= 0.8) {
        autoSend = true;
      } else {
        holdReason = '需人工确认';
      }
    }

    return AutopilotResult(
      reply: reply,
      sentiment: sentiment,
      negotiation: negotiation,
      intentClassification: intentClassification,
      cadenceDecision: cadenceDecision,
      escalationResult: escalationResult,
      qaResult: qaResult,
      autoSend: autoSend,
      holdReason: holdReason,
    );
  }
}
