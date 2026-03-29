import '../../../core/models/conversation.dart';
import '../../../core/models/message.dart';

class GoalEngineResult {
  const GoalEngineResult({
    required this.stage,
    required this.score,
    required this.suggestion,
  });

  final String stage;
  final double score;
  final String suggestion;
}

class GoalEngineService {
  const GoalEngineService();

  GoalEngineResult evaluate({
    required Conversation conversation,
    required List<Message> messages,
  }) {
    final customerMessages = messages
        .where((m) => m.role == 'customer')
        .toList();
    final latest = customerMessages.isEmpty
        ? null
        : customerMessages.last.content;

    if (latest == null || latest.isEmpty) {
      return const GoalEngineResult(
        stage: 'discover',
        score: 0.2,
        suggestion: '先收集客户需求与预算',
      );
    }

    if (latest.contains('价格') || latest.contains('优惠')) {
      return const GoalEngineResult(
        stage: 'proposal',
        score: 0.65,
        suggestion: '进入报价阶段，给出方案对比',
      );
    }

    if (latest.contains('合同') || latest.contains('付款')) {
      return const GoalEngineResult(
        stage: 'closing',
        score: 0.85,
        suggestion: '推进成交与风控确认',
      );
    }

    return GoalEngineResult(
      stage: conversation.goalStage,
      score: 0.45,
      suggestion: '维持当前跟进节奏，继续挖掘需求痛点',
    );
  }
}
