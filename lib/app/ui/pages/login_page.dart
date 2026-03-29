import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/service_bootstrapper.dart';
import '../../app_context.dart';
import '../../../features/telegram/application/telegram_service_manager.dart';
import '../../../features/wechatbot/application/wechat_service_manager.dart';
import '../../../features/wecom/domain/wecom_config.dart';

enum LoginChannel { telegram, wechat, wecom }

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.appContext,
    required this.onLoginSuccess,
    super.key,
  });

  final AppContext appContext;
  final void Function(LoginChannel channel, {String? token}) onLoginSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  LoginChannel? selectedChannel;
  bool _bootstrapping = false;
  String _bootstrapStatus = '';

  /// 选择渠道时，先检查是否需要引导环境
  Future<void> _selectChannel(LoginChannel channel) async {
    // 企业微信不需要 Node 环境
    if (channel == LoginChannel.wecom) {
      setState(() => selectedChannel = channel);
      return;
    }

    final bootstrapper = ServiceBootstrapper.instance;
    final serviceName = channel == LoginChannel.wechat
        ? 'wechat_service'
        : 'telegram_service';

    // 已就绪直接进
    if (bootstrapper.isNodeReady && bootstrapper.isServiceReady(serviceName)) {
      setState(() => selectedChannel = channel);
      return;
    }

    // 需要下载——显示进度
    setState(() {
      _bootstrapping = true;
      _bootstrapStatus = '正在准备运行环境...';
      selectedChannel = channel;
    });

    final result = await bootstrapper.bootstrapService(
      serviceName,
      onProgress: (status) {
        if (mounted) setState(() => _bootstrapStatus = status);
      },
    );

    if (!mounted) return;
    setState(() => _bootstrapping = false);

    if (!result.ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
      setState(() => selectedChannel = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 500,
          child: _bootstrapping
              ? _buildBootstrapProgress(scheme)
              : selectedChannel == null
              ? _buildChannelSelect(scheme)
              : _buildLoginForm(scheme),
        ),
      ),
    );
  }

  Widget _buildBootstrapProgress(ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.downloading_outlined, size: 48, color: scheme.primary),
        const SizedBox(height: 20),
        Text('首次使用，正在准备环境', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          '下载 Node.js 运行环境和服务依赖，仅首次需要',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        const LinearProgressIndicator(),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _bootstrapStatus,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '请稍候，大约需要1-2分钟...',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildChannelSelect(ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.rocket_launch_outlined, size: 56, color: scheme.primary),
        const SizedBox(height: 16),
        Text('AutoTalk Pro', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          '选择消息渠道登录',
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 36),
        _channelButton(
          icon: Icons.send_outlined,
          title: 'Telegram',
          subtitle: '使用个人账号登录，输入手机号 + 验证码',
          onTap: () => _selectChannel(LoginChannel.telegram),
        ),
        const SizedBox(height: 12),
        _channelButton(
          icon: Icons.chat_outlined,
          title: '微信',
          subtitle: '自动启动服务，扫码登录',
          onTap: () => _selectChannel(LoginChannel.wechat),
        ),
        const SizedBox(height: 12),
        _channelButton(
          icon: Icons.business_outlined,
          title: '企业微信',
          subtitle: '输入企业ID、应用ID、Secret，接入官方回调收发',
          onTap: () => _selectChannel(LoginChannel.wecom),
        ),
      ],
    );
  }

  Widget _channelButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 28, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 返回按钮
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => selectedChannel = null),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('返回选择'),
          ),
        ),
        const SizedBox(height: 12),
        if (selectedChannel == LoginChannel.telegram)
          _TelegramLoginForm(
            onSuccess: (token) =>
                widget.onLoginSuccess(LoginChannel.telegram, token: token),
          ),
        if (selectedChannel == LoginChannel.wechat)
          _WeChatLoginForm(
            onSuccess: () => widget.onLoginSuccess(LoginChannel.wechat),
          ),
        if (selectedChannel == LoginChannel.wecom)
          _WeComLoginForm(
            appContext: widget.appContext,
            onSuccess: () => widget.onLoginSuccess(LoginChannel.wecom),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// Telegram 个人账号登录（api_id + api_hash + 验证码）
// ═══════════════════════════════════════════
class _TelegramLoginForm extends StatefulWidget {
  const _TelegramLoginForm({required this.onSuccess});
  final void Function(String token) onSuccess;

  @override
  State<_TelegramLoginForm> createState() => _TelegramLoginFormState();
}

class _TelegramLoginFormState extends State<_TelegramLoginForm> {
  // 内置凭据，用户无需申请
  static const _builtinApiId = '2040';
  static const _builtinApiHash = 'b18441a1ff607e10a989891a5462e627';

  final _phoneCtl = TextEditingController();
  final _codeCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _manager = TelegramServiceManager();
  bool _loading = false;
  String? _error;
  String? _userInfo;
  String _step = 'phone'; // phone → codeSent → password → done

  @override
  void dispose() {
    _phoneCtl.dispose();
    _codeCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_phoneCtl.text.trim().isEmpty) {
      setState(() => _error = '请输入手机号');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // 启动本地TG服务
    final startResult = await _manager.start(
      apiId: _builtinApiId,
      apiHash: _builtinApiHash,
    );
    if (!startResult.ok) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = startResult.message;
      });
      return;
    }

    // 发送验证码
    final result = await _manager.requestCode(
      apiId: _builtinApiId,
      apiHash: _builtinApiHash,
      phone: _phoneCtl.text.trim(),
    );

    if (!mounted) return;
    if (result.alreadyLoggedIn) {
      setState(() {
        _step = 'done';
        _loading = false;
        _userInfo =
            '${result.user?.firstName ?? ''} (@${result.user?.username ?? ''})';
      });
      return;
    }
    if (result.ok) {
      setState(() {
        _step = 'codeSent';
        _loading = false;
      });
    } else {
      setState(() {
        _error = result.error;
        _loading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_codeCtl.text.trim().isEmpty) {
      setState(() => _error = '请输入验证码');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _manager.verifyCode(_codeCtl.text.trim());

    if (!mounted) return;
    if (result.needPassword) {
      setState(() {
        _step = 'password';
        _loading = false;
      });
      return;
    }
    if (result.ok) {
      setState(() {
        _step = 'done';
        _loading = false;
        _userInfo =
            '${result.user?.firstName ?? ''} (@${result.user?.username ?? ''})';
      });
    } else {
      setState(() {
        _error = result.error;
        _loading = false;
      });
    }
  }

  Future<void> _verifyPassword() async {
    // 两步验证暂不支持完整流程
    setState(() => _error = '请在Telegram设置中暂时关闭两步验证后重试');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.send_outlined, size: 24, color: scheme.primary),
            const SizedBox(width: 10),
            Text('Telegram 登录', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '输入你的Telegram手机号，我们会发送验证码到你的Telegram',
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _phoneCtl,
          enabled: _step == 'phone',
          decoration: const InputDecoration(
            labelText: '手机号',
            hintText: '带国际区号，如 +8613800138000',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          style: const TextStyle(fontSize: 14),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),

        if (_step == 'codeSent' || _step == 'password' || _step == 'done') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.sms, color: Colors.blue, size: 20),
                SizedBox(width: 10),
                Text('验证码已发送到你的Telegram', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          if (_step == 'codeSent')
            TextField(
              controller: _codeCtl,
              decoration: const InputDecoration(
                labelText: '验证码',
                hintText: '输入收到的验证码',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 14),
              keyboardType: TextInputType.number,
            ),
          if (_step == 'password')
            TextField(
              controller: _passwordCtl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '两步验证密码',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          const SizedBox(height: 16),
        ],

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ),

        if (_step == 'done')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '登录成功: ${_userInfo ?? ""}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Row(
          children: [
            if (_step == 'phone')
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : _requestCode,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('获取验证码'),
                ),
              ),
            if (_step == 'codeSent')
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : _verifyCode,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('验证登录'),
                ),
              ),
            if (_step == 'password')
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : _verifyPassword,
                  child: const Text('验证密码'),
                ),
              ),
            if (_step == 'done')
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      widget.onSuccess('$_builtinApiId:$_builtinApiHash'),
                  child: const Text('进入平台'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// 微信 扫码登录（内置服务，自动启动）
// ═══════════════════════════════════════════
class _WeChatLoginForm extends StatefulWidget {
  const _WeChatLoginForm({required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<_WeChatLoginForm> createState() => _WeChatLoginFormState();
}

class _WeChatLoginFormState extends State<_WeChatLoginForm> {
  final _manager = WeChatServiceManager();
  bool _loading = false;
  String? _error;
  String _step = 'init'; // init → setting_up → scanning → done
  String _statusText = '';
  String? _qrText;

  @override
  void initState() {
    super.initState();
    _autoSetup();
  }

  @override
  void dispose() {
    // 不停服务——进入平台后还要用
    super.dispose();
  }

  Future<void> _autoSetup() async {
    setState(() {
      _loading = true;
      _error = null;
      _step = 'setting_up';
    });

    final result = await _manager.setup(
      onProgress: (status) {
        if (mounted) setState(() => _statusText = status);
      },
    );

    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _loading = false;
        _error = result.message;
        _step = 'init';
        _statusText = result.message;
      });
      return;
    }

    if (result.step == 'done') {
      setState(() {
        _step = 'done';
        _loading = false;
        _statusText = '微信已登录';
      });
    } else {
      setState(() {
        _step = 'scanning';
        _loading = false;
        _statusText = '请扫码登录';
      });
      _pollQrCode();
    }
  }

  /// 轮询等待QR码出现
  Future<void> _pollQrCode() async {
    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || _step != 'scanning') return;
      final qr = _manager.qrCodeText;
      if (qr != null && qr.isNotEmpty) {
        setState(() => _qrText = qr);
        return;
      }
    }
    // 超时仍没QR
    if (mounted && _step == 'scanning') {
      setState(() => _error = '二维码加载超时，请点击"刷新二维码"重试');
    }
  }

  /// 重启服务获取新二维码
  Future<void> _refreshQrCode() async {
    setState(() {
      _qrText = null;
      _error = null;
      _loading = true;
      _statusText = '正在刷新二维码...';
    });
    await _manager.stop();
    await Future<void>.delayed(const Duration(seconds: 1));
    final result = await _manager.start();
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }
    setState(() {
      _loading = false;
      _statusText = '请扫码登录';
    });
    _pollQrCode();
  }

  Future<void> _checkLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (await _manager.isLoggedIn()) {
      setState(() {
        _step = 'done';
        _loading = false;
        _statusText = '微信已登录';
      });
    } else {
      setState(() {
        _loading = false;
        _error = '还没扫码成功，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.chat_outlined, size: 24, color: scheme.primary),
            const SizedBox(width: 10),
            Text('微信扫码登录', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 20),

        // 状态条
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              if (_loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_step == 'done')
                const Icon(Icons.check_circle, color: Colors.green, size: 20)
              else if (_error != null)
                Icon(Icons.error_outline, color: scheme.error, size: 20)
              else
                Icon(Icons.info_outline, size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusText.isEmpty ? '准备中...' : _statusText,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
        ],

        const SizedBox(height: 16),

        // 扫码
        if (_step == 'scanning') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  '用微信扫描下方二维码',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (_qrText != null && _qrText!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Text(
                        _qrText!,
                        style: const TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 12,
                          height: 1.1,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(height: 12),
                        Text('正在加载二维码...'),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '扫完后点下方按钮',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : _checkLogin,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('我已扫码'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _refreshQrCode,
                child: const Text('刷新二维码'),
              ),
            ],
          ),
        ],

        // 初始失败重试
        if (_step == 'init' && !_loading)
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _autoSetup, child: const Text('重试')),
          ),

        // 登录成功
        if (_step == 'done') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 10),
                Text(
                  '微信已登录',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.onSuccess,
              child: const Text('进入平台'),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════
// 企业微信 登录
// ═══════════════════════════════════════════
class _WeComLoginForm extends StatefulWidget {
  const _WeComLoginForm({required this.appContext, required this.onSuccess});

  final AppContext appContext;
  final VoidCallback onSuccess;

  @override
  State<_WeComLoginForm> createState() => _WeComLoginFormState();
}

class _WeComLoginFormState extends State<_WeComLoginForm> {
  final _corpIdCtl = TextEditingController();
  final _agentIdCtl = TextEditingController();
  final _secretCtl = TextEditingController();
  final _callbackPortCtl = TextEditingController(text: '3003');
  final _callbackPathCtl = TextEditingController(text: '/wecom/callback');

  bool _loading = false;
  String? _error;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    final cfg = widget.appContext.weComConfig;
    _corpIdCtl.text = cfg.corpId;
    _agentIdCtl.text = cfg.agentId;
    _secretCtl.text = cfg.secret;
    _callbackPortCtl.text = cfg.callbackPort.toString();
    _callbackPathCtl.text = cfg.callbackPath;
  }

  @override
  void dispose() {
    _corpIdCtl.dispose();
    _agentIdCtl.dispose();
    _secretCtl.dispose();
    _callbackPortCtl.dispose();
    _callbackPathCtl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final corpId = _corpIdCtl.text.trim();
    final agentId = _agentIdCtl.text.trim();
    final secret = _secretCtl.text.trim();
    final callbackPort = int.tryParse(_callbackPortCtl.text.trim());
    final callbackPath = _callbackPathCtl.text.trim();

    if (corpId.isEmpty || agentId.isEmpty || secret.isEmpty) {
      setState(() => _error = '请填写 corpId / agentId / secret');
      return;
    }
    if (callbackPort == null || callbackPort <= 0 || callbackPort > 65535) {
      setState(() => _error = 'callbackPort 必须是 1~65535 的数字');
      return;
    }
    if (callbackPath.isEmpty || !callbackPath.startsWith('/')) {
      setState(() => _error = 'callbackPath 必须以 / 开头');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = Uri.parse(
        'https://qyapi.weixin.qq.com/cgi-bin/gettoken'
        '?corpid=${Uri.encodeComponent(corpId)}'
        '&corpsecret=${Uri.encodeComponent(secret)}',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final errcode = body['errcode'] as int?;
        if (errcode == 0) {
          final config = WeComConfig(
            corpId: corpId,
            agentId: agentId,
            secret: secret,
            callbackPort: callbackPort,
            callbackPath: callbackPath,
          );
          await widget.appContext.updateWeComConfig(config);
          setState(() {
            _verified = true;
            _loading = false;
          });
          return;
        }
        final errmsg = body['errmsg'] ?? '未知错误';
        setState(() {
          _error = '验证失败: $errmsg';
          _loading = false;
        });
        return;
      }

      setState(() {
        _error = '请求失败(${resp.statusCode})';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = '连接失败，请检查网络';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.business_outlined, size: 24, color: scheme.primary),
            const SizedBox(width: 10),
            Text('企业微信登录', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '填写企业微信应用参数后，桌面端会启动本地回调监听并接管收发链路。',
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _corpIdCtl,
          decoration: const InputDecoration(
            labelText: '企业ID (Corp ID)',
            hintText: 'ww开头的企业ID',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _agentIdCtl,
          decoration: const InputDecoration(
            labelText: '应用ID (Agent ID)',
            hintText: '数字，如 1000002',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _secretCtl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Secret',
            hintText: '应用的Secret密钥',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _callbackPortCtl,
                decoration: const InputDecoration(
                  labelText: '回调端口',
                  hintText: '3003',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _callbackPathCtl,
                decoration: const InputDecoration(
                  labelText: '回调路径',
                  hintText: '/wecom/callback',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ),
        if (_verified)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 10),
                Text(
                  '企业微信连接成功，配置已保存',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        Row(
          children: [
            if (!_verified)
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : _verify,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('验证并保存'),
                ),
              ),
            if (_verified)
              Expanded(
                child: FilledButton(
                  onPressed: widget.onSuccess,
                  child: const Text('进入平台'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
