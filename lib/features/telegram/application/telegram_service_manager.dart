import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../../core/platform_utils.dart';
import '../../../core/service_bootstrapper.dart';

/// Telegram个人账号登录信息
class TelegramUserInfo {
  const TelegramUserInfo({this.id, this.firstName, this.username, this.phone});
  final String? id;
  final String? firstName;
  final String? username;
  final String? phone;
}

/// Telegram收到的消息
class TelegramIncomingMessage {
  const TelegramIncomingMessage({
    required this.id,
    required this.text,
    required this.fromId,
    required this.fromName,
    required this.chatId,
    required this.chatName,
    required this.isPrivate,
    required this.isMentioned,
    required this.date,
  });

  final int id;
  final String text;
  final String fromId;
  final String fromName;
  final String chatId;
  final String chatName;
  final bool isPrivate;
  final bool isMentioned;
  final int date;
}

/// Telegram本地服务管理器（内置GramJS，单例）
class TelegramServiceManager {
  factory TelegramServiceManager({http.Client? httpClient}) {
    _instance ??= TelegramServiceManager._(httpClient: httpClient);
    return _instance!;
  }

  TelegramServiceManager._({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  static TelegramServiceManager? _instance;

  final http.Client _client;
  Process? _process;

  static const int port = 3003;

  String get baseUrl => 'http://localhost:$port';

  /// 运行时缓存目录
  String get _serviceDir => PlatformUtils.cachedServiceDir('telegram_service');
  String get _nodePath => ServiceBootstrapper.nodePath;
  String get _entryPath => ServiceBootstrapper.telegramEntryPath;

  bool get isReady =>
      File(_nodePath).existsSync() && File(_entryPath).existsSync();

  Future<bool> isRunning() async {
    try {
      final resp = await _client
          .get(Uri.parse('$baseUrl/healthz'))
          .timeout(const Duration(seconds: 2));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final resp = await _client
          .get(Uri.parse('$baseUrl/healthz'))
          .timeout(const Duration(seconds: 2));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        return body['status'] == 'logged_in';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 启动TG本地服务
  Future<({bool ok, String message})> start({String? apiId, String? apiHash}) async {
    // 总是杀掉旧进程重启——确保用最新的server.js和消息监听器
    if (await isRunning()) {
      stop();
      await PlatformUtils.killPort(port);
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    // 自动引导环境
    if (!isReady) {
      final boot = await ServiceBootstrapper.instance.bootstrapService('telegram_service');
      if (!boot.ok) return (ok: false, message: boot.message);
    }
    if (!isReady) {
      return (ok: false, message: 'Telegram服务环境未就绪');
    }

    try {
      _process = await Process.start(
        _nodePath,
        [_entryPath],
        workingDirectory: _serviceDir,
        environment: {
          ...Platform.environment,
          'TG_PORT': '$port',
          if (apiId != null) 'TG_API_ID': apiId,
          if (apiHash != null) 'TG_API_HASH': apiHash,
        },
      );

      for (int i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (await isRunning()) {
          return (ok: true, message: '服务已启动');
        }
      }
      return (ok: false, message: '启动超时');
    } catch (e) {
      return (ok: false, message: '启动失败: $e');
    }
  }

  /// 发送验证码
  Future<({bool ok, String? error, bool alreadyLoggedIn, TelegramUserInfo? user})> requestCode({
    required String apiId,
    required String apiHash,
    required String phone,
  }) async {
    try {
      final resp = await _client.post(
        Uri.parse('$baseUrl/auth/request-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'apiId': apiId, 'apiHash': apiHash, 'phone': phone}),
      ).timeout(const Duration(seconds: 30));

      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200 && body['success'] == true) {
        if (body['alreadyLoggedIn'] == true) {
          final u = body['user'] as Map<String, dynamic>?;
          return (
            ok: true,
            error: null,
            alreadyLoggedIn: true,
            user: u != null ? TelegramUserInfo(
              id: u['id']?.toString(),
              firstName: u['firstName']?.toString(),
              username: u['username']?.toString(),
              phone: u['phone']?.toString(),
            ) : null,
          );
        }
        return (ok: true, error: null, alreadyLoggedIn: false, user: null);
      }
      return (ok: false, error: body['error']?.toString() ?? '未知错误', alreadyLoggedIn: false, user: null);
    } catch (e) {
      return (ok: false, error: '请求失败: $e', alreadyLoggedIn: false, user: null);
    }
  }

  /// 验证码校验
  Future<({bool ok, String? error, bool needPassword, TelegramUserInfo? user})> verifyCode(String code) async {
    try {
      final resp = await _client.post(
        Uri.parse('$baseUrl/auth/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(resp.body);
      if (body['needPassword'] == true) {
        return (ok: false, error: null, needPassword: true, user: null);
      }
      if (resp.statusCode == 200 && body['success'] == true) {
        final u = body['user'] as Map<String, dynamic>?;
        return (
          ok: true, error: null, needPassword: false,
          user: u != null ? TelegramUserInfo(
            id: u['id']?.toString(),
            firstName: u['firstName']?.toString(),
            username: u['username']?.toString(),
          ) : null,
        );
      }
      return (ok: false, error: body['error']?.toString() ?? '验证失败', needPassword: false, user: null);
    } catch (e) {
      return (ok: false, error: '请求失败: $e', needPassword: false, user: null);
    }
  }

  /// 发消息
  Future<bool> sendMessage({required String peerId, required String text}) async {
    try {
      final resp = await _client.post(
        Uri.parse('$baseUrl/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'peerId': peerId, 'text': text}),
      ).timeout(const Duration(seconds: 10));
      final body = jsonDecode(resp.body);
      return body['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// 长轮询获取新消息
  Future<List<TelegramIncomingMessage>> getMessages() async {
    try {
      final resp = await _client
          .get(Uri.parse('$baseUrl/messages'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return const [];
      final body = jsonDecode(resp.body);
      final list = body['messages'] as List? ?? [];
      return list.map((m) => TelegramIncomingMessage(
        id: m['id'] as int? ?? 0,
        text: m['text'] as String? ?? '',
        fromId: m['fromId']?.toString() ?? '',
        fromName: m['fromName']?.toString() ?? '',
        chatId: m['chatId']?.toString() ?? '',
        chatName: m['chatName']?.toString() ?? '',
        isPrivate: m['isPrivate'] as bool? ?? true,
        isMentioned: m['isMentioned'] as bool? ?? false,
        date: m['date'] as int? ?? 0,
      )).toList();
    } catch (_) {
      return const [];
    }
  }

  void stop() {
    _process?.kill();
    _process = null;
  }
}
