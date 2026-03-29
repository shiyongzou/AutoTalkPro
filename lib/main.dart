import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_context.dart';
import 'app/ui/app_theme.dart';
import 'app/ui/app_widgets.dart';
import 'app/ui/pages/ai_center_page.dart';
import 'app/ui/pages/business_profile_page.dart';
import 'app/ui/pages/conversation_center_page.dart';
import 'app/ui/pages/lock_screen.dart';
import 'app/ui/pages/login_page.dart';
import 'core/logging/support_logger.dart';
import 'features/channel/application/message_bridge.dart';
import 'features/channel/domain/channel_adapter.dart';
import 'features/telegram/application/telegram_service_manager.dart';
import 'features/wechatbot/application/wechat_service_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  runApp(const TgAiSalesApp());
}

class TgAiSalesApp extends StatefulWidget {
  const TgAiSalesApp({super.key, this.contextOverride});

  final AppContext? contextOverride;

  @override
  State<TgAiSalesApp> createState() => _TgAiSalesAppState();
}

class _TgAiSalesAppState extends State<TgAiSalesApp> {
  late final Future<AppContext> _contextFuture;
  String? _accountId;

  ThemeMode _themeMode = ThemeMode.light;
  bool _loggedIn = false;
  bool _prefsLoaded = false;
  bool _listeningRestored = false;
  bool _locked = false;
  StreamSubscription? _wechatSubscription;
  StreamSubscription? _wecomSubscription;
  Timer? _telegramPollTimer;
  Timer? _wechatHealthTimer;

  @override
  void initState() {
    super.initState();
    // 启动时就创建context（只创建一次）
    _contextFuture = _init();
  }

  Future<AppContext> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLock = (prefs.getString('app_lock_password') ?? '').isNotEmpty;
    _accountId = prefs.getString('account_id');

    final ctx =
        widget.contextOverride ??
        await AppContext.create(accountId: _accountId);

    if (mounted) {
      setState(() {
        _loggedIn = prefs.getBool('logged_in') ?? false;
        _locked = hasLock;
        final savedTheme = prefs.getString('theme_mode');
        if (savedTheme == 'dark') _themeMode = ThemeMode.dark;
        _prefsLoaded = true;
      });
    }
    return ctx;
  }

  Future<void> _saveLogin(
    bool value, {
    String? channel,
    String? token,
    String? accountId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('logged_in', value);
    if (channel != null) await prefs.setString('login_channel', channel);
    if (token != null) await prefs.setString('channel_token', token);
    if (accountId != null) await prefs.setString('account_id', accountId);
    if (!value) {
      await prefs.remove('login_channel');
      await prefs.remove('channel_token');
      // 不删account_id——下次登录同一个号还能找到数据
    }
    setState(() => _loggedIn = value);
  }

  /// 应用重启后自动恢复消息监听
  Future<void> _restoreMessageListening(AppContext ctx) async {
    final prefs = await SharedPreferences.getInstance();
    final channelStr = prefs.getString('login_channel');
    final savedToken = prefs.getString('channel_token');
    if (channelStr == null) return;

    LoginChannel? channel;
    if (channelStr == 'wechat') {
      channel = LoginChannel.wechat;
    } else if (channelStr == 'telegram') {
      channel = LoginChannel.telegram;
    } else if (channelStr == 'wecom') {
      channel = LoginChannel.wecom;
    }
    if (channel != null) {
      await _startMessageListening(ctx, channel, token: savedToken);
    }
  }

  /// 登录成功后启动消息监听
  Future<void> _startMessageListening(
    AppContext ctx,
    LoginChannel channel, {
    String? token,
  }) async {
    // Switch the channel manager to the active login channel
    if (channel == LoginChannel.wechat) {
      await ctx.channelManager.switchTo(ChannelType.wechat);
    } else if (channel == LoginChannel.telegram) {
      await ctx.channelManager.switchTo(ChannelType.telegram);
    } else if (channel == LoginChannel.wecom) {
      await ctx.channelManager.switchTo(ChannelType.wecom);
    }

    if (channel == LoginChannel.wechat) {
      // ignore: avoid_print
      print('[BOOT] 微信：启动wechatbot服务...');
      final manager = WeChatServiceManager();
      final startResult = await manager.start();
      // ignore: avoid_print
      print('[BOOT] 微信服务: ${startResult.message}');
      // ignore: avoid_print
      print('[BOOT] 微信：启动回调服务器...');
      await ctx.weChatMessageListener.start();
      // ignore: avoid_print
      print('[BOOT] 微信：回调服务器已启动');
      // 把收到的微信消息转给MessageBridge处理（cancel old subscription first）
      await _wechatSubscription?.cancel();
      _wechatSubscription = ctx.weChatMessageListener.messages.listen((
        msg,
      ) async {
        // ignore: avoid_print
        print(
          '[BOOT] 微信消息流收到: type=${msg.type} isPrivate=${msg.isPrivate} isMentioned=${msg.isMentioned} fromId=${msg.fromId} content=${msg.content.length > 30 ? msg.content.substring(0, 30) : msg.content}',
        );
        await SupportLogger.log(
          'wechat.main',
          'incoming_received',
          extra: {
            'type': msg.type,
            'isPrivate': msg.isPrivate,
            'isMentioned': msg.isMentioned,
            'fromId': msg.fromId,
            'roomId': msg.roomId,
            'contentPreview': msg.content.length > 80
                ? '${msg.content.substring(0, 80)}...'
                : msg.content,
          },
        );

        // isMentioned兜底：wechatbot-webhook的isMentioned不可靠
        // 群消息中包含@就视为被@（不限位置）
        final contentMentioned = !msg.isPrivate && msg.content.contains('@');
        final effectiveMentioned = msg.isMentioned || contentMentioned;
        // ignore: avoid_print
        print(
          '[BOOT] 微信消息过滤: isText=${msg.isText} isPrivate=${msg.isPrivate} isMentioned=${msg.isMentioned} contentMentioned=$contentMentioned → ${msg.isText && (msg.isPrivate || effectiveMentioned) ? "转发" : "跳过"}',
        );
        if (msg.isText && (msg.isPrivate || effectiveMentioned)) {
          // 群消息用群名（发送时webhook按群名查找），私聊用昵称
          final isGroup = !msg.isPrivate && msg.roomId != null;
          final groupName = (msg.roomName != null && msg.roomName!.isNotEmpty)
              ? msg.roomName!
              : '未知群';
          // ignore: avoid_print
          print(
            '[BOOT] 群信息: isGroup=$isGroup roomName=${msg.roomName} roomId=${msg.roomId}',
          );
          // peerId: 私聊=昵称，群聊=room:群名（adapter用于发送）
          // customerId: 私聊=昵称，群聊=群名:发送者（按人分会话，多轮不串）
          final groupPeerId = 'room:$groupName';
          final groupCustomerId = '$groupName:${msg.fromName}';
          final raw = IncomingRawMessage(
            channel: ChannelType.wechat,
            peerId: isGroup ? groupPeerId : msg.fromId,
            peerName: isGroup ? '[群$groupName] ${msg.fromName}' : msg.fromName,
            text: isGroup ? '${msg.fromName}: ${msg.content}' : msg.content,
            customerId: isGroup ? groupCustomerId : null,
            receivedAt: DateTime.now(),
          );
          await SupportLogger.log(
            'wechat.main',
            'incoming_forward_to_bridge',
            extra: {
              'peerId': raw.peerId,
              'peerName': raw.peerName,
              'isGroup': isGroup,
            },
          );
          await ctx.messageBridge.handleIncoming(raw);
        } else {
          await SupportLogger.log(
            'wechat.main',
            'incoming_filtered',
            extra: {
              'reason': !msg.isText ? 'not_text' : 'not_private_or_mentioned',
              'type': msg.type,
              'isPrivate': msg.isPrivate,
              'isMentioned': msg.isMentioned,
            },
          );
        }
      });
      // 微信掉线检测——延迟60秒后开始，连续3次失败才判定离线
      _wechatHealthTimer?.cancel();
      var healthFailCount = 0;
      _wechatHealthTimer = Timer.periodic(const Duration(seconds: 30), (
        timer,
      ) async {
        if (!_loggedIn) return;
        // 前60秒不检测（刚登录，服务可能还在初始化）
        if (timer.tick <= 2) return;
        final online = await manager.isLoggedIn();
        if (online) {
          healthFailCount = 0;
          return;
        }
        healthFailCount++;
        // ignore: avoid_print
        print('[BOOT] 微信健康检测失败 ($healthFailCount/3)');
        if (healthFailCount >= 3) {
          _wechatSubscription?.cancel();
          _wechatSubscription = null;
          _wechatHealthTimer?.cancel();
          _wechatHealthTimer = null;
          _saveLogin(false);
        }
      });
    } else if (channel == LoginChannel.wecom) {
      try {
        await ctx.weComMessageListener.start();
      } catch (e) {
        await SupportLogger.log(
          'wecom.main',
          'listener_start_failed',
          extra: {
            'error': e.toString(),
            'callbackUrl': ctx.weComMessageListener.callbackUrl,
          },
        );
        rethrow;
      }
      await _wecomSubscription?.cancel();
      _wecomSubscription = ctx.weComMessageListener.messages.listen((
        msg,
      ) async {
        await SupportLogger.log(
          'wecom.main',
          'incoming_received',
          extra: {
            'msgType': msg.msgType,
            'fromUserId': msg.fromUserId,
            'toUserId': msg.toUserId,
            'agentId': msg.agentId,
            'msgId': msg.msgId,
            'contentPreview': msg.content.length > 80
                ? '${msg.content.substring(0, 80)}...'
                : msg.content,
          },
        );

        if (msg.isText && msg.fromUserId.trim().isNotEmpty) {
          await ctx.messageBridge.handleIncoming(
            IncomingRawMessage(
              channel: ChannelType.wecom,
              peerId: msg.fromUserId,
              peerName: msg.fromUserId,
              text: msg.content,
              receivedAt: DateTime.now(),
            ),
          );
        } else {
          await SupportLogger.log(
            'wecom.main',
            'incoming_filtered',
            extra: {
              'reason': !msg.isText ? 'not_text' : 'empty_user',
              'msgType': msg.msgType,
              'fromUserId': msg.fromUserId,
            },
          );
        }
      });
    } else if (channel == LoginChannel.telegram) {
      // 启动TG服务（如果没跑）
      final tgManager = TelegramServiceManager();
      String? apiId;
      String? apiHash;
      if (token != null && token.contains(':')) {
        final parts = token.split(':');
        apiId = parts[0];
        apiHash = parts[1];
      }
      await tgManager.start(apiId: apiId, apiHash: apiHash);
      // 等server.js的auto-login完成（它会自动调startMessageListener）
      await Future<void>.delayed(const Duration(seconds: 5));
      // 如果auto-login没成功，手动触发
      if (!await tgManager.isLoggedIn() && apiId != null && apiHash != null) {
        await tgManager.requestCode(
          apiId: apiId,
          apiHash: apiHash,
          phone: 'reconnect',
        );
      }
      _startTelegramPolling(ctx, tgManager);
    }
  }

  /// TG消息长轮询
  void _startTelegramPolling(AppContext ctx, TelegramServiceManager manager) {
    _telegramPollTimer?.cancel();
    _telegramPollTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      if (!_loggedIn) {
        timer.cancel();
        return;
      }
      try {
        final messages = await manager.getMessages();
        for (final msg in messages) {
          if (msg.text.isNotEmpty && (msg.isPrivate || msg.isMentioned)) {
            final isGroup = !msg.isPrivate;
            ctx.messageBridge.handleIncoming(
              IncomingRawMessage(
                channel: ChannelType.telegram,
                peerId: msg.chatId,
                peerName: isGroup ? '[群] ${msg.chatName}' : msg.fromName,
                text: isGroup ? '${msg.fromName}: ${msg.text}' : msg.text,
                receivedAt: DateTime.fromMillisecondsSinceEpoch(
                  msg.date * 1000,
                ),
              ),
            );
          }
        }
      } catch (_) {}
    });
  }

  void _toggleThemeMode() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(
        'theme_mode',
        _themeMode == ThemeMode.dark ? 'dark' : 'light',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Auto Talk Pro',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: FutureBuilder<AppContext>(
        future: _contextFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('启动失败: ${snapshot.error}')),
              );
            }
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 等prefs加载完
          if (!_prefsLoaded && widget.contextOverride == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 锁屏
          if (_locked && widget.contextOverride == null) {
            return LockScreen(onUnlock: () => setState(() => _locked = false));
          }

          // 登录页
          if (!_loggedIn && widget.contextOverride == null) {
            return LoginPage(
              appContext: snapshot.data!,
              onLoginSuccess: (channel, {token}) {
                // 稳定的accountId——同一个渠道同一个ID，不会每次变
                final acctId = channel.name;
                _saveLogin(
                  true,
                  channel: channel.name,
                  token: token,
                  accountId: acctId,
                );
                _startMessageListening(snapshot.data!, channel, token: token);
              },
            );
          }

          // 已登录，自动恢复消息监听（只执行一次）
          // 测试注入 context 时不恢复，避免后台轮询导致测试无法 settle。
          if (!_listeningRestored && widget.contextOverride == null) {
            _listeningRestored = true;
            _restoreMessageListening(snapshot.data!);
          }

          return WorkspacePage(
            appContext: snapshot.data!,
            onToggleTheme: _toggleThemeMode,
            isDarkMode: _themeMode == ThemeMode.dark,
            onLogout: () {
              // 停消息监听
              _wechatSubscription?.cancel();
              _wechatSubscription = null;
              _wecomSubscription?.cancel();
              _wecomSubscription = null;
              _telegramPollTimer?.cancel();
              _telegramPollTimer = null;
              _wechatHealthTimer?.cancel();
              _wechatHealthTimer = null;
              snapshot.data!.weChatMessageListener.dispose();
              snapshot.data!.weComMessageListener.dispose();
              // 停后台服务
              WeChatServiceManager().stop();
              TelegramServiceManager().stop();
              // 重置状态
              _listeningRestored = false;
              _saveLogin(false);
            },
            onLock: () => setState(() => _locked = true),
          );
        },
      ),
    );
  }
}

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({
    required this.appContext,
    required this.onToggleTheme,
    required this.isDarkMode,
    required this.onLogout,
    required this.onLock,
    super.key,
  });

  final AppContext appContext;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final VoidCallback onLogout;
  final VoidCallback onLock;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  int selectedIndex = 0;

  final sections = const <_SectionItem>[
    _SectionItem(
      '会话',
      Icons.chat_bubble_outline,
      'Conversation Center',
      '所有聊天在这里，AI自动帮你回复',
    ),
    _SectionItem(
      '人设',
      Icons.person_outline,
      'Business Profile',
      '设定AI的职业身份和专业领域',
    ),
    _SectionItem('AI设置', Icons.smart_toy_outlined, 'AI Center', '选择AI模型，配置API'),
  ];

  Timer? _idleTimer;
  static const _idleTimeout = Duration(minutes: 5);

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () async {
      if (await LockSettings.isEnabled()) {
        widget.onLock();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final section = sections[selectedIndex];
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;

    return Listener(
      onPointerDown: (_) => _resetIdleTimer(),
      onPointerMove: (_) => _resetIdleTimer(),
      child: Scaffold(
        body: Row(
          children: [
            // 自定义侧边栏（可滚动，不溢出）
            SizedBox(
              width: 90,
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        top: tokens.spaceMd,
                        bottom: tokens.spaceSm,
                      ),
                      child: Icon(
                        Icons.rocket_launch_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 26,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: List.generate(sections.length, (i) {
                            final e = sections[i];
                            final isSelected = selectedIndex == i;
                            return Tooltip(
                              message: '${e.title}\n${e.tooltip}',
                              preferBelow: false,
                              waitDuration: const Duration(milliseconds: 300),
                              child: InkWell(
                                onTap: () => setState(() => selectedIndex = i),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withValues(alpha: 0.5)
                                        : null,
                                    border: isSelected
                                        ? Border(
                                            left: BorderSide(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              width: 3,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        e.icon,
                                        size: 24,
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        e.title,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(tokens.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppPanelHeader(
                      title: 'Auto Talk Pro',
                      subtitle: section.title,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: widget.onToggleTheme,
                            icon: Icon(
                              widget.isDarkMode
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                            ),
                            label: Text(widget.isDarkMode ? '浅色' : '深色'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.lock, size: 18),
                            tooltip: '立即锁屏',
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              if (await LockSettings.isEnabled()) {
                                widget.onLock();
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('请先设置密码')),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.lock_outline, size: 18),
                            tooltip: '设置/修改密码',
                            onPressed: () => _showLockSettings(context),
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton.icon(
                            onPressed: widget.onLogout,
                            icon: const Icon(Icons.logout, size: 16),
                            label: const Text('退出登录'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildSection(section.key)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLockSettings(BuildContext context) async {
    final controller = TextEditingController();
    final isEnabled = await LockSettings.isEnabled();

    final confirmController = TextEditingController();

    if (!context.mounted) {
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(isEnabled ? '修改或关闭密码' : '设置应用锁密码'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '输入密码',
                    hintText: isEnabled ? '留空则关闭密码锁' : '设置一个密码',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '再输入一次确认',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              if (isEnabled)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: const Text(
                    '关闭密码锁',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              FilledButton(
                onPressed: () {
                  if (controller.text.isNotEmpty &&
                      controller.text != confirmController.text) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('两次密码不一致'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx, controller.text);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) {
      return;
    }
    await LockSettings.setPassword(result);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isEmpty ? '密码锁已关闭' : '密码已设置，下次启动生效'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Widget _buildSection(String title) {
    switch (title) {
      case 'Conversation Center':
        return ConversationCenterPage(appContext: widget.appContext);
      case 'Business Profile':
        return BusinessProfilePage(appContext: widget.appContext);
      case 'AI Center':
        return AiCenterPage(appContext: widget.appContext);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SectionItem {
  const _SectionItem(this.title, this.icon, this.key, this.tooltip);

  final String title; // 中文显示名
  final IconData icon;
  final String key; // 路由key
  final String tooltip; // 鼠标悬浮提示
}
