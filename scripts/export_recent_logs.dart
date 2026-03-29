import 'dart:io';

import 'package:tg_ai_sales_desktop/core/logging/support_logger.dart';

Future<void> main(List<String> args) async {
  final maxLines = args.isNotEmpty ? int.tryParse(args.first) ?? 800 : 800;
  final out = await SupportLogger.exportRecentToDesktop(maxLines: maxLines);
  if (out == null) {
    final path = await SupportLogger.currentLogPath();
    stdout.writeln('No runtime logs yet. currentLogPath=$path');
    return;
  }
  stdout.writeln('Exported: ${out.path}');
}
