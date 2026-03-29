import 'dart:math';

/// 把一条AI回复拆成多条自然消息，模拟真人发消息的节奏
class SplitMessage {
  const SplitMessage({required this.text, required this.delayMs});
  final String text;
  final int delayMs; // 发送前等待的毫秒数
}

class MessageSplitter {
  const MessageSplitter();

  static final _random = Random();

  /// 拆分消息
  /// - 只有AI主动用\n分成多句的才拆
  /// - 普通单句不拆，不要显得神经
  /// - 每条之间加1-4秒随机延迟模拟打字
  List<SplitMessage> split(String text) {
    if (text.trim().isEmpty) return const [];

    List<String> parts;

    // 只有包含\n才拆（AI在system prompt里被要求用\n分多条）
    if (text.contains('\n')) {
      parts = text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      // 不包含\n的一律不拆，直接发
      parts = [text.trim()];
    }

    // 如果拆出来超过5条，合并一些
    if (parts.length > 5) {
      parts = _mergeParts(parts, 5);
    }

    // 给每条消息加随机延迟
    final result = <SplitMessage>[];
    for (int i = 0; i < parts.length; i++) {
      final delay = i == 0
          ? 0 // 第一条不延迟（外层cadence已经控制了整体延迟）
          : _naturalDelay();
      result.add(SplitMessage(text: parts[i], delayMs: delay));
    }

    return result;
  }

  List<String> _mergeParts(List<String> parts, int maxParts) {
    if (parts.length <= maxParts) return parts;
    final result = <String>[];
    final chunkSize = (parts.length / maxParts).ceil();
    for (int i = 0; i < parts.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, parts.length);
      result.add(parts.sublist(i, end).join('，'));
    }
    return result;
  }

  /// 自然延迟：1-4秒之间，模拟打字速度
  int _naturalDelay() {
    return 1000 + _random.nextInt(3000);
  }
}
