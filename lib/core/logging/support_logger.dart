import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Lightweight runtime logger for support/debugging.
///
/// Log file location:
/// - macOS/Linux: ~/.tg_ai_sales_desktop/logs/runtime.log
/// - Windows: %USERPROFILE%\\.tg_ai_sales_desktop\\logs\\runtime.log
class SupportLogger {
  SupportLogger._();

  static String _homeDir() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) {
      return Directory.current.path;
    }
    return home;
  }

  static String _logsDir() =>
      p.join(_homeDir(), '.tg_ai_sales_desktop', 'logs');

  static String _runtimeLogPath() => p.join(_logsDir(), 'runtime.log');

  static Future<void> _ensureDir() async {
    final dir = Directory(_logsDir());
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  static Future<void> log(
    String tag,
    String message, {
    Map<String, dynamic>? extra,
  }) async {
    try {
      await _ensureDir();
      final line = jsonEncode({
        'ts': DateTime.now().toIso8601String(),
        'tag': tag,
        'message': message,
        if (extra != null) 'extra': extra,
      });
      final file = File(_runtimeLogPath());
      await file.writeAsString('$line\n', mode: FileMode.append, flush: false);
    } catch (_) {
      // do not break business flow for logging failure
    }
  }

  static Future<File?> exportRecentToDesktop({int maxLines = 800}) async {
    try {
      final src = File(_runtimeLogPath());
      if (!await src.exists()) return null;

      final lines = await src.readAsLines();
      final recent = lines.length <= maxLines
          ? lines
          : lines.sublist(lines.length - maxLines);

      final desktop = Directory(p.join(_homeDir(), 'Desktop'));
      if (!await desktop.exists()) {
        await desktop.create(recursive: true);
      }

      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final out = File(p.join(desktop.path, 'tg_ai_recent_logs_$stamp.log'));
      await out.writeAsString(recent.join('\n'));
      return out;
    } catch (_) {
      return null;
    }
  }

  static Future<String> currentLogPath() async {
    await _ensureDir();
    return _runtimeLogPath();
  }
}
