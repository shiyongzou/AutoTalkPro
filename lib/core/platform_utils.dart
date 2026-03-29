import 'dart:io';

import 'package:path/path.dart' as p;

import 'service_bootstrapper.dart';

/// 跨平台工具
class PlatformUtils {
  /// 杀掉占用指定端口的进程
  static Future<void> killPort(int port) async {
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final result = await Process.run('lsof', ['-ti:$port', '-sTCP:LISTEN']);
        final pids = result.stdout.toString().trim();
        for (final pid in pids.split('\n')) {
          if (pid.trim().isNotEmpty) {
            await Process.run('kill', ['-9', pid.trim()]);
          }
        }
      } else if (Platform.isWindows) {
        final result = await Process.run('netstat', ['-ano'], runInShell: true);
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.contains(':$port') && line.contains('LISTENING')) {
            final parts = line.trim().split(RegExp(r'\s+'));
            final pid = parts.last;
            if (pid.isNotEmpty && int.tryParse(pid) != null) {
              await Process.run('taskkill', [
                '/F',
                '/PID',
                pid,
              ], runInShell: true);
            }
          }
        }
      }
    } catch (_) {}
  }

  /// 获取临时文件路径（跨平台）
  static String tempFilePath(String name) {
    if (Platform.isWindows) {
      return p.join(Platform.environment['TEMP'] ?? r'C:\Temp', name);
    }
    return p.join('/tmp', name);
  }

  /// 获取app bundle内的种子文件目录（只含 package.json / server.js 等小文件）
  static String bundledServiceDir(String serviceName) {
    final executable = Platform.resolvedExecutable;
    if (Platform.isMacOS) {
      final contentsDir = p.dirname(p.dirname(executable));
      return p.join(contentsDir, 'Resources', serviceName);
    } else {
      return p.join(p.dirname(executable), 'data', serviceName);
    }
  }

  /// 获取运行时 Node 二进制路径（从缓存目录）
  static String bundledNodePath() => ServiceBootstrapper.nodePath;

  /// 获取运行时服务目录（从缓存目录，含 node_modules）
  static String cachedServiceDir(String serviceName) =>
      ServiceBootstrapper.serviceDir(serviceName);

  /// 打开URL
  static Future<void> openUrl(String url) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('start', [url], runInShell: true);
      }
    } catch (_) {}
  }
}
