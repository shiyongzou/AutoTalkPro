import 'dart:async';

import '../../../core/models/conversation.dart';
import '../../../core/models/customer_profile.dart';
import '../../../core/models/message.dart';
import '../../autopilot/application/autopilot_service.dart';
import '../../conversation/domain/conversation_repository.dart';
import '../../message/domain/message_repository.dart';
import '../../negotiation/domain/negotiation_repository.dart';
import '../../notification/application/notification_service.dart';
import '../../qa/application/human_likeness_qa.dart';
import '../domain/channel_adapter.dart';
import 'channel_manager.dart';

/// 收到的原始消息（渠道无关）
class IncomingRawMessage {
  const IncomingRawMessage({
    required this.channel,
    required this.peerId,
    required this.peerName,
    required this.text,
    required this.receivedAt,
    this.customerId,
  });

  final ChannelType channel;
  final String peerId; // 发送回复用的目标（私聊=昵称，群=room:群名）
  final String peerName; // 显示名
  final String text;
  final DateTime receivedAt;
  final String? customerId; // 会话匹配用的ID（群里按人分：群名:发送者）

  /// 用于会话匹配的ID——有customerId就用，否则用peerId
  String get conversationKey => customerId ?? peerId;
}

/// 消息桥——连接所有渠道的收消息到会话系统+AI处理
class MessageBridge {
  MessageBridge({
    required this.conversationRepository,
    required this.messageRepository,
    required this.negotiationRepository,
    required this.autopilotService,
    required this.notificationService,
    required this.channelManager,
  });

  final ConversationRepository conversationRepository;
  final MessageRepository messageRepository;
  final NegotiationRepository negotiationRepository;
  final AutopilotService autopilotService;
  final NotificationService notificationService;

  // 消息处理队列——一次只处理一条，防止并发卡死
  final _queue = <IncomingRawMessage>[];
  bool _processing = false;
  final ChannelManager channelManager;
  final _humanQa = const HumanLikenessQa();

  final _processedController =
      StreamController<
        ({Conversation conversation, Message message, AutopilotResult? result})
      >.broadcast();

  /// 处理完成的消息流（UI可以订阅刷新）
  Stream<
    ({Conversation conversation, Message message, AutopilotResult? result})
  >
  get processed => _processedController.stream;

  /// 入口——加入队列排队处理
  Future<void> handleIncoming(IncomingRawMessage raw) async {
    if (raw.text.trim().isEmpty) return;
    _queue.add(raw);
    if (!_processing) _processQueue();
  }

  Future<void> _processQueue() async {
    _processing = true;
    while (_queue.isNotEmpty) {
      final raw = _queue.removeAt(0);
      try {
        await _handleOne(raw);
      } catch (_) {}
    }
    _processing = false;
  }

  /// 处理一条消息
  Future<void> _handleOne(IncomingRawMessage raw) async {
    // ignore: avoid_print
    print(
      '[MessageBridge] 处理消息: channel=${raw.channel} peerId=${raw.peerId} text=${raw.text.length > 30 ? raw.text.substring(0, 30) : raw.text}',
    );
    // 1. 找到或创建会话
    final conversation = await _getOrCreateConversation(raw);

    // 2. 存消息
    final message = Message(
      id: 'msg_in_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversation.id,
      role: 'customer',
      content: raw.text,
      sentAt: raw.receivedAt,
      riskFlag: false,
    );
    await messageRepository.addMessage(message);

    // 3. 更新会话时间
    await conversationRepository.upsertConversation(
      conversation.copyWith(
        lastMessageAt: raw.receivedAt,
        updatedAt: DateTime.now(),
      ),
    );

    // 4. 按会话设置的模式走——用户在UI上控制每个会话的自动回复开关
    final mode = _parseMode(conversation.autopilotMode);

    // ignore: avoid_print
    print(
      '[MessageBridge] 模式: autopilotMode=${conversation.autopilotMode} → mode=$mode',
    );

    // 5. 不管什么模式都生成AI回复（手动模式生成但不发）
    final negotiation = await negotiationRepository.getByConversation(
      conversation.id,
    );

    try {
      // ignore: avoid_print
      print('[MessageBridge] 调用AI引擎...');
      var result = await autopilotService.processIncomingMessage(
        conversation: conversation,
        incomingMessage: message,
        mode: mode,
        existingNegotiation: negotiation,
      );

      // ignore: avoid_print
      print(
        '[MessageBridge] AI回复: autoSend=${result.autoSend} qaPass=${result.qaResult?.pass} replyLen=${result.reply.content.length} provider=${result.reply.provider}',
      );

      final replyForSend = _withEmojiTone(result.reply.content, raw.channel);

      // 6. 空回复不处理（API失败时）
      if (replyForSend.trim().isEmpty) {
        // ignore: avoid_print
        print('[MessageBridge] 空回复，跳过。provider=${result.reply.provider}');
        _processedController.add((
          conversation: conversation,
          message: message,
          result: null,
        ));
        return;
      }

      // 7. AI味道检测——像不像AI说的
      final humanQaResult = _humanQa.evaluate(replyForSend);
      if (!humanQaResult.pass) {
        // AI味太重，通知人工审核
        notificationService.notifyAutopilotHold(
          conversationId: conversation.id,
          reason:
              'AI味检测不通过(${humanQaResult.score.toStringAsFixed(2)}分): ${humanQaResult.issues.join("、")}',
        );
        _processedController.add((
          conversation: conversation,
          message: message,
          result: result,
        ));
        return;
      }

      // 7. 如果可以自动发送，直接发
      if (result.autoSend && result.qaResult?.pass == true) {
        final adapter =
            channelManager.adapterOf(raw.channel) ??
            channelManager.activeAdapter;
        // 群消息回复加@发送者前缀，避免多人同时问时混淆
        final isGroupReply = raw.peerId.startsWith('room:');
        String finalReply = replyForSend;
        if (isGroupReply) {
          final colonIdx = raw.text.indexOf(':');
          if (colonIdx > 0) {
            final senderName = raw.text.substring(0, colonIdx).trim();
            finalReply = '@$senderName $replyForSend';
          }
        }
        // 长消息分段发送（微信单条有长度限制）
        final segments = _splitMessage(finalReply, 2000);
        // ignore: avoid_print
        print(
          '[MessageBridge] 发送回复: adapter=${adapter.runtimeType} peerId=${raw.peerId} segments=${segments.length} totalLen=${finalReply.length}',
        );
        var allSent = true;
        for (var i = 0; i < segments.length; i++) {
          if (i > 0) {
            // 分段之间间隔 1-2 秒，模拟真人打字
            await Future<void>.delayed(
              Duration(
                milliseconds:
                    1000 + (segments[i].length * 10).clamp(0, 1000),
              ),
            );
          }
          final sent = await adapter.sendMessage(
            peerId: raw.peerId,
            text: segments[i],
          );
          // ignore: avoid_print
          print('[MessageBridge] 发送段${i + 1}/${segments.length}: sent=$sent');
          if (!sent) allSent = false;
        }

        if (allSent) {
          final replyMsg = Message(
            id: 'msg_out_${DateTime.now().microsecondsSinceEpoch}',
            conversationId: conversation.id,
            role: 'assistant',
            content: finalReply,
            sentAt: DateTime.now(),
            riskFlag: false,
            metadata: {
              'autoSent': true,
              'confidence': result.reply.confidence,
              'humanScore': humanQaResult.score,
            },
          );
          await messageRepository.addMessage(replyMsg);
        }
      }

      // 7. 通知
      if (result.escalationResult.shouldEscalate) {
        for (final alert in result.escalationResult.alerts) {
          notificationService.notifyFromEscalation(alert);
        }
      }
      if (!result.autoSend && result.holdReason != null) {
        notificationService.notifyAutopilotHold(
          conversationId: conversation.id,
          reason: result.holdReason!,
        );
      }

      _processedController.add((
        conversation: conversation,
        message: message,
        result: result,
      ));
    } catch (e, st) {
      // ignore: avoid_print
      print('[MessageBridge] AI处理异常: $e\n$st');
      _processedController.add((
        conversation: conversation,
        message: message,
        result: null,
      ));
    }
  }

  /// 查找已有会话或创建新会话
  Future<Conversation> _getOrCreateConversation(IncomingRawMessage raw) async {
    final conversations = await conversationRepository.listConversations();
    // 按conversationKey匹配（群里按人分会话）
    final key = raw.conversationKey;
    final existing = conversations
        .where((c) => c.customerId == key)
        .firstOrNull;
    if (existing != null) return existing;

    // 创建新会话+新客户
    final now = DateTime.now();
    final conversation = Conversation(
      id: 'conv_${now.microsecondsSinceEpoch}',
      customerId: key,
      title: raw.peerName.isEmpty ? key : raw.peerName,
      status: 'active',
      goalStage: 'discover',
      lastMessageAt: now,
      createdAt: now,
      updatedAt: now,
      autopilotMode: 'manual',
    );
    await conversationRepository.upsertConversation(conversation);

    // 自动创建客户画像
    final customer = CustomerProfile(
      id: key,
      name: raw.peerName.isEmpty ? key : raw.peerName,
      segment: '中意向',
      tags: [raw.channel.name],
      lastContactAt: now,
      createdAt: now,
      updatedAt: now,
      preferredChannel: raw.channel.name,
    );
    await conversationRepository.upsertCustomer(customer);

    return conversation;
  }

  AutopilotMode _parseMode(String mode) {
    switch (mode) {
      case 'auto':
        return AutopilotMode.auto;
      case 'semiAuto':
        return AutopilotMode.semiAuto;
      default:
        return AutopilotMode.manual;
    }
  }

  /// 按自然段落分割长消息
  List<String> _splitMessage(String text, int maxLen) {
    if (text.length <= maxLen) return [text];

    final segments = <String>[];
    var remaining = text;

    while (remaining.length > maxLen) {
      // 优先在段落换行处分割
      var splitAt = remaining.lastIndexOf('\n\n', maxLen);
      // 其次在单换行处
      if (splitAt <= 0) splitAt = remaining.lastIndexOf('\n', maxLen);
      // 其次在句号处
      if (splitAt <= 0) splitAt = remaining.lastIndexOf('。', maxLen);
      // 其次在逗号处
      if (splitAt <= 0) splitAt = remaining.lastIndexOf('，', maxLen);
      // 兜底硬截
      if (splitAt <= 0) splitAt = maxLen;

      segments.add(remaining.substring(0, splitAt + 1).trim());
      remaining = remaining.substring(splitAt + 1).trim();
    }
    if (remaining.isNotEmpty) segments.add(remaining);

    return segments;
  }

  String _withEmojiTone(String text, ChannelType channel) {
    if (text.trim().isEmpty) return text;

    // 只在即时聊天渠道加轻量emoji，降低出错风险。
    final isChatChannel =
        channel == ChannelType.telegram ||
        channel == ChannelType.wechat ||
        channel == ChannelType.wecom;
    if (!isChatChannel) return text;

    // 已含emoji则不重复加。
    final emojiPattern = RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true);
    if (emojiPattern.hasMatch(text)) return text;

    // 过长消息不加，避免显得突兀。
    if (text.runes.length > 90) return text;

    const emojiPool = ['😊', '👌', '👍', '✨'];
    final idx = text.runes.fold<int>(
      0,
      (acc, r) => (acc + r) % emojiPool.length,
    );
    final emoji = emojiPool[idx];

    if (text.endsWith('。') || text.endsWith('！') || text.endsWith('!')) {
      return '$text $emoji';
    }
    return '$text。 $emoji';
  }

  void dispose() {
    _processedController.close();
  }
}
