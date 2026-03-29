import '../../../core/models/escalation_alert.dart';
import '../../../core/models/message.dart';
import '../../../core/models/negotiation_context.dart';
import '../../../core/models/sentiment_record.dart';
import '../domain/escalation_repository.dart';

class EscalationCheckResult {
  const EscalationCheckResult({
    required this.shouldEscalate,
    required this.alerts,
  });

  final bool shouldEscalate;
  final List<EscalationAlert> alerts;
}

class EscalationService {
  const EscalationService({required this.repository});
  final EscalationRepository repository;

  /// 综合评估是否需要人工介入
  Future<EscalationCheckResult> evaluate({
    required String conversationId,
    required String customerId,
    required Message message,
    SentimentRecord? sentiment,
    NegotiationContext? negotiation,
    String? negotiationEscalateReason,
    double aiConfidence = 1.0,
  }) async {
    final alerts = <EscalationAlert>[];
    final now = DateTime.now();

    // 1. 风险关键词检测
    final riskWords = ['投诉', '退款', '举报', '维权', '曝光', '律师', '法院'];
    final hitRisk = riskWords
        .where((w) => message.content.contains(w))
        .toList();
    if (hitRisk.isNotEmpty) {
      alerts.add(
        EscalationAlert(
          id: 'esc_risk_${now.microsecondsSinceEpoch}',
          conversationId: conversationId,
          customerId: customerId,
          reason: EscalationReason.riskDetected,
          priority: EscalationPriority.critical,
          status: EscalationStatus.pending,
          title: '风险告警: 客户提及${hitRisk.join("、")}',
          detail: '客户消息: ${message.content}',
          suggestedAction: '立即人工介入，安抚客户情绪，避免升级',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // 2. 客户情绪异常
    if (sentiment != null &&
        sentiment.sentiment == SentimentType.negative &&
        sentiment.confidence > 0.8) {
      alerts.add(
        EscalationAlert(
          id: 'esc_angry_${now.microsecondsSinceEpoch}',
          conversationId: conversationId,
          customerId: customerId,
          reason: EscalationReason.customerAngry,
          priority: EscalationPriority.high,
          status: EscalationStatus.pending,
          title: '情绪告警: 客户强烈不满(置信度${(sentiment.confidence * 100).toInt()}%)',
          detail:
              '情绪标签: ${sentiment.emotionTags.join("、")}\n异议: ${sentiment.objectionPatterns.join("、")}',
          suggestedAction: '切换为人工对话，优先处理情绪，再解决问题',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // 3. 紧急情绪
    if (sentiment != null && sentiment.isUrgent) {
      alerts.add(
        EscalationAlert(
          id: 'esc_urgent_${now.microsecondsSinceEpoch}',
          conversationId: conversationId,
          customerId: customerId,
          reason: EscalationReason.customerWaitingTooLong,
          priority: EscalationPriority.high,
          status: EscalationStatus.pending,
          title: '紧急告警: 客户表达急迫需求',
          detail: '客户消息: ${message.content}',
          suggestedAction: '立即响应，缩短回复间隔，优先处理',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // 4. 谈判引擎触发的升级
    if (negotiationEscalateReason != null) {
      var reason = EscalationReason.complexNegotiation;
      var priority = EscalationPriority.medium;

      if (negotiationEscalateReason.contains('底价')) {
        reason = EscalationReason.priceFloorBreached;
        priority = EscalationPriority.high;
      } else if (negotiationEscalateReason.contains('审批')) {
        reason = EscalationReason.authorityExceeded;
        priority = EscalationPriority.high;
      } else if (negotiationEscalateReason.contains('让步次数')) {
        reason = EscalationReason.complexNegotiation;
        priority = EscalationPriority.medium;
      }

      alerts.add(
        EscalationAlert(
          id: 'esc_neg_${now.microsecondsSinceEpoch}',
          conversationId: conversationId,
          customerId: customerId,
          reason: reason,
          priority: priority,
          status: EscalationStatus.pending,
          title: '谈判升级: $negotiationEscalateReason',
          detail: negotiation != null
              ? '当前阶段: ${negotiation.stage.name}, 让步: ${negotiation.concessionCount}/${negotiation.maxConcessions}, 成交分: ${(negotiation.dealScore * 100).toInt()}%'
              : negotiationEscalateReason,
          suggestedAction: '人工审核当前报价策略，决定是否继续让步或坚守',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // 5. AI置信度过低
    if (aiConfidence < 0.5) {
      alerts.add(
        EscalationAlert(
          id: 'esc_confidence_${now.microsecondsSinceEpoch}',
          conversationId: conversationId,
          customerId: customerId,
          reason: EscalationReason.aiConfidenceLow,
          priority: EscalationPriority.medium,
          status: EscalationStatus.pending,
          title: 'AI置信度低: ${(aiConfidence * 100).toInt()}%',
          detail: 'AI对当前回复的把握不足，建议人工审核后发送',
          suggestedAction: '人工审核AI生成的回复内容，修改后再发送',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // 6. 高价值成交阶段
    if (negotiation != null &&
        negotiation.stage == NegotiationStage.closing &&
        negotiation.ourOfferPrice != null &&
        negotiation.ourOfferPrice! > 5000) {
      alerts.add(
        EscalationAlert(
          id: 'esc_highval_${now.microsecondsSinceEpoch}',
          conversationId: conversationId,
          customerId: customerId,
          reason: EscalationReason.highValueDeal,
          priority: EscalationPriority.medium,
          status: EscalationStatus.pending,
          title: '高价值成交提醒: ¥${negotiation.ourOfferPrice!.toStringAsFixed(0)}',
          detail: '该单即将成交，金额较大，建议人工确认条款细节',
          suggestedAction: '人工介入确认合同条款、付款方式等关键细节',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // 持久化
    for (final alert in alerts) {
      await repository.add(alert);
    }

    return EscalationCheckResult(
      shouldEscalate: alerts.isNotEmpty,
      alerts: alerts,
    );
  }

  /// 人工确认处理
  Future<void> resolve({
    required String alertId,
    required String resolvedBy,
  }) async {
    final pending = await repository.listPending();
    final target = pending.where((a) => a.id == alertId).firstOrNull;
    if (target == null) return;

    await repository.update(
      target.copyWith(
        status: EscalationStatus.resolved,
        resolvedBy: resolvedBy,
        resolvedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// 忽略告警
  Future<void> dismiss(String alertId) async {
    final pending = await repository.listPending();
    final target = pending.where((a) => a.id == alertId).firstOrNull;
    if (target == null) return;

    await repository.update(
      target.copyWith(
        status: EscalationStatus.dismissed,
        updatedAt: DateTime.now(),
      ),
    );
  }
}
