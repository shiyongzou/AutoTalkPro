import 'dart:io';

import 'package:path/path.dart' as p;

/// 运行时环境引导器
///
/// 首次启动时自动下载完整 Node.js（含npm） + npm install 依赖，
/// 缓存到 ~/Library/Application Support/AutoTalk Pro/services/
/// 用户无需安装任何环境。
class ServiceBootstrapper {
  ServiceBootstrapper._();
  static final instance = ServiceBootstrapper._();

  static const _nodeVersion = 'v22.16.0';

  /// 缓存根目录
  static String get _cacheRoot {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Directory.current.path;
      return p.join(home, 'Library', 'Application Support', 'AutoTalk Pro', 'services');
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ??
          Platform.environment['USERPROFILE'] ??
          r'C:\Users\Public';
      return p.join(appData, 'AutoTalk Pro', 'services');
    } else {
      final home = Platform.environment['HOME'] ?? Directory.current.path;
      return p.join(home, '.autotalk-pro', 'services');
    }
  }

  /// Node安装根目录（完整解压，含bin/lib/npm）
  static String get _nodeRoot => p.join(_cacheRoot, 'node');

  /// Node二进制路径
  static String get nodePath {
    if (Platform.isWindows) {
      return p.join(_nodeRoot, 'node.exe');
    }
    return p.join(_nodeRoot, 'bin', 'node');
  }

  /// npm可执行路径（Node包自带）
  static String get npmPath {
    if (Platform.isWindows) {
      return p.join(_nodeRoot, 'npm.cmd');
    }
    return p.join(_nodeRoot, 'bin', 'npm');
  }

  /// npx可执行路径
  static String get npxPath {
    if (Platform.isWindows) {
      return p.join(_nodeRoot, 'npx.cmd');
    }
    return p.join(_nodeRoot, 'bin', 'npx');
  }

  /// 服务目录（缓存位置）
  static String serviceDir(String serviceName) =>
      p.join(_cacheRoot, serviceName);

  /// wechat_service入口
  static String get wechatEntryPath =>
      p.join(serviceDir('wechat_service'), 'node_modules', 'wechatbot-webhook', 'index.js');

  /// telegram_service入口
  static String get telegramEntryPath =>
      p.join(serviceDir('telegram_service'), 'server.js');

  /// Node是否已下载（检查node二进制和npm都存在）
  bool get isNodeReady =>
      File(nodePath).existsSync() && File(npmPath).existsSync();

  /// 某个服务的依赖是否已安装
  bool isServiceReady(String serviceName) {
    final dir = serviceDir(serviceName);
    return Directory(p.join(dir, 'node_modules')).existsSync();
  }

  /// 全部就绪？
  bool get isAllReady =>
      isNodeReady &&
      isServiceReady('wechat_service') &&
      isServiceReady('telegram_service');

  /// 引导全部环境（带进度回调）
  Future<({bool ok, String message})> bootstrap({
    void Function(String status)? onProgress,
  }) async {
    try {
      final root = Directory(_cacheRoot);
      if (!root.existsSync()) root.createSync(recursive: true);

      // 1. 下载 Node.js（含npm）
      if (!isNodeReady) {
        onProgress?.call('正在下载 Node.js 运行环境（首次约60MB）...');
        final result = await _downloadNode(onProgress: onProgress);
        if (!result.ok) return result;
      } else {
        onProgress?.call('Node.js 已就绪');
      }

      // 2. 安装 wechat_service 依赖
      if (!isServiceReady('wechat_service')) {
        onProgress?.call('正在安装微信服务依赖...');
        final result = await _installService('wechat_service');
        if (!result.ok) return result;
      } else {
        onProgress?.call('微信服务依赖已就绪');
      }

      // 3. 安装 telegram_service 依赖
      if (!isServiceReady('telegram_service')) {
        onProgress?.call('正在安装Telegram服务依赖...');
        final result = await _installService('telegram_service');
        if (!result.ok) return result;
      } else {
        onProgress?.call('Telegram服务依赖已就绪');
      }

      onProgress?.call('环境准备完成');
      return (ok: true, message: '环境准备完成');
    } catch (e) {
      return (ok: false, message: '环境准备失败: $e');
    }
  }

  /// 只引导单个服务
  Future<({bool ok, String message})> bootstrapService(
    String serviceName, {
    void Function(String status)? onProgress,
  }) async {
    try {
      final root = Directory(_cacheRoot);
      if (!root.existsSync()) root.createSync(recursive: true);

      if (!isNodeReady) {
        onProgress?.call('正在下载 Node.js 运行环境...');
        final result = await _downloadNode(onProgress: onProgress);
        if (!result.ok) return result;
      }

      if (!isServiceReady(serviceName)) {
        onProgress?.call('正在安装${_serviceDisplayName(serviceName)}依赖...');
        final result = await _installService(serviceName);
        if (!result.ok) return result;
      }

      return (ok: true, message: '${_serviceDisplayName(serviceName)}环境已就绪');
    } catch (e) {
      return (ok: false, message: '环境准备失败: $e');
    }
  }

  /// 下载完整 Node.js 包（含node二进制 + npm + npx）
  Future<({bool ok, String message})> _downloadNode({
    void Function(String status)? onProgress,
  }) async {
    final nodeDir = Directory(_nodeRoot);
    if (nodeDir.existsSync()) nodeDir.deleteSync(recursive: true);
    nodeDir.createSync(recursive: true);

    final arch = _getArch();
    String url;
    bool isZip;

    if (Platform.isMacOS) {
      url = 'https://nodejs.org/dist/$_nodeVersion/node-$_nodeVersion-darwin-$arch.tar.gz';
      isZip = false;
    } else if (Platform.isWindows) {
      url = 'https://nodejs.org/dist/$_nodeVersion/node-$_nodeVersion-win-x64.zip';
      isZip = true;
    } else {
      url = 'https://nodejs.org/dist/$_nodeVersion/node-$_nodeVersion-linux-$arch.tar.gz';
      isZip = false;
    }

    final tmpFile = File(p.join(_cacheRoot, isZip ? 'node_dl.zip' : 'node_dl.tar.gz'));

    try {
      // 下载
      onProgress?.call('正在下载 Node.js...');
      final dlResult = await Process.run(
        'curl',
        ['-fSL', '--progress-bar', '-o', tmpFile.path, url],
        environment: Platform.environment,
      );
      if (dlResult.exitCode != 0) {
        return (ok: false, message: 'Node.js下载失败，请检查网络连接');
      }

      // 解压完整包到临时位置
      onProgress?.call('正在解压 Node.js...');
      final tmpExtract = Directory(p.join(_cacheRoot, '_node_extract'));
      if (tmpExtract.existsSync()) tmpExtract.deleteSync(recursive: true);
      tmpExtract.createSync();

      if (!isZip) {
        final result = await Process.run(
          'tar',
          ['-xzf', tmpFile.path, '-C', tmpExtract.path],
        );
        if (result.exitCode != 0) {
          return (ok: false, message: 'Node.js解压失败: ${result.stderr}');
        }

        // tar解压后目录名如 node-v22.16.0-darwin-arm64
        final platform = Platform.isMacOS ? 'darwin' : 'linux';
        final extractedName = 'node-$_nodeVersion-$platform-$arch';
        final extractedDir = Directory(p.join(tmpExtract.path, extractedName));

        if (!extractedDir.existsSync()) {
          return (ok: false, message: 'Node.js解压异常，未找到目录 $extractedName');
        }

        // 移动到目标位置
        if (nodeDir.existsSync()) nodeDir.deleteSync(recursive: true);
        await _moveDirectory(extractedDir.path, nodeDir.path);
      } else {
        // Windows zip
        await Process.run('powershell', [
          '-Command',
          'Expand-Archive -Path "${tmpFile.path}" -DestinationPath "${tmpExtract.path}" -Force',
        ], runInShell: true);

        final extractedName = 'node-$_nodeVersion-win-x64';
        final extractedDir = Directory(p.join(tmpExtract.path, extractedName));
        if (extractedDir.existsSync()) {
          if (nodeDir.existsSync()) nodeDir.deleteSync(recursive: true);
          await _moveDirectory(extractedDir.path, nodeDir.path);
        }
      }

      // 清理临时文件
      if (tmpFile.existsSync()) tmpFile.deleteSync();
      if (tmpExtract.existsSync()) {
        try { tmpExtract.deleteSync(recursive: true); } catch (_) {}
      }

      // 验证
      if (!File(nodePath).existsSync()) {
        return (ok: false, message: 'Node.js安装失败，node二进制不存在');
      }
      if (!File(npmPath).existsSync()) {
        return (ok: false, message: 'Node.js安装失败，npm不存在');
      }

      // 确保可执行（macOS/Linux）
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', nodePath]);
        await Process.run('chmod', ['+x', npmPath]);
        await Process.run('chmod', ['+x', npxPath]);
      }

      return (ok: true, message: 'Node.js 安装完成');
    } catch (e) {
      if (tmpFile.existsSync()) tmpFile.deleteSync();
      return (ok: false, message: 'Node.js下载失败: $e');
    }
  }

  /// 安装服务依赖（从bundle复制配置文件 + npm install）
  Future<({bool ok, String message})> _installService(String serviceName) async {
    final targetDir = Directory(serviceDir(serviceName));
    if (!targetDir.existsSync()) targetDir.createSync(recursive: true);

    // 从app bundle复制 package.json 和 server.js 等源文件
    final bundleDir = _bundledSeedDir(serviceName);
    await _copySeedFiles(bundleDir, targetDir.path);

    // 确认 package.json 存在
    if (!File(p.join(targetDir.path, 'package.json')).existsSync()) {
      return (ok: false, message: '${_serviceDisplayName(serviceName)}的package.json缺失');
    }

    // 用自带的npm安装依赖
    // Windows: 直接运行 npm.cmd（它是批处理脚本，不能被node执行）
    // macOS/Linux: 用 node 运行 npm-cli.js
    final String npmExe;
    final List<String> npmArgs;
    if (Platform.isWindows) {
      npmExe = npmPath; // npm.cmd
      npmArgs = ['install', '--production', '--no-fund', '--no-audit'];
    } else {
      // macOS/Linux: npm是个shell脚本，直接执行
      npmExe = npmPath; // bin/npm
      npmArgs = ['install', '--production', '--no-fund', '--no-audit'];
    }

    final pathSep = Platform.isWindows ? ';' : ':';
    final result = await Process.run(
      npmExe,
      npmArgs,
      workingDirectory: targetDir.path,
      runInShell: Platform.isWindows, // Windows上npm.cmd需要shell执行
      environment: {
        ...Platform.environment,
        'PATH': '${p.dirname(nodePath)}$pathSep${Platform.environment['PATH'] ?? ''}',
      },
    );

    if (result.exitCode != 0) {
      return (ok: false, message: '依赖安装失败: ${result.stderr}');
    }

    return (ok: true, message: '${_serviceDisplayName(serviceName)}依赖安装完成');
  }

  /// 从bundle目录复制种子文件（package.json, server.js等，不复制node_modules和node）
  Future<void> _copySeedFiles(String srcDir, String destDir) async {
    final src = Directory(srcDir);
    if (!src.existsSync()) return;

    await for (final entity in src.list()) {
      final name = p.basename(entity.path);
      // 跳过大文件
      if (name == 'node_modules' || name == 'node' || name == 'node.exe') continue;
      if (name == 'package-lock.json') continue;

      if (entity is File) {
        final dest = File(p.join(destDir, name));
        // 总是覆盖，确保跟bundle版本一致
        entity.copySync(dest.path);
      }
    }
  }

  /// 移动目录（rename 可能跨分区失败，用 Dart API 复制兜底）
  Future<void> _moveDirectory(String src, String dest) async {
    try {
      Directory(src).renameSync(dest);
    } catch (_) {
      // rename 失败（跨分区），用纯 Dart 递归复制
      await _copyDirectoryRecursive(Directory(src), Directory(dest));
      Directory(src).deleteSync(recursive: true);
    }
  }

  /// 纯 Dart 递归复制目录（跨平台，不依赖 shell 命令）
  Future<void> _copyDirectoryRecursive(Directory src, Directory dest) async {
    if (!dest.existsSync()) dest.createSync(recursive: true);
    await for (final entity in src.list()) {
      final newPath = p.join(dest.path, p.basename(entity.path));
      if (entity is File) {
        entity.copySync(newPath);
      } else if (entity is Directory) {
        await _copyDirectoryRecursive(entity, Directory(newPath));
      }
    }
  }

  /// 获取CPU架构
  String _getArch() {
    // Windows 目前只提供 x64 Node.js 下载
    if (Platform.isWindows) return 'x64';
    try {
      final result = Process.runSync('uname', ['-m']);
      final arch = result.stdout.toString().trim();
      if (arch == 'arm64' || arch == 'aarch64') return 'arm64';
      return 'x64';
    } catch (_) {
      return 'x64';
    }
  }

  /// app bundle内的种子文件目录
  static String _bundledSeedDir(String serviceName) {
    final executable = Platform.resolvedExecutable;
    if (Platform.isMacOS) {
      final contentsDir = p.dirname(p.dirname(executable));
      return p.join(contentsDir, 'Resources', serviceName);
    } else {
      return p.join(p.dirname(executable), 'data', serviceName);
    }
  }

  String _serviceDisplayName(String serviceName) {
    switch (serviceName) {
      case 'wechat_service': return '微信服务';
      case 'telegram_service': return 'Telegram服务';
      default: return serviceName;
    }
  }

  /// 清除所有缓存（重新下载）
  Future<void> clearCache() async {
    final root = Directory(_cacheRoot);
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }
}
