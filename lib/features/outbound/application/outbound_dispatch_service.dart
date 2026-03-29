import '../../../core/models/audit_log.dart';
import '../../../core/models/message.dart';
import '../../audit/domain/audit_repository.dart';
import '../../channel/application/channel_manager.dart';
import '../../channel/domain/channel_send_guard.dart';
import '../../conversation/domain/conversation_repository.dart';
import '../../message/domain/message_repository.dart';
import '../../qa/application/message_qa_service.dart';
import '../domain/dispatch_guard_repository.dart';

class DispatchResult {
  const DispatchResult({
    required this.sent,
    required this.blocked,
    required this.reason,
    required this.warnReasons,
  });

  final bool sent;
  final bool blocked;
  final String reason;
  final List<String> warnReasons;
}

class OutboundDispatchService {
  const OutboundDispatchService({
    required this.qaService,
    required this.channelManager,
    required this.messageRepository,
    required this.auditRepository,
    required this.conversationRepository,
    required this.dispatchGuardRepository,
    this.maxAttempts = 3,
    this.initialBackoff = const Duration(milliseconds: 250),
    this.recoverStuckOlderThan = const Duration(minutes: 5),
  });

  final MessageQaService qaService;
  final ChannelManager channelManager;
  final MessageRepository messageRepository;
  final AuditRepository auditRepository;
  final ConversationRepository conversationRepository;
  final DispatchGuardRepository dispatchGuardRepository;
  final int maxAttempts;
  final Duration initialBackoff;
  final Duration recoverStuckOlderThan;

  Future<DispatchResult> sendWithQa({
    required String requestId,
    required String conversationId,
    required String peerId,
    required String content,
    required Map<String, dynamic> metadata,
  }) async {
    final startedAt = DateTime.now();
    final operator = metadata['operator']?.toString();
    final templateVersion = metadata['templateVersion']?.toString();
    final model = metadata['model']?.toString();
    final recovered = await dispatchGuardRepository.recoverStuckSending(
      olderThan: recoverStuckOlderThan,
    );

    await _audit(
      conversationId: conversationId,
      stage: 'idempotency_reserve',
      status: 'check',
      detail: {
        ..._baseDetail(
          requestId: requestId,
          conversationId: conversationId,
          peerId: peerId,
          startedAt: startedAt,
          operatorName: operator,
          templateVersion: templateVersion,
          model: model,
        ),
        'recoveredStuckSending': recovered,
      },
    );

    final reserved = await dispatchGuardRepository.tryReserve(
      requestId: requestId,
      conversationId: conversationId,
    );

    if (!reserved) {
      final status = await dispatchGuardRepository.getStatus(requestId);
      await _audit(
        conversationId: conversationId,
        stage: 'idempotency_reserve',
        status: 'blocked',
        detail: {
          ..._baseDetail(
            requestId: requestId,
            conversationId: conversationId,
            peerId: peerId,
            startedAt: startedAt,
            operatorName: operator,
            templateVersion: templateVersion,
            model: model,
          ),
          'dispatchStatus': status,
          'reason': 'duplicate_request',
        },
      );
      return DispatchResult(
        sent: status == 'sent',
        blocked: true,
        reason: '重复请求已拦截(requestId=$requestId)',
        warnReasons: const [],
      );
    }

    final conversation = await conversationRepository.getConversationById(
      conversationId,
    );
    if (conversation == null) {
      await dispatchGuardRepository.markStatus(
        requestId: requestId,
        status: 'blocked',
      );
      await _audit(
        conversationId: conversationId,
        stage: 'binding',
        status: 'blocked',
        detail: {
          ..._baseDetail(
            requestId: requestId,
            conversationId: conversationId,
            peerId: peerId,
            startedAt: startedAt,
            operatorName: operator,
            templateVersion: templateVersion,
            model: model,
          ),
          'reason': 'conversation_not_found',
        },
      );
      return const DispatchResult(
        sent: false,
        blocked: true,
        reason: '会话不存在，禁止发送',
        warnReasons: [],
      );
    }

    if (conversation.customerId != peerId) {
      await dispatchGuardRepository.markStatus(
        requestId: requestId,
        status: 'blocked',
      );
      await _audit(
        conversationId: conversationId,
        stage: 'binding',
        status: 'blocked',
        detail: {
          ..._baseDetail(
            requestId: requestId,
            conversationId: conversationId,
            peerId: peerId,
            startedAt: startedAt,
            operatorName: operator,
            templateVersion: templateVersion,
            model: model,
          ),
          'reason': 'peer_mismatch',
          'expectedPeerId': conversation.customerId,
          'actualPeerId': peerId,
        },
      );
      return const DispatchResult(
        sent: false,
        blocked: true,
        reason: '会话与目标客户不一致，已阻断',
        warnReasons: [],
      );
    }

    final qa = qaService.evaluate(
      text: content,
      conversationId: conversationId,
      peerId: peerId,
    );

    await _audit(
      conversationId: conversationId,
      stage: 'qa',
      status: qa.pass ? 'pass' : 'blocked',
      detail: {
        ..._baseDetail(
          requestId: requestId,
          conversationId: conversationId,
          peerId: peerId,
          startedAt: startedAt,
          operatorName: operator,
          templateVersion: templateVersion,
          model: model,
        ),
        'blockReasons': qa.blockReasons,
        'warnReasons': qa.warnReasons,
      },
    );

    if (!qa.pass) {
      await dispatchGuardRepository.markStatus(
        requestId: requestId,
        status: 'blocked',
      );
      return DispatchResult(
        sent: false,
        blocked: true,
        reason: qa.blockReasons.join('；'),
        warnReasons: qa.warnReasons,
      );
    }

    await dispatchGuardRepository.markStatus(
      requestId: requestId,
      status: 'sending',
    );

    final activeAdapter = channelManager.activeAdapter;
    if (activeAdapter is ChannelSendGuard) {
      final guardAdapter = activeAdapter as ChannelSendGuard;
      final guard = await guardAdapter.checkBeforeSend(
        peerId: peerId,
        text: content,
      );
      await _audit(
        conversationId: conversationId,
        stage: 'channel_precheck',
        status: guard.allowed ? 'pass' : 'blocked',
        detail: {
          ..._baseDetail(
            requestId: requestId,
            conversationId: conversationId,
            peerId: peerId,
            startedAt: startedAt,
            operatorName: operator,
            templateVersion: templateVersion,
            model: model,
          ),
          'channel': activeAdapter.channelType.name,
          'reason': guard.reason,
          'details': guard.details,
        },
      );
      if (!guard.allowed) {
        await dispatchGuardRepository.markStatus(
          requestId: requestId,
          status: 'blocked',
        );
        return DispatchResult(
          sent: false,
          blocked: true,
          reason: guard.reason ?? '通道未就绪，禁止发送',
          warnReasons: qa.warnReasons,
        );
      }
    }

    var ok = false;
    var attempt = 0;
    var backoff = initialBackoff;
    String? lastException;

    while (attempt < maxAttempts) {
      attempt += 1;
      try {
        ok = await activeAdapter.sendMessage(peerId: peerId, text: content);
      } catch (e) {
        ok = false;
        lastException = e.toString();
      }

      final attemptDetail = <String, dynamic>{
        ..._baseDetail(
          requestId: requestId,
          conversationId: conversationId,
          peerId: peerId,
          startedAt: startedAt,
          operatorName: operator,
          templateVersion: templateVersion,
          model: model,
        ),
        'channel': activeAdapter.channelType.name,
        'attempt': attempt,
        'maxAttempts': maxAttempts,
        'exception': lastException,
      };
      attemptDetail.removeWhere((_, value) => value == null);

      await _audit(
        conversationId: conversationId,
        stage: 'send_attempt',
        status: ok ? 'success' : 'failed',
        detail: attemptDetail,
      );

      if (ok) break;
      if (attempt < maxAttempts) {
        await Future<void>.delayed(backoff);
        backoff *= 2;
      }
    }

    final finishedAt = DateTime.now();
    final dispatchDurationMs = finishedAt.difference(startedAt).inMilliseconds;

    if (!ok) {
      await dispatchGuardRepository.markStatus(
        requestId: requestId,
        status: 'failed',
      );
      final failedDetail = <String, dynamic>{
        ..._baseDetail(
          requestId: requestId,
          conversationId: conversationId,
          peerId: peerId,
          startedAt: startedAt,
          operatorName: operator,
          templateVersion: templateVersion,
          model: model,
          finishedAt: finishedAt,
        ),
        'channel': activeAdapter.channelType.name,
        'attempts': attempt,
        'maxAttempts': maxAttempts,
        'durationMs': dispatchDurationMs,
        'lastException': lastException,
      };
      failedDetail.removeWhere((_, value) => value == null);

      await _audit(
        conversationId: conversationId,
        stage: 'send',
        status: 'failed',
        detail: failedDetail,
      );
      return DispatchResult(
        sent: false,
        blocked: false,
        reason: '发送失败(重试$attempt次)',
        warnReasons: qa.warnReasons,
      );
    }

    final message = Message(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      role: 'assistant',
      content: content,
      sentAt: DateTime.now(),
      riskFlag: qa.warnReasons.isNotEmpty,
      metadata: {
        ...metadata,
        'requestId': requestId,
        'channel': activeAdapter.channelType.name,
        'qaWarnReasons': qa.warnReasons,
        'dispatchAttempts': attempt,
        'dispatchDurationMs': dispatchDurationMs,
        'dispatchStartedAt': startedAt.toIso8601String(),
        'dispatchFinishedAt': finishedAt.toIso8601String(),
      },
    );
    await messageRepository.addMessage(message);
    await dispatchGuardRepository.markStatus(
      requestId: requestId,
      status: 'sent',
    );

    await _audit(
      conversationId: conversationId,
      stage: 'send',
      status: 'success',
      detail: {
        ..._baseDetail(
          requestId: requestId,
          conversationId: conversationId,
          peerId: peerId,
          startedAt: startedAt,
          operatorName: operator,
          templateVersion: templateVersion,
          model: model,
          finishedAt: finishedAt,
        ),
        'channel': activeAdapter.channelType.name,
        'attempts': attempt,
        'durationMs': dispatchDurationMs,
      },
    );

    return DispatchResult(
      sent: true,
      blocked: false,
      reason: '发送成功',
      warnReasons: qa.warnReasons,
    );
  }

  Map<String, dynamic> _baseDetail({
    required String requestId,
    required String conversationId,
    required String peerId,
    required DateTime startedAt,
    String? operatorName,
    String? templateVersion,
    String? model,
    DateTime? finishedAt,
  }) {
    final detail = <String, dynamic>{
      'requestId': requestId,
      'conversationId': conversationId,
      'peerId': peerId,
      'operator': operatorName,
      'templateVersion': templateVersion,
      'model': model,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
    };
    detail.removeWhere((_, value) => value == null);
    return detail;
  }

  Future<void> _audit({
    required String conversationId,
    required String stage,
    required String status,
    required Map<String, dynamic> detail,
  }) async {
    int? latencyMs =
        (detail['latencyMs'] as int?) ??
        (detail['durationMs'] as int?) ??
        (detail['dispatchDurationMs'] as int?);
    if (latencyMs == null && detail['startedAt'] is String) {
      final parsedStartedAt = DateTime.tryParse(detail['startedAt'] as String);
      if (parsedStartedAt != null) {
        latencyMs = DateTime.now().difference(parsedStartedAt).inMilliseconds;
      }
    }

    await auditRepository.add(
      AuditLog(
        id: 'audit_${DateTime.now().microsecondsSinceEpoch}_$stage',
        conversationId: conversationId,
        stage: stage,
        status: status,
        requestId: detail['requestId']?.toString(),
        operator: detail['operator']?.toString(),
        channel: detail['channel']?.toString(),
        templateVersion: detail['templateVersion']?.toString(),
        model: detail['model']?.toString(),
        latencyMs: latencyMs,
        detail: detail,
        createdAt: DateTime.now(),
      ),
    );
  }
}
