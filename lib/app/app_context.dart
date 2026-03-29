import '../core/persistence/drift_local_database.dart';
import '../features/channel/application/message_bridge.dart';
import '../features/wechatbot/application/wechat_message_listener.dart';
import '../features/ai/application/ai_conversation_engine.dart';
import '../features/ai/application/ai_draft_service.dart';
import '../features/order/application/order_service.dart';
import '../features/script/data/drift_script_repository.dart';
import '../features/script/domain/script_repository.dart';
import '../features/order/application/quick_quote_service.dart';
import '../features/order/data/drift_order_repository.dart';
import '../features/order/domain/order_repository.dart';
import '../features/ai/data/in_memory_ai_settings_repository.dart';
import '../features/ai/data/local_ai_settings_repository.dart';
import '../features/ai/domain/ai_settings_repository.dart';
import '../features/audit/data/drift_audit_repository.dart';
import '../features/audit/domain/audit_repository.dart';
import '../features/autopilot/application/autopilot_service.dart';
import '../features/channel/application/channel_manager.dart';
import '../features/channel/domain/channel_adapter.dart';
import '../features/conversation/application/conversation_draft_advisor_service.dart';
import '../features/conversation/application/intent_classifier_service.dart';
import '../features/conversation/application/response_cadence_policy.dart';
import '../features/conversation/data/drift_conversation_repository.dart';
import '../features/conversation/domain/conversation_repository.dart';
import '../features/escalation/application/escalation_service.dart';
import '../features/escalation/data/drift_escalation_repository.dart';
import '../features/escalation/domain/escalation_repository.dart';
import '../features/goal/application/goal_engine_service.dart';
import '../features/knowledge/application/weekly_communication_advisor.dart';
import '../features/knowledge/data/drift_knowledge_center_repository.dart';
import '../features/knowledge/domain/knowledge_center_repository.dart';
import '../features/message/data/drift_message_repository.dart';
import '../features/message/domain/message_repository.dart';
import '../features/negotiation/application/negotiation_engine.dart';
import '../features/negotiation/data/drift_negotiation_repository.dart';
import '../features/negotiation/domain/negotiation_repository.dart';
import '../features/notification/application/notification_service.dart';
import '../features/outbound/application/outbound_dispatch_service.dart';
import '../features/outbound/data/drift_dispatch_guard_repository.dart';
import '../features/outbound/domain/dispatch_guard_repository.dart';
import '../features/product/application/pricing_engine.dart';
import '../features/product/data/drift_product_repository.dart';
import '../features/product/domain/product_repository.dart';
import '../features/qa/application/message_qa_service.dart';
import '../features/release/application/release_gate_service.dart';
import '../features/report/application/report_generator_service.dart';
import '../features/risk/application/risk_radar_service.dart';
import '../features/sentiment/application/sentiment_analyzer.dart';
import '../features/sentiment/data/drift_sentiment_repository.dart';
import '../features/sentiment/domain/sentiment_repository.dart';
import '../features/telegram/data/gramjs_telegram_adapter.dart';
import '../features/telegram/data/local_telegram_config_repository.dart';
import '../features/telegram/domain/telegram_config.dart';
import '../features/telegram/domain/telegram_config_repository.dart';
import '../features/wecom/application/wecom_message_listener.dart';
import '../features/wecom/data/local_wecom_config_repository.dart';
import '../features/wecom/data/wecom_adapter.dart';
import '../features/wecom/domain/wecom_config.dart';
import '../features/wecom/domain/wecom_config_repository.dart';
import '../features/wechatbot/data/wechat_bot_adapter.dart';
import '../features/wechatbot/domain/wechat_bot_config.dart';
import '../features/wechatbot/application/wechat_service_manager.dart';
import '../features/template/application/template_import_service.dart';
import '../features/template/data/drift_template_repository.dart';
import '../features/template/domain/template_repository.dart';

class AppContext {
  AppContext._({
    required this.database,
    required this.templateRepository,
    required this.conversationRepository,
    required this.messageRepository,
    required this.knowledgeCenterRepository,
    required this.weeklyCommunicationAdvisor,
    required this.goalEngine,
    required this.riskRadar,
    required this.reportGenerator,
    required this.releaseGateService,
    required this.aiDraftService,
    required this.aiConversationEngine,
    required this.intentClassifier,
    required this.responseCadencePolicy,
    required this.conversationDraftAdvisor,
    required this.channelManager,
    required this.auditRepository,
    required this.qaService,
    required this.outboundDispatch,
    required this.dispatchGuardRepository,
    required this.weComConfigRepository,
    required this.weComConfig,
    required this.telegramConfigRepository,
    required this.telegramConfig,
    // V2: 新模块
    required this.productRepository,
    required this.pricingEngine,
    required this.negotiationRepository,
    required this.negotiationEngine,
    required this.sentimentAnalyzer,
    required this.sentimentRepository,
    required this.escalationRepository,
    required this.escalationService,
    required this.autopilotService,
    required this.notificationService,
    required this.orderRepository,
    required this.orderService,
    required this.quickQuoteService,
    required this.scriptRepository,
    required this.weChatMessageListener,
    required this.weComMessageListener,
    required this.messageBridge,
  });

  final DriftLocalDatabase database;
  final TemplateRepository templateRepository;
  final ConversationRepository conversationRepository;
  final MessageRepository messageRepository;
  final KnowledgeCenterRepository knowledgeCenterRepository;
  final WeeklyCommunicationAdvisor weeklyCommunicationAdvisor;
  final GoalEngineService goalEngine;
  final RiskRadarService riskRadar;
  final ReportGeneratorService reportGenerator;
  final ReleaseGateService releaseGateService;
  final AiDraftService aiDraftService;
  final AiConversationEngine aiConversationEngine;
  final IntentClassifierService intentClassifier;
  final ResponseCadencePolicy responseCadencePolicy;
  final ConversationDraftAdvisorService conversationDraftAdvisor;
  final ChannelManager channelManager;
  final AuditRepository auditRepository;
  final MessageQaService qaService;
  final OutboundDispatchService outboundDispatch;
  final DispatchGuardRepository dispatchGuardRepository;
  final WeComConfigRepository weComConfigRepository;
  WeComConfig weComConfig;
  final TelegramConfigRepository telegramConfigRepository;
  TelegramConfig telegramConfig;

  // V2: 新模块
  final ProductRepository productRepository;
  final PricingEngine pricingEngine;
  final NegotiationRepository negotiationRepository;
  final NegotiationEngine negotiationEngine;
  final SentimentAnalyzer sentimentAnalyzer;
  final SentimentRepository sentimentRepository;
  final EscalationRepository escalationRepository;
  final EscalationService escalationService;
  final AutopilotService autopilotService;
  final NotificationService notificationService;
  final OrderRepository orderRepository;
  final OrderService orderService;
  final QuickQuoteService quickQuoteService;
  final ScriptRepository scriptRepository;
  final WeChatMessageListener weChatMessageListener;
  final WeComMessageListener weComMessageListener;
  final MessageBridge messageBridge;

  Future<void> updateWeComConfig(WeComConfig config) async {
    await weComConfigRepository.save(config);
    weComConfig = config;
    weComMessageListener.updateConfig(config);
    channelManager.updateAdapter(WeComAdapter(config: config));
  }

  Future<void> updateTelegramConfig(TelegramConfig config) async {
    await telegramConfigRepository.save(config);
    telegramConfig = config;
    channelManager.updateAdapter(GramJsTelegramAdapter());
  }

  static Future<AppContext> create({String? accountId}) async {
    final db = await DriftLocalDatabase.open(accountId: accountId);
    final aiSettingsRepo = await LocalAiSettingsRepository.create();
    final weComConfigRepository = await LocalWeComConfigRepository.create();
    final telegramConfigRepository =
        await LocalTelegramConfigRepository.create();
    return _build(
      db,
      aiSettingsRepository: aiSettingsRepo,
      weComConfigRepository: weComConfigRepository,
      telegramConfigRepository: telegramConfigRepository,
    );
  }

  static Future<AppContext> testing() async {
    final db = await DriftLocalDatabase.inMemory();
    return _build(
      db,
      aiSettingsRepository: InMemoryAiSettingsRepository(),
      weComConfigRepository: _InMemoryWeComConfigRepository(),
      telegramConfigRepository: _InMemoryTelegramConfigRepository(),
    );
  }

  static Future<AppContext> _build(
    DriftLocalDatabase db, {
    required AiSettingsRepository aiSettingsRepository,
    required WeComConfigRepository weComConfigRepository,
    required TelegramConfigRepository telegramConfigRepository,
  }) async {
    final conversationRepository = DriftConversationRepository(db);
    final messageRepository = DriftMessageRepository(db);
    final auditRepository = DriftAuditRepository(db);
    final qaService = const MessageQaService();
    final weComConfig = await weComConfigRepository.load();
    final telegramConfig = await telegramConfigRepository.load();

    // WeChat adapter with the correct token matching WeChatServiceManager
    final weChatBotConfig = WeChatBotConfig(
      apiBase: 'http://localhost:${WeChatServiceManager.port}',
      token: WeChatServiceManager.token,
      enabled: true,
    );

    final channelManager = ChannelManager(
      adapters: {
        ChannelType.telegram: GramJsTelegramAdapter(),
        ChannelType.wecom: WeComAdapter(config: weComConfig),
        ChannelType.wechat: WeChatBotAdapter(config: weChatBotConfig),
      },
      initialChannel: ChannelType.telegram,
    );
    final dispatchGuardRepository = DriftDispatchGuardRepository(db);
    final knowledgeCenterRepository = DriftKnowledgeCenterRepository(db);
    final weeklyCommunicationAdvisor = WeeklyCommunicationAdvisor(
      repository: knowledgeCenterRepository,
    );
    await dispatchGuardRepository.recoverStuckSending(
      olderThan: const Duration(minutes: 5),
    );

    final aiDraftService = AiDraftService(
      settingsRepository: aiSettingsRepository,
      weeklyCommunicationAdvisor: weeklyCommunicationAdvisor,
    );
    await aiDraftService.restoreSettings();

    final aiConversationEngine = AiConversationEngine(
      settingsRepository: aiSettingsRepository,
      initialSettings: aiDraftService.settings,
    );
    await aiConversationEngine.restoreSettings();

    const intentClassifier = IntentClassifierService();
    const responseCadencePolicy = ResponseCadencePolicy();
    final conversationDraftAdvisor = ConversationDraftAdvisorService(
      aiDraftService: aiDraftService,
      intentClassifier: intentClassifier,
      cadencePolicy: responseCadencePolicy,
    );

    // V2: 新模块初始化
    final productRepository = DriftProductRepository(db);
    final pricingEngine = PricingEngine(productRepository: productRepository);
    final negotiationRepository = DriftNegotiationRepository(db);
    final negotiationEngine = NegotiationEngine(
      repository: negotiationRepository,
      pricingEngine: pricingEngine,
    );
    const sentimentAnalyzer = SentimentAnalyzer();
    final sentimentRepository = DriftSentimentRepository(db);
    final escalationRepository = DriftEscalationRepository(db);
    final escalationService = EscalationService(
      repository: escalationRepository,
    );
    final notificationService = NotificationService();

    final scriptRepository = DriftScriptRepository(db);
    final orderRepository = DriftOrderRepository(db);
    final weChatMessageListener = WeChatMessageListener();
    final weComMessageListener = WeComMessageListener(config: weComConfig);
    final orderService = OrderService(repository: orderRepository);
    final quickQuoteService = QuickQuoteService(
      productRepository: productRepository,
    );

    final autopilotService = AutopilotService(
      aiEngine: aiConversationEngine,
      sentimentAnalyzer: sentimentAnalyzer,
      sentimentRepository: sentimentRepository,
      negotiationEngine: negotiationEngine,
      escalationService: escalationService,
      intentClassifier: intentClassifier,
      cadencePolicy: responseCadencePolicy,
      qaService: qaService,
      pricingEngine: pricingEngine,
      messageRepository: messageRepository,
    );

    final messageBridge = MessageBridge(
      conversationRepository: conversationRepository,
      messageRepository: messageRepository,
      negotiationRepository: negotiationRepository,
      autopilotService: autopilotService,
      notificationService: notificationService,
      channelManager: channelManager,
    );

    return AppContext._(
      database: db,
      templateRepository: DriftTemplateRepository(db, TemplateImportService()),
      conversationRepository: conversationRepository,
      messageRepository: messageRepository,
      knowledgeCenterRepository: knowledgeCenterRepository,
      weeklyCommunicationAdvisor: weeklyCommunicationAdvisor,
      goalEngine: const GoalEngineService(),
      riskRadar: const RiskRadarService(),
      reportGenerator: ReportGeneratorService(
        conversationRepository: conversationRepository,
        messageRepository: messageRepository,
      ),
      releaseGateService: const ReleaseGateService(),
      aiDraftService: aiDraftService,
      aiConversationEngine: aiConversationEngine,
      intentClassifier: intentClassifier,
      responseCadencePolicy: responseCadencePolicy,
      conversationDraftAdvisor: conversationDraftAdvisor,
      channelManager: channelManager,
      auditRepository: auditRepository,
      qaService: qaService,
      outboundDispatch: OutboundDispatchService(
        qaService: qaService,
        channelManager: channelManager,
        messageRepository: messageRepository,
        auditRepository: auditRepository,
        conversationRepository: conversationRepository,
        dispatchGuardRepository: dispatchGuardRepository,
      ),
      dispatchGuardRepository: dispatchGuardRepository,
      weComConfigRepository: weComConfigRepository,
      weComConfig: weComConfig,
      telegramConfigRepository: telegramConfigRepository,
      telegramConfig: telegramConfig,
      // V2
      productRepository: productRepository,
      pricingEngine: pricingEngine,
      negotiationRepository: negotiationRepository,
      negotiationEngine: negotiationEngine,
      sentimentAnalyzer: sentimentAnalyzer,
      sentimentRepository: sentimentRepository,
      escalationRepository: escalationRepository,
      escalationService: escalationService,
      autopilotService: autopilotService,
      notificationService: notificationService,
      orderRepository: orderRepository,
      orderService: orderService,
      quickQuoteService: quickQuoteService,
      scriptRepository: scriptRepository,
      weChatMessageListener: weChatMessageListener,
      weComMessageListener: weComMessageListener,
      messageBridge: messageBridge,
    );
  }
}

class _InMemoryWeComConfigRepository implements WeComConfigRepository {
  WeComConfig _value = WeComConfig.stub();

  @override
  Future<WeComConfig> load() async => _value;

  @override
  Future<void> save(WeComConfig config) async {
    _value = config;
  }
}

class _InMemoryTelegramConfigRepository implements TelegramConfigRepository {
  TelegramConfig _value = TelegramConfig.defaults();

  @override
  Future<TelegramConfig> load() async => _value;

  @override
  Future<void> save(TelegramConfig config) async {
    _value = config;
  }
}
