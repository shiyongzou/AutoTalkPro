import 'package:flutter_test/flutter_test.dart';

import 'package:tg_ai_sales_desktop/core/models/conversation.dart';
import 'package:tg_ai_sales_desktop/core/models/message.dart';
import 'package:tg_ai_sales_desktop/core/persistence/drift_local_database.dart';
import 'package:tg_ai_sales_desktop/features/ai/application/ai_draft_service.dart';
import 'package:tg_ai_sales_desktop/features/ai/data/in_memory_ai_settings_repository.dart';
import 'package:tg_ai_sales_desktop/features/audit/data/drift_audit_repository.dart';
import 'package:tg_ai_sales_desktop/features/channel/application/channel_manager.dart';
import 'package:tg_ai_sales_desktop/features/channel/domain/channel_adapter.dart';
import 'package:tg_ai_sales_desktop/features/conversation/application/conversation_draft_advisor_service.dart';
import 'package:tg_ai_sales_desktop/features/conversation/application/intent_classifier_service.dart';
import 'package:tg_ai_sales_desktop/features/conversation/application/response_cadence_policy.dart';
import 'package:tg_ai_sales_desktop/features/conversation/data/drift_conversation_repository.dart';
import 'package:tg_ai_sales_desktop/features/knowledge/application/weekly_communication_advisor.dart';
import 'package:tg_ai_sales_desktop/features/knowledge/data/drift_knowledge_center_repository.dart';
import 'package:tg_ai_sales_desktop/features/message/data/drift_message_repository.dart';
import 'package:tg_ai_sales_desktop/features/outbound/application/outbound_dispatch_service.dart';
import 'package:tg_ai_sales_desktop/features/outbound/data/drift_dispatch_guard_repository.dart';
import 'package:tg_ai_sales_desktop/features/qa/application/message_qa_service.dart';
import 'package:tg_ai_sales_desktop/features/release/application/release_gate_service.dart';
import 'package:tg_ai_sales_desktop/features/telegram/data/mock_telegram_adapter.dart';
import 'package:tg_ai_sales_desktop/features/telegram/domain/telegram_config.dart';
import 'package:tg_ai_sales_desktop/features/template/application/template_import_service.dart';
import 'package:tg_ai_sales_desktop/features/template/data/drift_template_repository.dart';
import 'package:tg_ai_sales_desktop/features/template/domain/template_scope.dart';
import 'package:tg_ai_sales_desktop/features/wecom/domain/wecom_config.dart';

const _templateRaw = '''
{
  "meta": {
    "name": "端到端关键流程模板",
    "industry": "cross_border",
    "version": "1.0.0",
    "author": "qa",
    "description": "用于关键业务链路回归",
    "compatibleSchema": "1.0"
  },
  "persona": {
    "role": "资深顾问",
    "tone": "专业",
    "style": "简洁推进",
    "forbiddenPromises": ["保证收益", "承诺绝对结果"]
  },
  "script": {
    "goals": ["收集需求", "推进报价"],
    "stages": [
      {
        "key": "discover",
        "description": "确认预算和时效",
        "enterWhen": ["客户询问报价"],
        "exitWhen": ["明确预算"]
      }
    ]
  },
  "policy": {
    "mode": "L1",
    "handoffRules": ["客户投诉", "客户索要合同"],
    "riskKeywords": ["投诉", "退款"]
  },
  "kpi": {
    "metrics": ["推进率"],
    "reportCadence": ["daily"]
  }
}
''';

void main() {
  group('critical chain integration', () {
    test(
      'template -> intent -> cadence -> QA -> send -> audit -> release gate pass',
      () async {
        final db = await DriftLocalDatabase.inMemory();
        addTearDown(db.close);

        final templateRepo = DriftTemplateRepository(
          db,
          TemplateImportService(),
        );
        final conversationRepo = DriftConversationRepository(db);
        final messageRepo = DriftMessageRepository(db);
        final auditRepo = DriftAuditRepository(db);
        final dispatchGuardRepo = DriftDispatchGuardRepository(db);
        final knowledgeRepo = DriftKnowledgeCenterRepository(db);

        final imported = await templateRepo.importTemplate(
          scope: const TemplateScope(level: TemplateScopeLevel.system),
          raw: _templateRaw,
        );
        expect(imported.ok, isTrue);
        expect(imported.record?.active, isTrue);

        const conversationId = 'conv_e2e_001';
        const peerId = 'tg_90001';
        final now = DateTime.now();

        await conversationRepo.upsertConversation(
          Conversation(
            id: conversationId,
            customerId: peerId,
            title: '客户A',
            status: 'active',
            goalStage: 'discover',
            lastMessageAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await messageRepo.addMessage(
          Message(
            id: 'msg_customer_1',
            conversationId: conversationId,
            role: 'customer',
            content: '这个套餐价格多少？多久可以开通？',
            sentAt: now,
            riskFlag: false,
          ),
        );

        final aiDraftService = AiDraftService(
          settingsRepository: InMemoryAiSettingsRepository(),
          weeklyCommunicationAdvisor: WeeklyCommunicationAdvisor(
            repository: knowledgeRepo,
          ),
        );

        final advisor = ConversationDraftAdvisorService(
          aiDraftService: aiDraftService,
          intentClassifier: const IntentClassifierService(),
          cadencePolicy: const ResponseCadencePolicy(),
        );

        final history = await messageRepo.listMessages(conversationId);
        final advice = await advisor.buildAdvice(
          customerName: '客户A',
          goalStage: 'discover',
          messages: history,
        );

        expect(advice.draft, isNotNull);
        expect(
          advice.classification.intent,
          ConversationIntent.businessPromotion,
        );
        expect(advice.cadenceDecision.action, CadenceAction.draftNow);

        final qa = const MessageQaService().evaluate(
          text: advice.draft!.content,
          conversationId: conversationId,
          peerId: peerId,
        );
        expect(qa.pass, isTrue);

        final channelManager = ChannelManager(
          adapters: {ChannelType.telegram: const MockTelegramAdapter()},
          initialChannel: ChannelType.telegram,
        );

        final dispatchService = OutboundDispatchService(
          qaService: const MessageQaService(),
          channelManager: channelManager,
          messageRepository: messageRepo,
          auditRepository: auditRepo,
          conversationRepository: conversationRepo,
          dispatchGuardRepository: dispatchGuardRepo,
          maxAttempts: 1,
        );

        final sendResult = await dispatchService.sendWithQa(
          requestId: 'req_e2e_001',
          conversationId: conversationId,
          peerId: peerId,
          content: advice.draft!.content,
          metadata: {
            'flow': 'critical_e2e',
            'operator': 'e2e_bot',
            'templateVersion': imported.record?.version,
            'model': aiDraftService.settings.model,
          },
        );

        expect(sendResult.sent, isTrue);

        final allMessages = await messageRepo.listMessages(conversationId);
        expect(allMessages.length, 2);
        expect(allMessages.last.role, 'assistant');

        final auditLogs = await auditRepo.listByConversation(conversationId);
        final stages = auditLogs.map((e) => e.stage).toSet();
        expect(stages, contains('idempotency_reserve'));
        expect(stages, contains('qa'));
        expect(stages, contains('send_attempt'));
        expect(stages, contains('send'));

        final sendAudit = auditLogs.firstWhere((e) => e.stage == 'send');
        expect(sendAudit.status, 'success');
        expect(sendAudit.requestId, 'req_e2e_001');
        expect(sendAudit.operator, 'e2e_bot');
        expect(sendAudit.channel, 'telegram');
        expect(sendAudit.templateVersion, imported.record?.version);
        expect(sendAudit.model, aiDraftService.settings.model);
        expect((sendAudit.latencyMs ?? -1) >= 0, isTrue);

        final gateResult = await const ReleaseGateService().evaluate(
          channelManager: channelManager,
          telegramConfig: TelegramConfig.defaults(),
          weComConfig: WeComConfig.stub(),
          qaEnabled: qa.pass,
          dispatchIdempotencyEnabled: true,
          auditEnabled: auditLogs.isNotEmpty,
          analyzePassed: true,
          testsPassed: true,
          uiStyleConsistencyPassed: true,
          uiStyleViolationCount: 0,
          uiTokenCoverage: 0.95,
          criticalTestCoverage: 92,
        );

        expect(gateResult.passed, isTrue);
        expect(gateResult.blockers, isEmpty);
      },
    );

    test(
      'critical chain blocks at QA and release gate when forbidden promise appears',
      () async {
        final db = await DriftLocalDatabase.inMemory();
        addTearDown(db.close);

        final templateRepo = DriftTemplateRepository(
          db,
          TemplateImportService(),
        );
        final conversationRepo = DriftConversationRepository(db);
        final messageRepo = DriftMessageRepository(db);
        final auditRepo = DriftAuditRepository(db);
        final dispatchGuardRepo = DriftDispatchGuardRepository(db);
        final knowledgeRepo = DriftKnowledgeCenterRepository(db);

        final imported = await templateRepo.importTemplate(
          scope: const TemplateScope(level: TemplateScopeLevel.system),
          raw: _templateRaw,
        );
        expect(imported.ok, isTrue);

        const conversationId = 'conv_e2e_qa_block';
        const peerId = 'tg_90002';
        final now = DateTime.now();

        await conversationRepo.upsertConversation(
          Conversation(
            id: conversationId,
            customerId: peerId,
            title: '客户B',
            status: 'active',
            goalStage: 'discover',
            lastMessageAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await messageRepo.addMessage(
          Message(
            id: 'msg_customer_qa_block',
            conversationId: conversationId,
            role: 'customer',
            content: '报价发我，我今天就确认。',
            sentAt: now,
            riskFlag: false,
          ),
        );

        final aiDraftService = AiDraftService(
          settingsRepository: InMemoryAiSettingsRepository(),
          weeklyCommunicationAdvisor: WeeklyCommunicationAdvisor(
            repository: knowledgeRepo,
          ),
        );

        final advisor = ConversationDraftAdvisorService(
          aiDraftService: aiDraftService,
          intentClassifier: const IntentClassifierService(),
          cadencePolicy: const ResponseCadencePolicy(),
        );

        final history = await messageRepo.listMessages(conversationId);
        final advice = await advisor.buildAdvice(
          customerName: '客户B',
          goalStage: 'discover',
          messages: history,
        );

        final riskyContent = '${advice.draft!.content} 我保证收益';
        final qa = const MessageQaService().evaluate(
          text: riskyContent,
          conversationId: conversationId,
          peerId: peerId,
        );
        expect(qa.pass, isFalse);

        final channelManager = ChannelManager(
          adapters: {ChannelType.telegram: const MockTelegramAdapter()},
          initialChannel: ChannelType.telegram,
        );

        final dispatchService = OutboundDispatchService(
          qaService: const MessageQaService(),
          channelManager: channelManager,
          messageRepository: messageRepo,
          auditRepository: auditRepo,
          conversationRepository: conversationRepo,
          dispatchGuardRepository: dispatchGuardRepo,
          maxAttempts: 1,
        );

        final sendResult = await dispatchService.sendWithQa(
          requestId: 'req_e2e_qa_block',
          conversationId: conversationId,
          peerId: peerId,
          content: riskyContent,
          metadata: {
            'flow': 'critical_e2e_qa_block',
            'operator': 'e2e_bot',
            'templateVersion': imported.record?.version,
            'model': aiDraftService.settings.model,
          },
        );

        expect(sendResult.sent, isFalse);
        expect(sendResult.blocked, isTrue);
        expect(sendResult.reason, contains('命中禁止词'));

        final logs = await auditRepo.listByConversation(conversationId);
        final qaAudit = logs.firstWhere((e) => e.stage == 'qa');
        expect(qaAudit.status, 'blocked');
        expect(logs.where((e) => e.stage == 'send'), isEmpty);

        final gateResult = await const ReleaseGateService().evaluate(
          channelManager: channelManager,
          telegramConfig: TelegramConfig.defaults(),
          weComConfig: WeComConfig.stub(),
          qaEnabled: qa.pass,
          dispatchIdempotencyEnabled: true,
          auditEnabled: logs.isNotEmpty,
          analyzePassed: true,
          testsPassed: true,
        );

        expect(gateResult.passed, isFalse);
        expect(gateResult.blockers.join(','), contains('发送前QA拦截'));
      },
    );
  });
}
