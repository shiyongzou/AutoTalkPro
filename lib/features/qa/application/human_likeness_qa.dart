/// AI味道检测 + 话术合适度审核
///
/// 检查AI生成的回复是否像真人说的，是否适合当前语境。
/// 不通过则要求重新生成。
class HumanLikenessQaResult {
  const HumanLikenessQaResult({
    required this.pass,
    required this.score,
    required this.issues,
  });

  final bool pass;
  final double score; // 0.0(纯AI) ~ 1.0(像真人)
  final List<String> issues;
}

class HumanLikenessQa {
  const HumanLikenessQa();

  // AI味道特征词
  static const List<String> _aiPatterns = [
    '您好',
    '请问',
    '非常感谢',
    '如果您需要',
    '如果您有任何',
    '请随时联系',
    '我很乐意',
    '希望能帮到您',
    '祝您',
    '感谢您的信任',
    '我将为您',
    '为您提供',
    '竭诚为您',
    '期待与您',
    '如有疑问',
    '不胜感激',
    '此致',
    '敬上',
  ];

  // 客服体特征
  static const List<String> _servicePatterns = [
    '好的呢',
    '收到哦',
    '亲亲',
    '亲，',
    '小主',
    '宝子',
    '么么哒',
    '感谢您的耐心',
    '给您带来不便',
    '温馨提示',
  ];

  // 模板感特征（过于结构化）
  static const List<String> _templatePatterns = [
    '第一，',
    '第二，',
    '首先，',
    '其次，',
    '最后，',
    '总结：',
    '综上所述',
    '以下是',
    '如下：',
    '1.',
    '2.',
    '3.',
  ];

  // 不合适的回复模式
  static const List<String> _inappropriatePatterns = [
    '作为AI',
    '作为人工智能',
    '我是AI',
    '我是机器人',
    '我没有感情',
    '我无法',
    '根据我的训练数据',
    '我的知识截止',
  ];

  // 波浪号滥用
  static final RegExp _wavyPattern = RegExp(r'[~～]{2,}|[~～].*[~～]');

  // 感叹号滥用
  static final RegExp _exclamationPattern = RegExp(r'[!！]{2,}');

  // 消息过长（真人微信聊天很少超过100字）
  static const int _maxNaturalLength = 120;

  HumanLikenessQaResult evaluate(String text) {
    final issues = <String>[];
    double penalty = 0;

    // 1. AI味道检测
    for (final p in _aiPatterns) {
      if (text.contains(p)) {
        issues.add('AI腔: "$p"');
        penalty += 0.15;
      }
    }

    // 2. 客服体检测
    for (final p in _servicePatterns) {
      if (text.contains(p)) {
        issues.add('客服体: "$p"');
        penalty += 0.12;
      }
    }

    // 3. 模板感检测
    int templateHits = 0;
    for (final p in _templatePatterns) {
      if (text.contains(p)) {
        templateHits++;
      }
    }
    if (templateHits >= 2) {
      issues.add('模板感太强（$templateHits个结构化标记）');
      penalty += 0.2;
    }

    // 4. 暴露AI身份
    for (final p in _inappropriatePatterns) {
      if (text.contains(p)) {
        issues.add('暴露AI身份: "$p"');
        penalty += 0.5; // 严重
      }
    }

    // 5. 波浪号滥用
    if (_wavyPattern.hasMatch(text)) {
      issues.add('波浪号过多，太做作');
      penalty += 0.1;
    }

    // 6. 感叹号滥用
    if (_exclamationPattern.hasMatch(text)) {
      issues.add('感叹号过多');
      penalty += 0.08;
    }

    // 7. 消息过长
    if (text.length > _maxNaturalLength) {
      issues.add('消息太长(${text.length}字)，真人很少发这么长');
      penalty += 0.1;
    }

    // 8. emoji滥用（超过2个）
    final emojiCount = RegExp(
      r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
      unicode: true,
    ).allMatches(text).length;
    if (emojiCount > 2) {
      issues.add('emoji太多($emojiCount个)');
      penalty += 0.08;
    }

    final score = (1.0 - penalty).clamp(0.0, 1.0);
    return HumanLikenessQaResult(
      pass: score >= 0.6, // 60分以上才通过
      score: score,
      issues: issues,
    );
  }
}
