class QaCheckResult {
  const QaCheckResult({
    required this.pass,
    required this.blockReasons,
    required this.warnReasons,
    required this.normalizedText,
  });

  final bool pass;
  final List<String> blockReasons;
  final List<String> warnReasons;
  final String normalizedText;
}

class MessageQaService {
  const MessageQaService({
    this.blockKeywords = const ['保证收益', '100%成交', '包过', '包赚', '稳赚不赔'],
    this.warnKeywords = const ['退款', '投诉', '举报', '合同', '违约'],
  });

  final List<String> blockKeywords;
  final List<String> warnKeywords;

  QaCheckResult evaluate({
    required String text,
    required String conversationId,
    required String peerId,
  }) {
    final block = <String>[];
    final warn = <String>[];

    final normalized = _normalize(text);

    if (conversationId.trim().isEmpty || peerId.trim().isEmpty) {
      block.add('会话ID或目标客户ID为空，禁止发送');
    }

    for (final k in blockKeywords) {
      if (_normalize(k).isNotEmpty && normalized.contains(_normalize(k))) {
        block.add('命中禁止词: $k');
      }
    }
    for (final k in warnKeywords) {
      if (_normalize(k).isNotEmpty && normalized.contains(_normalize(k))) {
        warn.add('命中风险词: $k');
      }
    }

    final hardPatterns = [
      RegExp(r'100\s*%\s*(成交|包过|保证|成功)'),
      RegExp(r'保(证|底).{0,8}(收益|回本|赚钱)'),
    ];
    for (final p in hardPatterns) {
      if (p.hasMatch(normalized)) {
        block.add('命中高风险承诺模式: ${p.pattern}');
      }
    }

    if (normalized.trim().isEmpty) {
      block.add('内容为空');
    }

    return QaCheckResult(
      pass: block.isEmpty,
      blockReasons: block,
      warnReasons: warn,
      normalizedText: normalized,
    );
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('％', '%')
        .replaceAll('。', '.')
        .replaceAll('，', ',')
        .trim();
  }
}
