import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_context.dart';
import '../app_theme.dart';
import '../app_widgets.dart';
import '../../../features/channel/domain/channel_adapter.dart';
import '../../../features/telegram/data/official_telegram_adapter.dart';
import '../../../features/telegram/domain/telegram_config.dart';
import '../../../features/telegram/domain/telegram_official_auth_state.dart';
import '../../../features/wecom/application/wecom_tunnel_manager.dart';
import '../../../features/wecom/domain/wecom_config.dart';

const officialTelegramCodeInputKey = Key('officialTelegramCodeInput');

class TelegramCenterPage extends StatefulWidget {
  const TelegramCenterPage({required this.appContext, super.key});

  final AppContext appContext;

  @override
  State<TelegramCenterPage> createState() => _TelegramCenterPageState();
}

class _TelegramCenterPageState extends State<TelegramCenterPage> {
  List<ChannelChatSummary> chats = const [];
  ChannelHealthStatus? healthStatus;

  late final TextEditingController _corpIdController;
  late final TextEditingController _agentIdController;
  late final TextEditingController _secretController;
  late final TextEditingController _apiBaseController;
  late final TextEditingController _callbackPortController;
  late final TextEditingController _callbackPathController;

  late final WeComTunnelManager _weComTunnelManager;
  TunnelStatus _weComTunnelStatus = TunnelStatus.disconnected;
  bool _isConnectingWeComTunnel = false;

  late bool _telegramUseOfficial;
  late final TextEditingController _telegramApiIdController;
  late final TextEditingController _telegramApiHashController;
  late final TextEditingController _telegramPhoneController;
  late final TextEditingController _telegramSessionPathController;
  late final TextEditingController _telegramCodeController;

  @override
  void initState() {
    super.initState();
    final config = widget.appContext.weComConfig;
    _corpIdController = TextEditingController(text: config.corpId);
    _agentIdController = TextEditingController(text: config.agentId);
    _secretController = TextEditingController(text: config.secret);
    _apiBaseController = TextEditingController(text: config.apiBase);
    _callbackPortController = TextEditingController(
      text: config.callbackPort.toString(),
    );
    _callbackPathController = TextEditingController(text: config.callbackPath);

    _weComTunnelStatus = TunnelStatus.disconnected.copyWith(
      publicBaseUrl: config.tunnelPublicBaseUrl.isEmpty
          ? null
          : config.tunnelPublicBaseUrl,
      callbackUrl: config.callbackUrl.isEmpty ? null : config.callbackUrl,
    );
    _weComTunnelManager = WeComTunnelManager(
      onTunnelReady: (publicBaseUrl, callbackUrl) async {
        final callbackPort = int.tryParse(_callbackPortController.text.trim());
        final callbackPath = _normalizedCallbackPath;
        if (callbackPort == null || callbackPort <= 0 || callbackPort > 65535) {
          throw Exception('callbackPort 不合法，无法写入配置');
        }

        final updated = widget.appContext.weComConfig.copyWith(
          callbackPort: callbackPort,
          callbackPath: callbackPath,
          callbackUrl: callbackUrl,
          tunnelPublicBaseUrl: publicBaseUrl,
        );

        await widget.appContext.updateWeComConfig(updated);
      },
    );
    _weComTunnelManager.status.addListener(_handleTunnelStatusChange);

    final tg = widget.appContext.telegramConfig;
    _telegramUseOfficial = tg.useOfficial;
    _telegramApiIdController = TextEditingController(text: tg.apiId);
    _telegramApiHashController = TextEditingController(text: tg.apiHash);
    _telegramPhoneController = TextEditingController(text: tg.phoneNumber);
    _telegramSessionPathController = TextEditingController(
      text: tg.sessionPath ?? '',
    );
    _telegramCodeController = TextEditingController();

    _sync();
  }

  @override
  void dispose() {
    _weComTunnelManager.status.removeListener(_handleTunnelStatusChange);
    unawaited(_weComTunnelManager.dispose());
    _corpIdController.dispose();
    _agentIdController.dispose();
    _secretController.dispose();
    _apiBaseController.dispose();
    _callbackPortController.dispose();
    _callbackPathController.dispose();
    _telegramApiIdController.dispose();
    _telegramApiHashController.dispose();
    _telegramPhoneController.dispose();
    _telegramSessionPathController.dispose();
    _telegramCodeController.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    final rows = await widget.appContext.channelManager.activeAdapter
        .listChats();
    final health = await widget.appContext.channelManager.checkActiveHealth();
    if (!mounted) return;
    setState(() {
      chats = rows;
      healthStatus = health;
    });
  }

  Future<void> _switchChannel(ChannelType value) async {
    await widget.appContext.channelManager.switchTo(value);
    await _sync();
  }

  String get _normalizedCallbackPath {
    final raw = _callbackPathController.text.trim();
    if (raw.isEmpty) return '/wecom/callback';
    return raw.startsWith('/') ? raw : '/$raw';
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _handleTunnelStatusChange() {
    if (!mounted) return;
    setState(() {
      _weComTunnelStatus = _weComTunnelManager.status.value;
    });
  }

  Future<void> _connectWeComTunnel() async {
    final callbackPort = int.tryParse(_callbackPortController.text.trim());
    if (callbackPort == null || callbackPort <= 0 || callbackPort > 65535) {
      _showSnack('callbackPort 必须是 1~65535 的数字');
      return;
    }

    setState(() => _isConnectingWeComTunnel = true);
    try {
      await _saveWeComConfig();
      await _weComTunnelManager.start(
        localPort: callbackPort,
        callbackPath: _normalizedCallbackPath,
      );
      _showSnack('正在连接 WeCom 隧道，请稍候…');
    } catch (e) {
      _showSnack('隧道连接失败：$e');
    } finally {
      if (mounted) {
        setState(() => _isConnectingWeComTunnel = false);
      }
    }
  }

  Future<void> _disconnectWeComTunnel() async {
    await _weComTunnelManager.stop();
    _showSnack('WeCom 隧道已断开');
  }

  Future<void> _copyWeComCallbackUrl() async {
    final callbackUrl =
        _weComTunnelStatus.callbackUrl?.trim().isNotEmpty == true
        ? _weComTunnelStatus.callbackUrl!.trim()
        : widget.appContext.weComConfig.callbackUrl.trim();
    if (callbackUrl.isEmpty) {
      _showSnack('当前没有可复制的回调地址');
      return;
    }
    await Clipboard.setData(ClipboardData(text: callbackUrl));
    _showSnack('回调地址已复制');
  }

  Future<void> _saveWeComConfig() async {
    final callbackPort =
        int.tryParse(_callbackPortController.text.trim()) ?? 3003;
    final callbackPath = _normalizedCallbackPath;

    final config = WeComConfig(
      corpId: _corpIdController.text.trim(),
      agentId: _agentIdController.text.trim(),
      secret: _secretController.text.trim(),
      apiBase: _apiBaseController.text.trim().isEmpty
          ? 'https://qyapi.weixin.qq.com'
          : _apiBaseController.text.trim(),
      callbackPort: callbackPort,
      callbackPath: callbackPath,
      callbackUrl:
          _weComTunnelStatus.callbackUrl ??
          widget.appContext.weComConfig.callbackUrl,
      tunnelPublicBaseUrl:
          _weComTunnelStatus.publicBaseUrl ??
          widget.appContext.weComConfig.tunnelPublicBaseUrl,
    );
    await widget.appContext.updateWeComConfig(config);
    if (mounted && !_weComTunnelStatus.isConnected) {
      setState(() {
        _weComTunnelStatus = _weComTunnelStatus.copyWith(
          publicBaseUrl: config.tunnelPublicBaseUrl,
          callbackUrl: config.callbackUrl,
        );
      });
    }
    await _sync();
  }

  Future<void> _saveTelegramConfig() async {
    final config = TelegramConfig(
      useOfficial: _telegramUseOfficial,
      apiId: _telegramApiIdController.text.trim(),
      apiHash: _telegramApiHashController.text.trim(),
      phoneNumber: _telegramPhoneController.text.trim(),
      sessionPath: _telegramSessionPathController.text.trim(),
    );
    await widget.appContext.updateTelegramConfig(config);
    await _sync();
  }

  Future<void> _requestTelegramCode() async {
    final adapter = widget.appContext.channelManager.activeAdapter;
    if (adapter is! OfficialTelegramAdapter) return;
    await adapter.requestLoginCode();
    await _sync();
  }

  Future<void> _submitTelegramCode() async {
    final adapter = widget.appContext.channelManager.activeAdapter;
    if (adapter is! OfficialTelegramAdapter) return;
    await adapter.submitLoginCode(_telegramCodeController.text.trim());
    await _sync();
  }

  Future<void> _logoutTelegramOfficial() async {
    final adapter = widget.appContext.channelManager.activeAdapter;
    if (adapter is! OfficialTelegramAdapter) return;
    await adapter.logout();
    await _sync();
  }

  Future<void> _reconnectTelegramOfficial() async {
    final adapter = widget.appContext.channelManager.activeAdapter;
    if (adapter is! OfficialTelegramAdapter) return;
    await adapter.reconnect();
    await _sync();
  }

  AppStatusTone _officialStateTone(TelegramOfficialAuthState state) {
    switch (state) {
      case TelegramOfficialAuthState.loggedIn:
        return AppStatusTone.success;
      case TelegramOfficialAuthState.waitingCode:
        return AppStatusTone.warning;
      case TelegramOfficialAuthState.loggedOut:
        return AppStatusTone.neutral;
      case TelegramOfficialAuthState.error:
        return AppStatusTone.danger;
      case TelegramOfficialAuthState.reconnecting:
        return AppStatusTone.warning;
    }
  }

  String _officialStateHint(OfficialTelegramAdapter adapter) {
    return adapter.nextStepHint;
  }

  String _weComTunnelStatusLabel(TunnelStatus status) {
    switch (status.state) {
      case TunnelConnectionState.disconnected:
        return '未连接';
      case TunnelConnectionState.preparing:
        return '准备中';
      case TunnelConnectionState.connecting:
        return '连接中';
      case TunnelConnectionState.connected:
        return '已连接';
      case TunnelConnectionState.error:
        return '异常';
    }
  }

  List<Widget> _officialFlowTags(OfficialTelegramAdapter adapter) {
    const flow = <TelegramOfficialAuthState>[
      TelegramOfficialAuthState.loggedOut,
      TelegramOfficialAuthState.waitingCode,
      TelegramOfficialAuthState.loggedIn,
      TelegramOfficialAuthState.error,
      TelegramOfficialAuthState.reconnecting,
    ];

    return flow
        .map(
          (state) => AppStatusTag(
            label: state == adapter.authState
                ? '● ${state.label}'
                : '○ ${state.label}',
            tone: state == adapter.authState
                ? _officialStateTone(state)
                : AppStatusTone.neutral,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final channelManager = widget.appContext.channelManager;
    final activeAdapter = channelManager.activeAdapter;
    final officialAdapter = activeAdapter is OfficialTelegramAdapter
        ? activeAdapter
        : null;
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppPanelHeader(
            title: 'Channel Center',
            subtitle: '统一管理 Telegram / WeCom 通道、连接健康与聊天同步。',
          ),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              SizedBox(
                width: 160,
                child: AppMetricTile(
                  label: '在线通道',
                  value: channelManager.activeChannel.name,
                ),
              ),
              SizedBox(
                width: 160,
                child: AppMetricTile(label: '聊天数量', value: '${chats.length}'),
              ),
              SizedBox(
                width: 220,
                child: AppMetricTile(
                  label: '链路健康',
                  value: healthStatus == null
                      ? '检查中'
                      : (healthStatus!.healthy ? '健康' : '异常'),
                  tone: healthStatus == null
                      ? AppStatusTone.neutral
                      : (healthStatus!.healthy
                            ? AppStatusTone.success
                            : AppStatusTone.danger),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Wrap(
            spacing: tokens.spaceMd,
            runSpacing: tokens.spaceSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<ChannelType>(
                value: channelManager.activeChannel,
                onChanged: (value) {
                  if (value == null) return;
                  _switchChannel(value);
                },
                items: channelManager.adapters
                    .map(
                      (adapter) => DropdownMenuItem(
                        value: adapter.channelType,
                        child: Text(adapter.displayName),
                      ),
                    )
                    .toList(),
              ),
              FilledButton.icon(
                onPressed: _sync,
                icon: const Icon(Icons.sync),
                label: const Text('同步聊天列表'),
              ),
              AppStatusTag(
                label: '适配器: ${activeAdapter.runtimeType}',
                tone: AppStatusTone.neutral,
              ),
            ],
          ),
          SizedBox(height: tokens.spaceSm),
          if (healthStatus != null)
            AppStatusTag(
              label:
                  '通道状态: ${healthStatus!.healthy ? '健康' : '异常'} · ${healthStatus!.message}',
              tone: healthStatus!.healthy
                  ? AppStatusTone.success
                  : AppStatusTone.danger,
            ),
          if (channelManager.activeChannel == ChannelType.telegram) ...[
            SizedBox(height: tokens.spaceMd),
            AppSurfaceCard(
              padding: EdgeInsets.all(tokens.spaceMd),
              child: Wrap(
                spacing: tokens.spaceSm,
                runSpacing: tokens.spaceSm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    label: const Text('使用官方接入(TDLib路线)'),
                    selected: _telegramUseOfficial,
                    onSelected: (v) => setState(() => _telegramUseOfficial = v),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _telegramApiIdController,
                      decoration: const InputDecoration(labelText: 'apiId'),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _telegramApiHashController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'apiHash'),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _telegramPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'phoneNumber',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _telegramSessionPathController,
                      decoration: const InputDecoration(
                        labelText: 'sessionPath(optional)',
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: _saveTelegramConfig,
                    child: const Text('保存 Telegram 配置'),
                  ),
                ],
              ),
            ),
            if (officialAdapter != null) ...[
              SizedBox(height: tokens.spaceSm),
              AppSurfaceCard(
                padding: EdgeInsets.all(tokens.spaceMd),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppStatusTag(
                      label: '官方链路状态: ${officialAdapter.authState.label}',
                      tone: _officialStateTone(officialAdapter.authState),
                    ),
                    AppStatusTag(
                      label: _officialStateHint(officialAdapter),
                      tone: AppStatusTone.neutral,
                    ),
                    ..._officialFlowTags(officialAdapter),
                    if (officialAdapter.lastError != null)
                      Text(
                        '错误: ${officialAdapter.lastError}',
                        style: TextStyle(color: tokens.danger),
                      ),
                    OutlinedButton(
                      onPressed: officialAdapter.canRequestCode
                          ? _requestTelegramCode
                          : null,
                      child: const Text('请求验证码'),
                    ),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        key: officialTelegramCodeInputKey,
                        controller: _telegramCodeController,
                        decoration: const InputDecoration(labelText: '验证码'),
                      ),
                    ),
                    FilledButton(
                      onPressed: officialAdapter.canSubmitCode
                          ? _submitTelegramCode
                          : null,
                      child: const Text('提交验证码'),
                    ),
                    TextButton(
                      onPressed: officialAdapter.canLogout
                          ? _logoutTelegramOfficial
                          : null,
                      child: const Text('退出登录'),
                    ),
                    OutlinedButton(
                      onPressed: officialAdapter.canReconnect
                          ? _reconnectTelegramOfficial
                          : null,
                      child: const Text('开始重连'),
                    ),
                    if (officialAdapter.authState ==
                        TelegramOfficialAuthState.error)
                      OutlinedButton(
                        onPressed: () async {
                          await officialAdapter.recoverFromError();
                          await _sync();
                        },
                        child: const Text('错误恢复(进入重连)'),
                      ),
                  ],
                ),
              ),
            ],
          ],
          if (channelManager.activeChannel == ChannelType.wecom) ...[
            SizedBox(height: tokens.spaceMd),
            AppSurfaceCard(
              padding: EdgeInsets.all(tokens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: tokens.spaceSm,
                    runSpacing: tokens.spaceSm,
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _corpIdController,
                          decoration: const InputDecoration(
                            labelText: 'corpId',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _agentIdController,
                          decoration: const InputDecoration(
                            labelText: 'agentId',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _secretController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'secret',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _apiBaseController,
                          decoration: const InputDecoration(
                            labelText: 'apiBase',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _callbackPortController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'callbackPort',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 240,
                        child: TextField(
                          controller: _callbackPathController,
                          decoration: const InputDecoration(
                            labelText: 'callbackPath',
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: _saveWeComConfig,
                        child: const Text('保存 WeCom 配置'),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spaceMd),
                  const Text(
                    '企业微信回调隧道（应用内）',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: tokens.spaceSm),
                  Wrap(
                    spacing: tokens.spaceSm,
                    runSpacing: tokens.spaceSm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            (_isConnectingWeComTunnel ||
                                _weComTunnelStatus.isBusy)
                            ? null
                            : _connectWeComTunnel,
                        icon: const Icon(Icons.link_outlined),
                        label: Text(
                          (_isConnectingWeComTunnel ||
                                  _weComTunnelStatus.isBusy)
                              ? '连接中…'
                              : '连接',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _weComTunnelStatus.isConnected
                            ? _disconnectWeComTunnel
                            : null,
                        icon: const Icon(Icons.link_off_outlined),
                        label: const Text('断开'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            ((_weComTunnelStatus.callbackUrl ?? '')
                                    .isNotEmpty ||
                                widget.appContext.weComConfig.callbackUrl
                                    .trim()
                                    .isNotEmpty)
                            ? _copyWeComCallbackUrl
                            : null,
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('复制回调地址'),
                      ),
                      AppStatusTag(
                        label:
                            '状态: ${_weComTunnelStatusLabel(_weComTunnelStatus)}',
                        tone:
                            _weComTunnelStatus.state ==
                                TunnelConnectionState.connected
                            ? AppStatusTone.success
                            : (_weComTunnelStatus.state ==
                                      TunnelConnectionState.error
                                  ? AppStatusTone.danger
                                  : AppStatusTone.neutral),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spaceSm),
                  SelectableText(
                    '公网URL: ${(_weComTunnelStatus.publicBaseUrl ?? widget.appContext.weComConfig.tunnelPublicBaseUrl).isEmpty ? '-' : (_weComTunnelStatus.publicBaseUrl ?? widget.appContext.weComConfig.tunnelPublicBaseUrl)}',
                  ),
                  SizedBox(height: tokens.spaceXs),
                  SelectableText(
                    '回调URL: ${(_weComTunnelStatus.callbackUrl ?? widget.appContext.weComConfig.callbackUrl).isEmpty ? '-' : (_weComTunnelStatus.callbackUrl ?? widget.appContext.weComConfig.callbackUrl)}',
                  ),
                  if ((_weComTunnelStatus.message ?? '').isNotEmpty) ...[
                    SizedBox(height: tokens.spaceXs),
                    Text(
                      _weComTunnelStatus.message!,
                      style: TextStyle(
                        color:
                            _weComTunnelStatus.state ==
                                TunnelConnectionState.error
                            ? tokens.danger
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          SizedBox(height: tokens.spaceMd),
          Expanded(
            child: chats.isEmpty
                ? const Center(child: Text('暂无聊天数据'))
                : AppSurfaceCard(
                    padding: const EdgeInsets.all(8),
                    child: ListView.separated(
                      itemCount: chats.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        return ListTile(
                          leading: Icon(
                            chat.channel == ChannelType.telegram
                                ? Icons.telegram
                                : Icons.business,
                          ),
                          title: Text(chat.title),
                          subtitle: Text(chat.lastMessagePreview),
                          trailing: Text(
                            chat.lastMessageAt.toLocal().toString().substring(
                              11,
                              16,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
