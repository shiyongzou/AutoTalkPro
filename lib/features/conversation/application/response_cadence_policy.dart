import '../../../core/models/message.dart';
import 'intent_classifier_service.dart';

enum CadenceAction { draftNow, suggestDelay, suggestSkip }

class ConversationStrategyWeights {
  const ConversationStrategyWeights({
    this.relationshipMaintenance = 0.78,
    this.smallTalk = 0.46,
    this.businessPromotion = 0.9,
  });

  final double relationshipMaintenance;
  final double smallTalk;
  final double businessPromotion;
}

class CadenceControlParameters {
  const CadenceControlParameters({
    this.riskQuickDelay = const Duration(seconds: 20),
    this.businessNaturalPause = const Duration(minutes: 3),
    this.relationshipDelay = const Duration(minutes: 8),
    this.smallTalkWithBusinessDelay = const Duration(minutes: 10),
    this.activeConversationWindow = const Duration(minutes: 25),
  });

  final Duration riskQuickDelay;
  final Duration businessNaturalPause;
  final Duration relationshipDelay;
  final Duration smallTalkWithBusinessDelay;
  final Duration activeConversationWindow;
}

class CadenceDecision {
  const CadenceDecision({
    required this.action,
    required this.reason,
    required this.strategyWeight,
    required this.rhythmHint,
    this.suggestedDelay,
  });

  final CadenceAction action;
  final String reason;
  final Duration? suggestedDelay;
  final double strategyWeight;
  final String rhythmHint;
}

class ResponseCadencePolicy {
  const ResponseCadencePolicy({
    this.strategyWeights = const ConversationStrategyWeights(),
    this.controlParameters = const CadenceControlParameters(),
  });

  final ConversationStrategyWeights strategyWeights;
  final CadenceControlParameters controlParameters;

  static const Set<String> _lowValueTokens = {
    '嗯',
    '好的',
    '收到',
    'ok',
    '哈哈',
    '哦',
    '1',
    '嗯嗯',
    '行',
  };

  static const List<String> _businessContextKeywords = [
    '价格',
    '报价',
    '套餐',
    '下单',
    '购买',
    '合同',
    '付款',
    '折扣',
    '开通',
    '试用',
    '发票',
    '交付',
    '多少钱',
    '怎么卖',
  ];

  static const List<String> _urgentBuySignals = [
    '下单',
    '付款',
    '怎么付',
    '转账',
    '买',
    '要了',
    '签',
    '合同',
    '打款',
    '付了',
    '成交',
  ];

  CadenceDecision evaluate({
    required IntentClassification classification,
    required List<Message> messages,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final latestCustomer = _latestCustomerMessage(messages);
    final latest = latestCustomer?.content.trim().toLowerCase() ?? '';
    final active =
        latestCustomer != null &&
        currentTime.difference(latestCustomer.sentAt) <=
            controlParameters.activeConversationWindow;

    switch (classification.intent) {
      case ConversationIntent.riskComplaint:
        return CadenceDecision(
          action: CadenceAction.suggestDelay,
          suggestedDelay: controlParameters.riskQuickDelay,
          reason: '风险信号，快速跟进并给出处理动作。',
          strategyWeight: 1,
          rhythmHint: '先安抚，再明确解决路径。',
        );

      case ConversationIntent.businessPromotion:
        final hasDirectQuestion =
            latest.contains('?') ||
            latest.contains('？') ||
            latest.contains('怎么') ||
            latest.contains('多少') ||
            latest.contains('可以吗');
        if (hasDirectQuestion) {
          return CadenceDecision(
            action: CadenceAction.draftNow,
            reason: '客户在直接询问关键信息，建议立即出草稿。',
            strategyWeight: strategyWeights.businessPromotion,
            rhythmHint: '先答核心问题，再轻推进下一步。',
          );
        }

        final hasUrgentSignal = _urgentBuySignals.any(latest.contains);
        if (hasUrgentSignal) {
          return CadenceDecision(
            action: CadenceAction.suggestDelay,
            suggestedDelay: controlParameters.businessNaturalPause,
            reason: '客户有推进成交意图，稍作停顿后跟进。',
            strategyWeight: strategyWeights.businessPromotion,
            rhythmHint: '确认意向并轻推进成交动作。',
          );
        }

        final delay = active
            ? controlParameters.businessNaturalPause
            : controlParameters.businessNaturalPause;
        return CadenceDecision(
          action: CadenceAction.suggestDelay,
          suggestedDelay: delay,
          reason: '业务跟进保持自然节奏，避免打断感。',
          strategyWeight: strategyWeights.businessPromotion,
          rhythmHint: '保持轻推进，不催促。',
        );

      case ConversationIntent.relationshipMaintenance:
        return CadenceDecision(
          action: CadenceAction.suggestDelay,
          suggestedDelay: controlParameters.relationshipDelay,
          reason: '关系维护以舒适节奏回应，避免压迫感。',
          strategyWeight: strategyWeights.relationshipMaintenance,
          rhythmHint: '温和回应并保持连接。',
        );

      case ConversationIntent.smallTalk:
        final hasBusinessContext = _hasRecentBusinessContext(messages);

        if (_isLowValuePing(latest) && !hasBusinessContext) {
          return CadenceDecision(
            action: CadenceAction.suggestSkip,
            reason: '低价值闲聊且无业务上下文，建议跳过。',
            strategyWeight: strategyWeights.smallTalk,
            rhythmHint: '不主动展开闲聊。',
          );
        }

        if (hasBusinessContext) {
          return CadenceDecision(
            action: CadenceAction.suggestDelay,
            suggestedDelay: controlParameters.smallTalkWithBusinessDelay,
            reason: '检测到业务上下文，先接住闲聊再回到业务。',
            strategyWeight: strategyWeights.smallTalk,
            rhythmHint: '先接住闲聊，再轻推回业务节点。',
          );
        }

        return CadenceDecision(
          action: CadenceAction.suggestDelay,
          suggestedDelay: controlParameters.businessNaturalPause,
          reason: '普通闲聊保持自然回应。',
          strategyWeight: strategyWeights.smallTalk,
          rhythmHint: '简短回应，避免过度延展。',
        );
    }
  }

  Message? _latestCustomerMessage(List<Message> messages) {
    Message? latest;
    for (final message in messages) {
      if (message.role != 'customer') {
        continue;
      }
      if (latest == null || message.sentAt.isAfter(latest.sentAt)) {
        latest = message;
      }
    }
    return latest;
  }

  bool _isLowValuePing(String text) {
    if (text.isEmpty) {
      return true;
    }
    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    if (_lowValueTokens.contains(normalized)) {
      return true;
    }
    if (normalized.length <= 2 &&
        !normalized.contains('?') &&
        !normalized.contains('？')) {
      return true;
    }
    if (normalized == '在' || normalized == '在么' || normalized == '在吗') {
      return true;
    }
    return false;
  }

  bool _hasRecentBusinessContext(List<Message> messages) {
    final customerMessages = messages
        .where((message) => message.role == 'customer')
        .toList(growable: false);
    if (customerMessages.length < 2) {
      return false;
    }

    final sorted = [...customerMessages]
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

    final lookback = sorted.length >= 4
        ? sorted.sublist(sorted.length - 4, sorted.length - 1)
        : sorted.sublist(0, sorted.length - 1);

    for (final message in lookback) {
      final normalized = message.content.toLowerCase();
      if (_businessContextKeywords.any(normalized.contains)) {
        return true;
      }
    }
    return false;
  }
}
