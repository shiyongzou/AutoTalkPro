import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_context.dart';
import '../app_theme.dart';
import '../app_widgets.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/message.dart';
import '../../../core/models/negotiation_context.dart';
import '../../../features/ai/domain/ai_provider.dart';
import '../../../features/autopilot/application/autopilot_service.dart';

class ConversationCenterPage extends StatefulWidget {
  const ConversationCenterPage({required this.appContext, super.key});

  final AppContext appContext;

  @override
  State<ConversationCenterPage> createState() => _ConversationCenterPageState();
}

class _ConversationCenterPageState extends State<ConversationCenterPage> {
  List<Conversation> conversations = const [];
  Conversation? selectedConversation;
  List<Message> currentMessages = const [];
  NegotiationContext? currentNegotiation;
  AutopilotResult? lastAutopilotResult;
  AutopilotMode autopilotMode = AutopilotMode.semiAuto;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isProcessing = false;
  StreamSubscription? _bridgeSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPlatformKeys();
    // 监听新消息自动刷新（防抖：500ms内多次触发只执行一次）
    Timer? debounce;
    _bridgeSubscription = widget.appContext.messageBridge.processed.listen((
      event,
    ) {
      if (!mounted) return;
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _load();
        if (selectedConversation != null &&
            event.conversation.id == selectedConversation!.id) {
          _refreshCurrentChat();
          // 手动模式：AI回复塞到输入框
          if (event.result != null &&
              !event.result!.autoSend &&
              event.result!.reply.content.isNotEmpty) {
            _inputController.text = event.result!.reply.content;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _bridgeSubscription?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _clearCurrentChat() async {
    if (selectedConversation == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: Text('确定要清空「${selectedConversation!.title}」的所有消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await widget.appContext.database.customStatement(
      'DELETE FROM messages WHERE conversation_id = ?',
      [selectedConversation!.id],
    );
    setState(() => currentMessages = const []);
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空所有会话'),
        content: const Text('确定要删除所有会话和消息记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // 删除数据库里所有会话和消息
    final db = widget.appContext.database;
    await db.customStatement('DELETE FROM messages');
    await db.customStatement('DELETE FROM conversations');
    setState(() {
      conversations = const [];
      selectedConversation = null;
      currentMessages = const [];
    });
  }

  Future<void> _toggleAutoReply(Conversation c) async {
    final newMode = c.autopilotMode == 'manual' ? 'auto' : 'manual';
    final updated = c.copyWith(
      autopilotMode: newMode,
      updatedAt: DateTime.now(),
    );
    await widget.appContext.conversationRepository.upsertConversation(updated);
    await _load();
    if (selectedConversation?.id == c.id) {
      setState(() => selectedConversation = updated);
    }
  }

  Future<void> _refreshCurrentChat() async {
    if (selectedConversation == null) return;
    final targetId = selectedConversation!.id;
    final messages = await widget.appContext.messageRepository.listMessages(
      targetId,
    );
    if (!mounted || selectedConversation?.id != targetId) return;
    setState(() => currentMessages = messages);
    _scrollToBottom();
  }

  Future<void> _load() async {
    final rows = await widget.appContext.conversationRepository
        .listConversations();
    if (!mounted) return;
    setState(() => conversations = rows);
  }

  Future<void> _persistAutopilotMode(AutopilotMode mode) async {
    if (selectedConversation == null) return;
    final modeStr = mode == AutopilotMode.auto
        ? 'auto'
        : mode == AutopilotMode.semiAuto
        ? 'semiAuto'
        : 'manual';
    final updated = selectedConversation!.copyWith(
      autopilotMode: modeStr,
      updatedAt: DateTime.now(),
    );
    await widget.appContext.conversationRepository.upsertConversation(updated);
    if (mounted) setState(() => selectedConversation = updated);
  }

  /// 当前模型名
  String _currentModelName() {
    return widget.appContext.aiConversationEngine.settings.model;
  }

  /// 各平台key状态缓存
  Map<String, bool> _platformKeyStatus = {};

  /// 加载所有平台的key状态
  Future<void> _loadPlatformKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final status = <String, bool>{};
    for (final p in AiProviderSettings.platforms) {
      final key = prefs.getString('ai.apiKey.${p.id}') ?? '';
      status[p.id] = key.isNotEmpty || p.id == 'ollama';
    }
    if (mounted) setState(() => _platformKeyStatus = status);
  }

  bool _platformHasKey(String platformId) {
    return _platformKeyStatus[platformId] ?? false;
  }

  /// 切换到指定平台的指定模型
  Future<void> _switchToModel(String platformId, String model) async {
    final platform = AiProviderSettings.platforms.firstWhere(
      (p) => p.id == platformId,
    );
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('ai.apiKey.$platformId');

    final settings = AiProviderSettings(
      provider: AiProviderType.openaiCompatible,
      model: model,
      apiBase: platform.apiBase,
      apiKey: apiKey,
      temperature: widget.appContext.aiConversationEngine.settings.temperature,
    );

    widget.appContext.aiConversationEngine.updateSettings(settings);
    widget.appContext.aiDraftService.updateSettings(settings);
    setState(() {});
  }

  /// 防串号版本号，每次切换会话递增，异步回调时校验
  int _selectVersion = 0;

  Future<void> _selectConversation(Conversation c) async {
    final version = ++_selectVersion; // 捕获当前版本
    final targetId = c.id;

    // 立即切换选中态，清空旧数据，避免闪烁旧消息
    setState(() {
      selectedConversation = c;
      currentMessages = const [];
      currentNegotiation = null;
      lastAutopilotResult = null;
    });

    final messages = await widget.appContext.messageRepository.listMessages(
      targetId,
    );
    final neg = await widget.appContext.negotiationRepository.getByConversation(
      targetId,
    );

    if (!mounted) return;
    // 关键：如果用户已经切到别的会话，丢弃这次结果
    if (_selectVersion != version) return;

    final loadedMode = c.autopilotMode == 'auto'
        ? AutopilotMode.auto
        : c.autopilotMode == 'semiAuto'
        ? AutopilotMode.semiAuto
        : AutopilotMode.manual;
    setState(() {
      selectedConversation = c;
      currentMessages = messages;
      currentNegotiation = neg;
      lastAutopilotResult = null;
      autopilotMode = loadedMode;
    });
    _scrollToBottom();
  }

  Future<void> _sendReply(String content) async {
    if (selectedConversation == null || content.trim().isEmpty) return;
    final targetId = selectedConversation!.id;
    final customerId = selectedConversation!.customerId;

    // Actually send to the channel (WeChat/Telegram/WeCom)
    final channelManager = widget.appContext.channelManager;
    final adapter = channelManager.activeAdapter;
    final sent = await adapter.sendMessage(
      peerId: customerId,
      text: content.trim(),
    );

    final msg = Message(
      id: 'msg_ai_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: targetId,
      role: 'assistant',
      content: content.trim(),
      sentAt: DateTime.now(),
      riskFlag: false,
      metadata: {'manualSent': true, 'delivered': sent},
    );
    await widget.appContext.messageRepository.addMessage(msg);

    final messages = await widget.appContext.messageRepository.listMessages(
      targetId,
    );
    if (!mounted) return;
    // 只在仍选中同一会话时更新UI
    if (selectedConversation?.id != targetId) return;
    setState(() {
      currentMessages = messages;
      _inputController.clear();
    });
    _scrollToBottom();

    if (!sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('消息发送失败，已保存到本地'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    return Row(
      children: [
        // 左侧: 会话列表
        SizedBox(
          width: 280,
          child: AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(tokens.spaceMd),
                  child: Row(
                    children: [
                      Text(
                        '会话列表',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep, size: 20),
                        tooltip: '清空所有会话',
                        onPressed: _clearAll,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: '刷新',
                        onPressed: _load,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: conversations.isEmpty
                      ? const Center(
                          child: Text('暂无会话', style: TextStyle(fontSize: 12)),
                        )
                      : ListView.builder(
                          itemCount: conversations.length,
                          itemBuilder: (context, index) {
                            final c = conversations[index];
                            final isSelected = selectedConversation?.id == c.id;
                            final isAutoReply = c.autopilotMode != 'manual';
                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedTileColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.3),
                              leading: Icon(
                                Icons.forum_outlined,
                                size: 18,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              title: Text(
                                c.title,
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                isAutoReply ? '自动回复已开启' : '自动回复关闭',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isAutoReply ? Colors.green : null,
                                ),
                              ),
                              trailing: Tooltip(
                                message: isAutoReply ? '点击关闭自动回复' : '点击开启自动回复',
                                child: GestureDetector(
                                  onTap: () => _toggleAutoReply(c),
                                  child: Icon(
                                    isAutoReply
                                        ? Icons.smart_toy
                                        : Icons.smart_toy_outlined,
                                    size: 18,
                                    color: isAutoReply
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              onTap: () => _selectConversation(c),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: tokens.spaceSm),

        // 中间: 聊天区域
        Expanded(
          flex: 3,
          child: selectedConversation == null
              ? const AppSurfaceCard(child: Center(child: Text('选择一个会话开始对话')))
              : AppSurfaceCard(
                  child: Column(
                    children: [
                      // 顶部栏
                      _buildChatHeader(context, tokens),
                      const Divider(height: 1),
                      // 消息列表
                      Expanded(child: _buildMessageList(context, tokens)),
                      const Divider(height: 1),
                      // 输入区域
                      _buildInputArea(context, tokens),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildChatHeader(BuildContext context, AppThemeTokens tokens) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceMd,
        vertical: tokens.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              selectedConversation!.title,
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: '清空当前会话消息',
            onPressed: _clearCurrentChat,
          ),
          // 模型快切
          PopupMenuButton<String>(
            tooltip: '切换AI模型',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentModelName(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            ),
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[];
              for (final platform in AiProviderSettings.platforms) {
                // 平台标题
                items.add(
                  PopupMenuItem(
                    enabled: false,
                    height: 28,
                    child: Text(
                      platform.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                );
                // 该平台下的模型
                final hasKey = _platformHasKey(platform.id);
                for (final model in platform.models) {
                  final isCurrent = model == _currentModelName();
                  items.add(
                    PopupMenuItem(
                      value: hasKey ? '${platform.id}|$model' : null,
                      enabled: hasKey,
                      height: 32,
                      child: Row(
                        children: [
                          if (isCurrent)
                            Icon(
                              Icons.check,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          else
                            const SizedBox(width: 14),
                          const SizedBox(width: 6),
                          Text(
                            model,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: !hasKey
                                  ? Colors.grey
                                  : isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          if (!hasKey) ...[
                            const SizedBox(width: 6),
                            Text(
                              '未配Key',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                items.add(const PopupMenuDivider(height: 4));
              }
              return items;
            },
            onSelected: (value) {
              final parts = value.split('|');
              if (parts.length == 2) {
                _switchToModel(parts[0], parts[1]);
              }
            },
          ),
          const SizedBox(width: 8),
          // Autopilot模式选择
          Flexible(
            child: SegmentedButton<AutopilotMode>(
              segments: const [
                ButtonSegment(
                  value: AutopilotMode.manual,
                  label: Tooltip(
                    message: 'AI生成回复草稿，你审核后手动发送',
                    child: Text('手动', style: TextStyle(fontSize: 11)),
                  ),
                  icon: Icon(Icons.person, size: 14),
                ),
                ButtonSegment(
                  value: AutopilotMode.semiAuto,
                  label: Tooltip(
                    message: 'AI置信度高时自动发送，不确定时暂停等你确认',
                    child: Text('半自动', style: TextStyle(fontSize: 11)),
                  ),
                  icon: Icon(Icons.auto_fix_high, size: 14),
                ),
                ButtonSegment(
                  value: AutopilotMode.auto,
                  label: Tooltip(
                    message: 'AI全自动回复，遇到风险或复杂问题才提醒你',
                    child: Text('全自动', style: TextStyle(fontSize: 11)),
                  ),
                  icon: Icon(Icons.smart_toy, size: 14),
                ),
              ],
              selected: {autopilotMode},
              onSelectionChanged: (modes) {
                setState(() => autopilotMode = modes.first);
                _persistAutopilotMode(modes.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(
                  Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context, AppThemeTokens tokens) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(tokens.spaceMd),
      itemCount: currentMessages.length + (isProcessing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == currentMessages.length && isProcessing) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spaceSm),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'AI正在思考...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final msg = currentMessages[index];
        final isCustomer = msg.role == 'customer';

        return Padding(
          padding: EdgeInsets.only(bottom: tokens.spaceSm),
          child: Row(
            mainAxisAlignment: isCustomer
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCustomer) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.orange.shade100,
                  child: const Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: EdgeInsets.all(tokens.spaceSm + 2),
                  decoration: BoxDecoration(
                    color: isCustomer
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.content,
                        style: TextStyle(
                          fontSize: 13,
                          color: isCustomer
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${msg.sentAt.hour.toString().padLeft(2, '0')}:${msg.sentAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isCustomer) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(
                    Icons.smart_toy,
                    size: 16,
                    color: Colors.blue,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputArea(BuildContext context, AppThemeTokens tokens) {
    return Container(
      padding: EdgeInsets.all(tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI建议回复
          if (lastAutopilotResult != null &&
              lastAutopilotResult!.reply.content.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(tokens.spaceSm),
              margin: EdgeInsets.only(bottom: tokens.spaceSm),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.tertiary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lastAutopilotResult!.reply.content,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(lastAutopilotResult!.reply.confidence * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.send, size: 16),
                    tooltip: '采纳并发送',
                    onPressed: () =>
                        _sendReply(lastAutopilotResult!.reply.content),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    tooltip: '编辑后发送',
                    onPressed: () {
                      _inputController.text =
                          lastAutopilotResult!.reply.content;
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
          // 手动输入
          Row(
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: TextField(
                    controller: _inputController,
                    maxLines: null,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: '输入消息，Enter换行，点发送按钮发出',
                      hintStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    scrollPhysics: const ClampingScrollPhysics(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _sendReply(_inputController.text),
                icon: const Icon(Icons.send, size: 16),
                label: const Text('发送', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
