import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum TunnelConnectionState {
  disconnected,
  preparing,
  connecting,
  connected,
  error,
}

class TunnelStatus {
  const TunnelStatus({
    required this.state,
    this.publicBaseUrl,
    this.callbackUrl,
    this.message,
  });

  final TunnelConnectionState state;
  final String? publicBaseUrl;
  final String? callbackUrl;
  final String? message;

  bool get isBusy =>
      state == TunnelConnectionState.preparing ||
      state == TunnelConnectionState.connecting;

  bool get isConnected => state == TunnelConnectionState.connected;

  TunnelStatus copyWith({
    TunnelConnectionState? state,
    String? publicBaseUrl,
    String? callbackUrl,
    String? message,
    bool clearMessage = false,
  }) {
    return TunnelStatus(
      state: state ?? this.state,
      publicBaseUrl: publicBaseUrl ?? this.publicBaseUrl,
      callbackUrl: callbackUrl ?? this.callbackUrl,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  static const disconnected = TunnelStatus(
    state: TunnelConnectionState.disconnected,
  );
}

class CommandResult {
  const CommandResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

abstract class ManagedProcess {
  Stream<String> get stdoutLines;
  Stream<String> get stderrLines;
  Future<int> get exitCode;
  Future<void> kill();
}

abstract class TunnelProcessRunner {
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  });

  Future<ManagedProcess> start(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  });
}

class IoManagedProcess implements ManagedProcess {
  IoManagedProcess(this._process)
    : stdoutLines = _process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter()),
      stderrLines = _process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter());

  final Process _process;

  @override
  final Stream<String> stdoutLines;

  @override
  final Stream<String> stderrLines;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Future<void> kill() async {
    _process.kill(ProcessSignal.sigterm);
  }
}

class IoTunnelProcessRunner implements TunnelProcessRunner {
  const IoTunnelProcessRunner();

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: Platform.isWindows,
    );

    return CommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout?.toString() ?? '',
      stderr: result.stderr?.toString() ?? '',
    );
  }

  @override
  Future<ManagedProcess> start(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: Platform.isWindows,
    );

    return IoManagedProcess(process);
  }
}

typedef RuntimeDirectoryProvider = Future<Directory> Function();
typedef TunnelUrlPersistor =
    Future<void> Function(String publicBaseUrl, String callbackUrl);

class WeComTunnelManager {
  WeComTunnelManager({
    TunnelProcessRunner? processRunner,
    RuntimeDirectoryProvider? runtimeDirectoryProvider,
    this.onTunnelReady,
  }) : _processRunner = processRunner ?? const IoTunnelProcessRunner(),
       _runtimeDirectoryProvider =
           runtimeDirectoryProvider ?? _defaultRuntimeDirectoryProvider;

  final TunnelProcessRunner _processRunner;
  final RuntimeDirectoryProvider _runtimeDirectoryProvider;
  final TunnelUrlPersistor? onTunnelReady;

  final ValueNotifier<TunnelStatus> status = ValueNotifier<TunnelStatus>(
    TunnelStatus.disconnected,
  );

  ManagedProcess? _activeProcess;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  static final _urlRegex = RegExp(r'https?://[^\s]+');

  Future<void> start({
    required int localPort,
    required String callbackPath,
  }) async {
    if (_activeProcess != null) {
      return;
    }

    _setStatus(
      const TunnelStatus(
        state: TunnelConnectionState.preparing,
        message: '准备隧道运行环境…',
      ),
    );

    final runtimeDir = await _runtimeDirectoryProvider();
    await runtimeDir.create(recursive: true);
    await _ensureRuntime(runtimeDir);

    _setStatus(
      const TunnelStatus(
        state: TunnelConnectionState.connecting,
        message: '正在建立公网隧道连接…',
      ),
    );

    final nodeExecutable = _resolveNodeExecutable(runtimeDir.path);
    final ltCliPath = _resolveLtCliPath(runtimeDir.path);

    _activeProcess = await _processRunner.start(nodeExecutable, <String>[
      ltCliPath,
      '--port',
      '$localPort',
    ], workingDirectory: runtimeDir.path);

    _stdoutSub = _activeProcess!.stdoutLines.listen(
      (line) => _onProcessLine(line, callbackPath),
    );
    _stderrSub = _activeProcess!.stderrLines.listen(
      (line) => _onProcessLine(line, callbackPath),
    );

    _activeProcess!.exitCode.then((code) {
      _clearProcessHandles();
      if (status.value.state == TunnelConnectionState.disconnected) {
        return;
      }

      if (code == 0) {
        _setStatus(
          const TunnelStatus(
            state: TunnelConnectionState.disconnected,
            message: '隧道已断开。',
          ),
        );
      } else {
        _setStatus(
          TunnelStatus(
            state: TunnelConnectionState.error,
            message: '隧道进程异常退出（code=$code）。',
          ),
        );
      }
    });
  }

  Future<void> stop() async {
    final process = _activeProcess;
    if (process == null) {
      _setStatus(
        status.value.copyWith(
          state: TunnelConnectionState.disconnected,
          message: '隧道未运行。',
        ),
      );
      return;
    }

    await process.kill();
    _clearProcessHandles();
    _setStatus(
      status.value.copyWith(
        state: TunnelConnectionState.disconnected,
        message: '隧道已断开。',
      ),
    );
  }

  Future<void> dispose() async {
    await stop();
    status.dispose();
  }

  void _onProcessLine(String line, String callbackPath) {
    final match = _urlRegex.firstMatch(line);
    if (match == null) {
      return;
    }

    final publicBaseUrl = match.group(0)!;
    final callbackUrl = _joinUrl(publicBaseUrl, callbackPath);

    if (status.value.publicBaseUrl == publicBaseUrl &&
        status.value.callbackUrl == callbackUrl &&
        status.value.state == TunnelConnectionState.connected) {
      return;
    }

    _setStatus(
      TunnelStatus(
        state: TunnelConnectionState.connected,
        publicBaseUrl: publicBaseUrl,
        callbackUrl: callbackUrl,
        message: '隧道连接成功。',
      ),
    );

    final callback = onTunnelReady;
    if (callback != null) {
      callback(publicBaseUrl, callbackUrl).catchError((Object err) {
        _setStatus(
          status.value.copyWith(
            state: TunnelConnectionState.error,
            message: '隧道已连通，但配置写入失败：$err',
          ),
        );
      });
    }
  }

  Future<void> _ensureRuntime(Directory runtimeDir) async {
    final packageJson = File(_joinPath(runtimeDir.path, 'package.json'));
    if (!await packageJson.exists()) {
      await packageJson.writeAsString(_packageJsonTemplate);
    }

    final packageLock = File(_joinPath(runtimeDir.path, 'package-lock.json'));
    if (!await packageLock.exists()) {
      await packageLock.writeAsString('{}');
    }

    final ltCliPath = _resolveLtCliPath(runtimeDir.path);
    final hasLocalTunnel = await File(ltCliPath).exists();
    if (hasLocalTunnel) {
      return;
    }

    final result = await _processRunner.run(
      _resolveNpmExecutable(runtimeDir.path),
      const <String>['install', '--no-audit', '--no-fund'],
      workingDirectory: runtimeDir.path,
    );

    if (result.exitCode != 0) {
      throw Exception(
        '初始化本地隧道依赖失败: '
        '${result.stderr.isNotEmpty ? result.stderr : result.stdout}',
      );
    }
  }

  String _resolveNodeExecutable(String runtimeDirPath) {
    final embeddedNode = Platform.isWindows
        ? _joinPath(runtimeDirPath, 'node', 'node.exe')
        : _joinPath(runtimeDirPath, 'node', 'bin', 'node');
    if (File(embeddedNode).existsSync()) {
      return embeddedNode;
    }
    return Platform.isWindows ? 'node.exe' : 'node';
  }

  String _resolveNpmExecutable(String runtimeDirPath) {
    final embeddedNpm = Platform.isWindows
        ? _joinPath(runtimeDirPath, 'node', 'npm.cmd')
        : _joinPath(runtimeDirPath, 'node', 'bin', 'npm');
    if (File(embeddedNpm).existsSync()) {
      return embeddedNpm;
    }
    return Platform.isWindows ? 'npm.cmd' : 'npm';
  }

  String _resolveLtCliPath(String runtimeDirPath) {
    return _joinPath(
      runtimeDirPath,
      'node_modules',
      'localtunnel',
      'bin',
      'lt.js',
    );
  }

  String _joinPath(
    String base,
    String segment1, [
    String? segment2,
    String? segment3,
    String? segment4,
  ]) {
    final segments = <String>[base, segment1];
    if (segment2 != null) segments.add(segment2);
    if (segment3 != null) segments.add(segment3);
    if (segment4 != null) segments.add(segment4);
    return segments.join(Platform.pathSeparator);
  }

  String _joinUrl(String baseUrl, String callbackPath) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = callbackPath.startsWith('/')
        ? callbackPath
        : '/$callbackPath';
    return '$normalizedBase$normalizedPath';
  }

  void _clearProcessHandles() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    _activeProcess = null;
  }

  void _setStatus(TunnelStatus next) {
    status.value = next;
  }

  static Future<Directory> _defaultRuntimeDirectoryProvider() async {
    final appSupport = await getApplicationSupportDirectory();
    return Directory(
      '${appSupport.path}${Platform.pathSeparator}wecom_tunnel_runtime',
    );
  }
}

const String _packageJsonTemplate = '''
{
  "name": "wecom-tunnel-runtime",
  "private": true,
  "version": "1.0.0",
  "description": "Private runtime for WeCom callback tunnel",
  "dependencies": {
    "localtunnel": "^2.0.2"
  }
}
''';
