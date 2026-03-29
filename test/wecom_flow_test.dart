import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tg_ai_sales_desktop/app/app_context.dart';
import 'package:tg_ai_sales_desktop/core/models/conversation.dart';
import 'package:tg_ai_sales_desktop/core/models/message.dart';
import 'package:tg_ai_sales_desktop/core/models/negotiation_context.dart';
import 'package:tg_ai_sales_desktop/core/models/sentiment_record.dart';
import 'package:tg_ai_sales_desktop/features/autopilot/application/autopilot_service.dart';
import 'package:tg_ai_sales_desktop/features/channel/application/channel_manager.dart';
import 'package:tg_ai_sales_desktop/features/channel/application/message_bridge.dart';
import 'package:tg_ai_sales_desktop/features/channel/domain/channel_adapter.dart';
import 'package:tg_ai_sales_desktop/features/conversation/application/intent_classifier_service.dart';
import 'package:tg_ai_sales_desktop/features/conversation/application/response_cadence_policy.dart';
import 'package:tg_ai_sales_desktop/features/escalation/application/escalation_service.dart';
import 'package:tg_ai_sales_desktop/features/notification/application/notification_service.dart';
import 'package:tg_ai_sales_desktop/features/qa/application/message_qa_service.dart';
import 'package:tg_ai_sales_desktop/features/ai/application/ai_conversation_engine.dart';
import 'package:tg_ai_sales_desktop/features/wecom/application/wecom_message_listener.dart';
import 'package:tg_ai_sales_desktop/features/wecom/domain/wecom_config.dart';

Future<HttpClientResponse> _postRaw({
  required Uri url,
  required String body,
  String contentType = 'application/xml',
}) async {
  final client = HttpClient();
  final req = await client.postUrl(url);
  req.headers.set('Content-Type', contentType);
  req.add(utf8.encode(body));
  final resp = await req.close();
  client.close(force: true);
  return resp;
}

void main() {
  group('WeCom listener flow', () {
    late WeComMessageListener listener;

    setUp(() async {
      listener = WeComMessageListener(
        config: const WeComConfig(
          corpId: 'ww_test',
          agentId: '1000002',
          secret: 'secret',
          callbackPort: 3903,
          callbackPath: '/wecom/callback',
        ),
      );
      await listener.start();
    });

    tearDown(() async {
      listener.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });

    test('GET verification should echo echostr', () async {
      final client = HttpClient();
      final req = await client.getUrl(
        Uri.parse('${listener.callbackUrl}?echostr=hello_wecom'),
      );
      final resp = await req.close();
      final body = await utf8.decoder.bind(resp).join();
      client.close(force: true);

      expect(resp.statusCode, 200);
      expect(body, 'hello_wecom');
    });

    test('XML text message should be parsed and emitted', () async {
      const xml = '''
<xml>
<ToUserName><![CDATA[ww_test]]></ToUserName>
<FromUserName><![CDATA[zhangsan]]></FromUserName>
<CreateTime>1710000000</CreateTime>
<MsgType><![CDATA[text]]></MsgType>
<Content><![CDATA[你好，来个报价]]></Content>
<MsgId>123456789</MsgId>
<AgentID>1000002</AgentID>
</xml>
''';

      final future = listener.messages
          .firstWhere((m) => m.msgId == '123456789')
          .timeout(const Duration(seconds: 3));

      final resp = await _postRaw(
        url: Uri.parse(listener.callbackUrl),
        body: xml,
      );
      final respBody = await utf8.decoder.bind(resp).join();
      expect(resp.statusCode, 200);
      expect(respBody, 'success');

      final msg = await future;
      expect(msg.isText, true);
      expect(msg.fromUserId, 'zhangsan');
      expect(msg.toUserId, 'ww_test');
      expect(msg.content, '你好，来个报价');
    });

    test('JSON text payload should be parsed and emitted', () async {
      final payload = {
        'msgType': 'text',
        'content': 'JSON回调消息',
        'fromUserId': 'lisi',
        'toUserId': 'ww_test',
        'agentId': '1000002',
        'msgId': 'json_1',
      };

      final future = listener.messages
          .firstWhere((m) => m.msgId == 'json_1')
          .timeout(const Duration(seconds: 3));

      final resp = await _postRaw(
        url: Uri.parse(listener.callbackUrl),
        body: jsonEncode(payload),
        contentType: 'application/json',
      );
      expect(resp.statusCode, 200);

      final msg = await future;
      expect(msg.isText, true);
      expect(msg.fromUserId, 'lisi');
      expect(msg.content, 'JSON回调消息');
    });
  });

  test('MessageBridge should auto-reply for wecom incoming text', () async {
    final app = await AppContext.testing();
    final captureAdapter = _CaptureWeComAdapter();
    final manager = ChannelManager(
      adapters: {ChannelType.wecom: captureAdapter},
      initialChannel: ChannelType.wecom,
    );

    final bridge = MessageBridge(
      conversationRepository: app.conversationRepository,
      messageRepository: app.messageRepository,
      negotiationRepository: app.negotiationRepository,
      autopilotService: _FakeAutopilotService(app),
      notificationService: NotificationService(),
      channelManager: manager,
    );

    await bridge.handleIncoming(
      IncomingRawMessage(
        channel: ChannelType.wecom,
        peerId: 'u_wecom_1',
        peerName: '企业客户A',
        text: '在吗，给个报价',
        receivedAt: DateTime.now(),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(captureAdapter.sent.length, 1);
    expect(captureAdapter.sent.first.peerId, 'u_wecom_1');
    expect(captureAdapter.sent.first.text, contains('报价'));

    final conversations = await app.conversationRepository.listConversations();
    expect(
      conversations.where((c) => c.customerId == 'u_wecom_1').isNotEmpty,
      true,
    );

    final conv = conversations.firstWhere((c) => c.customerId == 'u_wecom_1');
    final messages = await app.messageRepository.listMessages(conv.id);
    expect(messages.any((m) => m.role == 'customer'), true);
    expect(messages.any((m) => m.role == 'assistant'), true);
  });
}

class _CaptureWeComAdapter implements ChannelAdapter {
  final List<({String peerId, String text})> sent = [];

  @override
  ChannelType get channelType => ChannelType.wecom;

  @override
  String get displayName => 'Capture WeCom';

  @override
  Future<ChannelHealthStatus> healthCheck() async {
    return ChannelHealthStatus(
      channel: ChannelType.wecom,
      healthy: true,
      message: 'ok',
      checkedAt: DateTime.now(),
    );
  }

  @override
  Future<List<ChannelChatSummary>> listChats() async => const [];

  @override
  Future<bool> sendMessage({
    required String peerId,
    required String text,
  }) async {
    sent.add((peerId: peerId, text: text));
    return true;
  }
}

class _FakeAutopilotService extends AutopilotService {
  _FakeAutopilotService(AppContext app)
    : super(
        aiEngine: app.aiConversationEngine,
        sentimentAnalyzer: app.sentimentAnalyzer,
        sentimentRepository: app.sentimentRepository,
        negotiationEngine: app.negotiationEngine,
        escalationService: app.escalationService,
        intentClassifier: app.intentClassifier,
        cadencePolicy: app.responseCadencePolicy,
        qaService: app.qaService,
        pricingEngine: app.pricingEngine,
        messageRepository: app.messageRepository,
      );

  @override
  Future<AutopilotResult> processIncomingMessage({
    required Conversation conversation,
    required Message incomingMessage,
    required AutopilotMode mode,
    NegotiationContext? existingNegotiation,
  }) async {
    return AutopilotResult(
      reply: const ConversationReply(
        content: '可以的，这边给你一个基础报价方案。',
        confidence: 0.96,
        provider: 'test',
        model: 'fake',
        strategy: 'wecom-minimal',
        reasoning: null,
      ),
      sentiment: SentimentRecord(
        id: 'sent_1',
        conversationId: conversation.id,
        messageId: incomingMessage.id,
        sentiment: SentimentType.neutral,
        confidence: 0.7,
        buyingSignals: const [],
        hesitationSignals: const [],
        objectionPatterns: const [],
        emotionTags: const ['normal'],
        createdAt: DateTime.now(),
      ),
      negotiation: null,
      intentClassification: const IntentClassification(
        intent: ConversationIntent.businessPromotion,
        confidence: 0.9,
        reason: 'test',
      ),
      cadenceDecision: const CadenceDecision(
        action: CadenceAction.draftNow,
        reason: 'test',
        strategyWeight: 0.9,
        rhythmHint: 'test',
      ),
      escalationResult: const EscalationCheckResult(
        shouldEscalate: false,
        alerts: [],
      ),
      qaResult: const QaCheckResult(
        pass: true,
        blockReasons: [],
        warnReasons: [],
        normalizedText: '可以的，这边给你一个基础报价方案。',
      ),
      autoSend: mode == AutopilotMode.auto,
      holdReason: null,
    );
  }
}
