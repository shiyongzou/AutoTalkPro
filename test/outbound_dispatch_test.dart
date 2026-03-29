import 'package:flutter_test/flutter_test.dart';

import 'package:tg_ai_sales_desktop/core/models/audit_log.dart';
import 'package:tg_ai_sales_desktop/core/models/conversation.dart';
import 'package:tg_ai_sales_desktop/core/models/customer_profile.dart';
import 'package:tg_ai_sales_desktop/core/models/message.dart';
import 'package:tg_ai_sales_desktop/features/audit/domain/audit_repository.dart';
import 'package:tg_ai_sales_desktop/features/channel/application/channel_manager.dart';
import 'package:tg_ai_sales_desktop/features/channel/domain/channel_adapter.dart';
import 'package:tg_ai_sales_desktop/features/conversation/domain/conversation_repository.dart';
import 'package:tg_ai_sales_desktop/features/message/domain/message_repository.dart';
import 'package:tg_ai_sales_desktop/features/outbound/application/outbound_dispatch_service.dart';
import 'package:tg_ai_sales_desktop/features/outbound/domain/dispatch_guard_repository.dart';
import 'package:tg_ai_sales_desktop/features/qa/application/message_qa_service.dart';
import 'package:tg_ai_sales_desktop/features/telegram/data/official_telegram_adapter.dart';
import 'package:tg_ai_sales_desktop/features/telegram/domain/telegram_config.dart';

void main() {
  test('QA blocks forbidden promise', () {
    const qa = MessageQaService();
    final result = qa.evaluate(
      text: '我保证收益，100%成交',
      conversationId: 'c1',
      peerId: 'p1',
    );

    expect(result.pass, isFalse);
    expect(result.blockReasons.join(','), contains('命中禁止词'));
  });

  test('dispatch blocks when conversation-peer mismatch', () async {
    final service = OutboundDispatchService(
      qaService: const MessageQaService(),
      channelManager: _buildChannelManager(const _FakeChannelAdapter()),
      messageRepository: _FakeMessageRepository(),
      auditRepository: _FakeAuditRepository(),
      conversationRepository: _FakeConversationRepository(
        Conversation(
          id: 'conv_1',
          customerId: 'peer_A',
          title: 'x',
          status: 'active',
          goalStage: 'discover',
          lastMessageAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
      dispatchGuardRepository: _FakeDispatchGuardRepository(),
      maxAttempts: 1,
    );

    final result = await service.sendWithQa(
      requestId: 'r1',
      conversationId: 'conv_1',
      peerId: 'peer_B',
      content: '你好',
      metadata: const {},
    );

    expect(result.blocked, isTrue);
    expect(result.reason, contains('会话与目标客户不一致'));
  });

  test('dispatch deduplicates same request id', () async {
    final fakeMessageRepo = _FakeMessageRepository();
    final service = OutboundDispatchService(
      qaService: const MessageQaService(),
      channelManager: _buildChannelManager(const _FakeChannelAdapter()),
      messageRepository: fakeMessageRepo,
      auditRepository: _FakeAuditRepository(),
      conversationRepository: _FakeConversationRepository(
        Conversation(
          id: 'conv_2',
          customerId: 'peer_2',
          title: 'x',
          status: 'active',
          goalStage: 'discover',
          lastMessageAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
      dispatchGuardRepository: _FakeDispatchGuardRepository(),
      maxAttempts: 1,
    );

    final first = await service.sendWithQa(
      requestId: 'same_req',
      conversationId: 'conv_2',
      peerId: 'peer_2',
      content: '第一条',
      metadata: const {},
    );
    final second = await service.sendWithQa(
      requestId: 'same_req',
      conversationId: 'conv_2',
      peerId: 'peer_2',
      content: '第二条',
      metadata: const {},
    );

    expect(first.sent, isTrue);
    expect(second.blocked, isTrue);
    expect(fakeMessageRepo.messages.length, 1);
  });

  test(
    'dispatch blocks when official telegram channel is not logged in',
    () async {
      final fakeMessageRepo = _FakeMessageRepository();
      final officialAdapter = OfficialTelegramAdapter(
        config: const TelegramConfig(
          useOfficial: true,
          apiId: '10001',
          apiHash: 'hash',
          phoneNumber: '+85512345678',
        ),
      );
      final service = OutboundDispatchService(
        qaService: const MessageQaService(),
        channelManager: _buildChannelManager(officialAdapter),
        messageRepository: fakeMessageRepo,
        auditRepository: _FakeAuditRepository(),
        conversationRepository: _FakeConversationRepository(
          Conversation(
            id: 'conv_4',
            customerId: 'peer_4',
            title: 'x',
            status: 'active',
            goalStage: 'discover',
            lastMessageAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        dispatchGuardRepository: _FakeDispatchGuardRepository(),
        maxAttempts: 1,
      );

      final result = await service.sendWithQa(
        requestId: 'official_not_login',
        conversationId: 'conv_4',
        peerId: 'peer_4',
        content: '请发我报价',
        metadata: const {},
      );

      expect(result.sent, isFalse);
      expect(result.blocked, isTrue);
      expect(result.reason, contains('未登录'));
      expect(fakeMessageRepo.messages, isEmpty);
    },
  );

  test(
    'dispatch blocks when official telegram is pending verification code',
    () async {
      final fakeMessageRepo = _FakeMessageRepository();
      final officialAdapter = OfficialTelegramAdapter(
        config: const TelegramConfig(
          useOfficial: true,
          apiId: '10001',
          apiHash: 'hash',
          phoneNumber: '+85512345678',
        ),
      );
      await officialAdapter.requestLoginCode();

      final service = OutboundDispatchService(
        qaService: const MessageQaService(),
        channelManager: _buildChannelManager(officialAdapter),
        messageRepository: fakeMessageRepo,
        auditRepository: _FakeAuditRepository(),
        conversationRepository: _FakeConversationRepository(
          Conversation(
            id: 'conv_5',
            customerId: 'peer_5',
            title: 'x',
            status: 'active',
            goalStage: 'discover',
            lastMessageAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        dispatchGuardRepository: _FakeDispatchGuardRepository(),
        maxAttempts: 1,
      );

      final result = await service.sendWithQa(
        requestId: 'official_waiting_code',
        conversationId: 'conv_5',
        peerId: 'peer_5',
        content: '请发我报价',
        metadata: const {},
      );

      expect(result.sent, isFalse);
      expect(result.blocked, isTrue);
      expect(result.reason, contains('待验证码'));
      expect(fakeMessageRepo.messages, isEmpty);
    },
  );

  test('dispatch retries and succeeds', () async {
    final fakeMessageRepo = _FakeMessageRepository();
    final flaky = _FlakyChannelAdapter(failuresBeforeSuccess: 2);

    final service = OutboundDispatchService(
      qaService: const MessageQaService(),
      channelManager: _buildChannelManager(flaky),
      messageRepository: fakeMessageRepo,
      auditRepository: _FakeAuditRepository(),
      conversationRepository: _FakeConversationRepository(
        Conversation(
          id: 'conv_3',
          customerId: 'peer_3',
          title: 'x',
          status: 'active',
          goalStage: 'discover',
          lastMessageAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
      dispatchGuardRepository: _FakeDispatchGuardRepository(),
      maxAttempts: 3,
      initialBackoff: const Duration(milliseconds: 1),
    );

    final result = await service.sendWithQa(
      requestId: 'retry_req',
      conversationId: 'conv_3',
      peerId: 'peer_3',
      content: '请发我报价',
      metadata: const {},
    );

    expect(result.sent, isTrue);
    expect(flaky.attempts, 3);
    expect(fakeMessageRepo.messages.length, 1);
    expect(
      fakeMessageRepo.messages.single.metadata?['dispatchAttempts'],
      equals(3),
    );
  });

  test(
    'dispatch recovers from adapter exception and eventually succeeds',
    () async {
      final fakeMessageRepo = _FakeMessageRepository();
      final adapter = _ExceptionThenSuccessAdapter();
      final auditRepo = _FakeAuditRepository();

      final service = OutboundDispatchService(
        qaService: const MessageQaService(),
        channelManager: _buildChannelManager(adapter),
        messageRepository: fakeMessageRepo,
        auditRepository: auditRepo,
        conversationRepository: _FakeConversationRepository(
          Conversation(
            id: 'conv_6',
            customerId: 'peer_6',
            title: 'x',
            status: 'active',
            goalStage: 'discover',
            lastMessageAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        dispatchGuardRepository: _FakeDispatchGuardRepository(),
        maxAttempts: 3,
        initialBackoff: const Duration(milliseconds: 1),
      );

      final result = await service.sendWithQa(
        requestId: 'exception_retry',
        conversationId: 'conv_6',
        peerId: 'peer_6',
        content: '请发我报价',
        metadata: const {},
      );

      expect(result.sent, isTrue);
      expect(fakeMessageRepo.messages.length, 1);
      final attemptLogs = auditRepo.logs.where(
        (e) => e.stage == 'send_attempt',
      );
      expect(attemptLogs.length, 2);
      expect(
        attemptLogs.first.detail['exception'] as String,
        contains('simulated send crash'),
      );
    },
  );

  test('audit logs include enriched trace fields', () async {
    final auditRepo = _FakeAuditRepository();
    final service = OutboundDispatchService(
      qaService: const MessageQaService(),
      channelManager: _buildChannelManager(const _FakeChannelAdapter()),
      messageRepository: _FakeMessageRepository(),
      auditRepository: auditRepo,
      conversationRepository: _FakeConversationRepository(
        Conversation(
          id: 'conv_audit_1',
          customerId: 'peer_audit_1',
          title: 'x',
          status: 'active',
          goalStage: 'discover',
          lastMessageAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
      dispatchGuardRepository: _FakeDispatchGuardRepository(),
      maxAttempts: 1,
    );

    final result = await service.sendWithQa(
      requestId: 'audit_req_1',
      conversationId: 'conv_audit_1',
      peerId: 'peer_audit_1',
      content: '请发我报价',
      metadata: const {
        'operator': 'alice',
        'templateVersion': 'v2026.03',
        'model': 'gpt-4.1-mini',
      },
    );

    expect(result.sent, isTrue);

    final logs = await auditRepo.listByRequestId('audit_req_1');
    expect(logs, isNotEmpty);
    expect(logs.every((e) => e.requestId == 'audit_req_1'), isTrue);
    expect(logs.any((e) => e.operator == 'alice'), isTrue);
    expect(logs.any((e) => e.channel == 'telegram'), isTrue);
    expect(logs.any((e) => e.templateVersion == 'v2026.03'), isTrue);
    expect(logs.any((e) => e.model == 'gpt-4.1-mini'), isTrue);
    expect(logs.any((e) => (e.latencyMs ?? 0) >= 0), isTrue);
  });

  test('dispatch invokes stuck-sending recovery before reserve', () async {
    final guardRepo = _FakeDispatchGuardRepository();
    final service = OutboundDispatchService(
      qaService: const MessageQaService(),
      channelManager: _buildChannelManager(const _FakeChannelAdapter()),
      messageRepository: _FakeMessageRepository(),
      auditRepository: _FakeAuditRepository(),
      conversationRepository: _FakeConversationRepository(
        Conversation(
          id: 'conv_7',
          customerId: 'peer_7',
          title: 'x',
          status: 'active',
          goalStage: 'discover',
          lastMessageAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
      dispatchGuardRepository: guardRepo,
      maxAttempts: 1,
    );

    await service.sendWithQa(
      requestId: 'recover_call',
      conversationId: 'conv_7',
      peerId: 'peer_7',
      content: '你好',
      metadata: const {},
    );

    expect(guardRepo.recoverCalled, isTrue);
  });
}

ChannelManager _buildChannelManager(ChannelAdapter adapter) {
  return ChannelManager(
    adapters: {ChannelType.telegram: adapter},
    initialChannel: ChannelType.telegram,
  );
}

class _FakeChannelAdapter implements ChannelAdapter {
  const _FakeChannelAdapter();

  @override
  ChannelType get channelType => ChannelType.telegram;

  @override
  String get displayName => 'fake';

  @override
  Future<ChannelHealthStatus> healthCheck() async {
    return ChannelHealthStatus(
      channel: channelType,
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
  }) async => true;
}

class _FlakyChannelAdapter implements ChannelAdapter {
  _FlakyChannelAdapter({required this.failuresBeforeSuccess});

  final int failuresBeforeSuccess;
  int attempts = 0;

  @override
  ChannelType get channelType => ChannelType.telegram;

  @override
  String get displayName => 'flaky';

  @override
  Future<ChannelHealthStatus> healthCheck() async {
    return ChannelHealthStatus(
      channel: channelType,
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
    attempts += 1;
    return attempts > failuresBeforeSuccess;
  }
}

class _ExceptionThenSuccessAdapter implements ChannelAdapter {
  int attempts = 0;

  @override
  ChannelType get channelType => ChannelType.telegram;

  @override
  String get displayName => 'exception-then-success';

  @override
  Future<ChannelHealthStatus> healthCheck() async {
    return ChannelHealthStatus(
      channel: channelType,
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
    attempts += 1;
    if (attempts == 1) {
      throw StateError('simulated send crash');
    }
    return true;
  }
}

class _FakeMessageRepository implements MessageRepository {
  final List<Message> messages = [];

  @override
  Future<void> addMessage(Message message) async {
    messages.add(message);
  }

  @override
  Future<List<Message>> listMessages(String conversationId) async {
    return messages.where((m) => m.conversationId == conversationId).toList();
  }
}

class _FakeAuditRepository implements AuditRepository {
  final List<AuditLog> logs = [];

  @override
  Future<void> add(AuditLog log) async {
    logs.add(log);
  }

  @override
  Future<List<AuditLog>> listByConversation(String conversationId) async {
    return logs.where((l) => l.conversationId == conversationId).toList();
  }

  @override
  Future<List<AuditLog>> listByRequestId(String requestId) async {
    return logs.where((l) => l.requestId == requestId).toList();
  }

  @override
  Future<List<AuditLog>> query(AuditQuery query) async {
    var filtered = [...logs];
    if (query.conversationId != null) {
      filtered = filtered
          .where((l) => l.conversationId == query.conversationId)
          .toList();
    }
    if (query.requestId != null) {
      filtered = filtered.where((l) => l.requestId == query.requestId).toList();
    }
    if (query.channel != null) {
      filtered = filtered.where((l) => l.channel == query.channel).toList();
    }
    if (query.stage != null) {
      filtered = filtered.where((l) => l.stage == query.stage).toList();
    }
    if (query.status != null) {
      filtered = filtered.where((l) => l.status == query.status).toList();
    }
    return filtered.take(query.limit).toList();
  }
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository(this.conversation);

  final Conversation conversation;

  @override
  Future<Conversation?> getConversationById(String conversationId) async {
    return conversation.id == conversationId ? conversation : null;
  }

  @override
  Future<List<Conversation>> listConversations() async => [conversation];

  @override
  Future<void> upsertConversation(Conversation conversation) async {}

  @override
  Future<List<CustomerProfile>> listCustomers() async => const [];

  @override
  Future<void> upsertCustomer(CustomerProfile profile) async {}
}

class _FakeDispatchGuardRepository implements DispatchGuardRepository {
  final Map<String, String> _state = {};
  bool recoverCalled = false;

  @override
  Future<String?> getStatus(String requestId) async => _state[requestId];

  @override
  Future<void> markStatus({
    required String requestId,
    required String status,
  }) async {
    if (_state.containsKey(requestId)) {
      _state[requestId] = status;
    }
  }

  @override
  Future<bool> tryReserve({
    required String requestId,
    required String conversationId,
  }) async {
    if (_state.containsKey(requestId)) return false;
    _state[requestId] = 'reserved';
    return true;
  }

  @override
  Future<int> recoverStuckSending({required Duration olderThan}) async {
    recoverCalled = true;
    var n = 0;
    _state.updateAll((key, value) {
      if (value == 'sending') {
        n += 1;
        return 'failed';
      }
      return value;
    });
    return n;
  }
}
