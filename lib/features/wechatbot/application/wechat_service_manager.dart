import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../core/platform_utils.dart';
import '../../../core/service_bootstrapper.dart';

/// 微信机器人本地服务管理器（单例）
class WeChatServiceManager {
  factory WeChatServiceManager({http.Client? httpClient}) {
    _instance ??= WeChatServiceManager._(httpClient: httpClient);
    return _instance!;
  }

  WeChatServiceManager._({http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  static WeChatServiceManager? _instance;

  final http.Client _client;
  Process? _process;
  IOSink? _sink;

  static const int port = 3001;
  static const int callbackPort = 3002;
  static const String token = 'ai_trade_local';
  static final String _qrFilePath = PlatformUtils.tempFilePath(
    '.wechat_qr_output',
  );

  String get baseUrl => 'http://localhost:$port';
  String get healthUrl => '$baseUrl/healthz?token=$token';

  /// 运行时缓存目录（node_modules在这里）
  String get _serviceDir => PlatformUtils.cachedServiceDir('wechat_service');
  String get _nodePath => ServiceBootstrapper.nodePath;
  String get _entryPath => ServiceBootstrapper.wechatEntryPath;

  bool get isReady =>
      File(_nodePath).existsSync() && File(_entryPath).existsSync();

  /// 读取QR码
  String? get qrCodeText {
    try {
      final f = File(_qrFilePath);
      if (!f.existsSync()) return null;
      final content = f.readAsStringSync();
      final qrLines = content
          .split('\n')
          .where((line) => line.contains('█') || line.contains('▄'))
          .toList();
      return qrLines.length >= 10 ? qrLines.join('\n') : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isRunning() async {
    try {
      final resp = await _client
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 2));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final resp = await _client
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 2));
      // wechatbot-webhook: "healthy" = 已登录, "unHealthy" = 未登录
      return resp.body == 'healthy';
    } catch (_) {
      return false;
    }
  }

  /// 构造环境变量（直接传给进程，不依赖.env文件位置）
  Map<String, String> _buildEnv() => {
    ...Platform.environment,
    'PORT': '$port',
    'LOG_LEVEL': 'info',
    'DISABLE_AUTO_LOGIN': '',
    'ACCEPT_RECVD_MSG_MYSELF': 'false',
    'LOCAL_RECVD_MSG_API': 'http://localhost:$callbackPort/callback',
    'LOCAL_LOGIN_API_TOKEN': token,
  };

  /// 写配置文件（兜底：写到工作目录的.env）
  Future<void> _writeEnvFile() async {
    final envFile = File(p.join(_serviceDir, '.env'));
    await envFile.writeAsString('''
PORT=$port
LOG_LEVEL=info
DISABLE_AUTO_LOGIN=
ACCEPT_RECVD_MSG_MYSELF=false
LOCAL_RECVD_MSG_API=http://localhost:$callbackPort/callback
LOCAL_LOGIN_API_TOKEN=$token
''');
  }

  /// 杀掉端口上的旧进程
  Future<void> _killPortProcess() async {
    await PlatformUtils.killPort(port);
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  /// 启动服务（总是重启确保配置最新）
  Future<({bool ok, String message})> start() async {
    // 如果有旧进程在跑，先杀掉重启——确保env配置（回调地址等）是最新的
    if (await isRunning()) {
      await _killPortProcess();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    // 自动引导环境（首次下载Node+依赖）
    if (!isReady) {
      final boot = await ServiceBootstrapper.instance.bootstrapService(
        'wechat_service',
      );
      if (!boot.ok) return (ok: false, message: boot.message);
    }
    if (!isReady) {
      return (ok: false, message: '微信服务环境未就绪');
    }

    await _killPortProcess();

    try {
      await _writeEnvFile();

      // 清旧QR文件
      final qrFile = File(_qrFilePath);
      if (qrFile.existsSync()) qrFile.deleteSync();

      _process = await Process.start(
        _nodePath,
        [_entryPath],
        workingDirectory: _serviceDir,
        environment: _buildEnv(),
      );

      // stdout/stderr写文件
      _sink = qrFile.openWrite();
      _process!.stdout.listen(
        (data) => _sink?.add(data),
        onDone: () {
          _sink?.close();
          _sink = null;
        },
      );
      _process!.stderr.listen((data) => _sink?.add(data));

      // 等服务启动
      for (int i = 0; i < 15; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (await isRunning()) {
          // 多等2秒让QR码完整输出
          await Future<void>.delayed(const Duration(seconds: 2));
          // 刷新文件
          await _sink?.flush();
          return (ok: true, message: '服务已启动');
        }
      }

      return (ok: false, message: '服务启动超时');
    } catch (e) {
      return (ok: false, message: '启动失败: $e');
    }
  }

  /// 停止服务
  Future<void> stop() async {
    _process?.kill();
    _process = null;
    await _sink?.close();
    _sink = null;
    await _killPortProcess();
    try {
      final f = File(_qrFilePath);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  /// 一键启动
  Future<({bool ok, String message, String step})> setup({
    void Function(String status)? onProgress,
  }) async {
    // 首次使用自动下载环境
    if (!isReady) {
      onProgress?.call('正在准备运行环境...');
      final boot = await ServiceBootstrapper.instance.bootstrapService(
        'wechat_service',
        onProgress: onProgress,
      );
      if (!boot.ok) {
        return (ok: false, message: boot.message, step: 'error');
      }
    }

    onProgress?.call('正在启动微信服务...');
    final result = await start();
    if (!result.ok) {
      return (ok: false, message: result.message, step: 'error');
    }

    if (await isLoggedIn()) {
      return (ok: true, message: '微信已登录', step: 'done');
    }

    return (ok: true, message: '服务已启动，请扫码', step: 'scan');
  }

  void dispose() {
    stop();
  }
}
