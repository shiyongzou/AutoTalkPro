import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tg_ai_sales_desktop/features/wecom/application/wecom_tunnel_manager.dart';

class _FakeManagedProcess implements ManagedProcess {
  final StreamController<String> stdoutController =
      StreamController<String>.broadcast();
  final StreamController<String> stderrController =
      StreamController<String>.broadcast();
  final Completer<int> _exitCompleter = Completer<int>();
  bool killed = false;

  @override
  Stream<String> get stdoutLines => stdoutController.stream;

  @override
  Stream<String> get stderrLines => stderrController.stream;

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  Future<void> kill() async {
    killed = true;
    if (!_exitCompleter.isCompleted) {
      _exitCompleter.complete(0);
    }
  }

  void emitStdout(String line) => stdoutController.add(line);

  void completeExit([int code = 0]) {
    if (!_exitCompleter.isCompleted) {
      _exitCompleter.complete(code);
    }
  }
}

class _FakeRunner implements TunnelProcessRunner {
  _FakeRunner(this.process);

  final _FakeManagedProcess process;
  int runCalls = 0;
  int startCalls = 0;

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    runCalls += 1;
    return const CommandResult(exitCode: 0);
  }

  @override
  Future<ManagedProcess> start(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    startCalls += 1;
    return process;
  }
}

Future<Directory> _prepareRuntimeDirectory() async {
  final dir = await Directory.systemTemp.createTemp('wecom_tunnel_test_');
  final ltBin = Directory(
    '${dir.path}${Platform.pathSeparator}node_modules${Platform.pathSeparator}localtunnel${Platform.pathSeparator}bin',
  );
  await ltBin.create(recursive: true);
  await File(
    '${ltBin.path}${Platform.pathSeparator}lt.js',
  ).writeAsString('// fake lt');
  return dir;
}

void main() {
  test('detects public url and builds callback url', () async {
    final process = _FakeManagedProcess();
    final runner = _FakeRunner(process);
    String? savedPublic;
    String? savedCallback;

    final manager = WeComTunnelManager(
      processRunner: runner,
      runtimeDirectoryProvider: _prepareRuntimeDirectory,
      onTunnelReady: (publicBaseUrl, callbackUrl) async {
        savedPublic = publicBaseUrl;
        savedCallback = callbackUrl;
      },
    );

    await manager.start(localPort: 8787, callbackPath: '/wecom/callback');
    process.emitStdout('your url is: https://abc123.loca.lt');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(manager.status.value.state, TunnelConnectionState.connected);
    expect(manager.status.value.publicBaseUrl, 'https://abc123.loca.lt');
    expect(
      manager.status.value.callbackUrl,
      'https://abc123.loca.lt/wecom/callback',
    );
    expect(savedPublic, 'https://abc123.loca.lt');
    expect(savedCallback, 'https://abc123.loca.lt/wecom/callback');

    await manager.dispose();
  });

  test('stop kills process and marks disconnected', () async {
    final process = _FakeManagedProcess();
    final runner = _FakeRunner(process);
    final manager = WeComTunnelManager(
      processRunner: runner,
      runtimeDirectoryProvider: _prepareRuntimeDirectory,
    );

    await manager.start(localPort: 8787, callbackPath: 'wecom/callback');
    await manager.stop();

    expect(process.killed, isTrue);
    expect(manager.status.value.state, TunnelConnectionState.disconnected);

    await manager.dispose();
  });
}
