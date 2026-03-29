import '../../../core/models/message.dart';
import '../../../core/models/negotiation_context.dart';
import '../../product/application/pricing_engine.dart';
import '../domain/negotiation_repository.dart';

class NegotiationDecision {
  const NegotiationDecision({
    required this.updatedContext,
    required this.strategy,
    required this.suggestedResponse,
    required this.priceQuote,
    required this.shouldEscalate,
    required this.escalateReason,
  });

  final NegotiationContext updatedContext;
  final String strategy;
  final String suggestedResponse;
  final PriceQuote? priceQuote;
  final bool shouldEscalate;
  final String? escalateReason;
}

class NegotiationEngine {
  const NegotiationEngine({
    required this.repository,
    required this.pricingEngine,
  });

  final NegotiationRepository repository;
  final PricingEngine pricingEngine;

  /// 分析客户消息并推进谈判
  Future<NegotiationDecision> processMessage({
    required NegotiationContext context,
    required Message customerMessage,
  }) async {
    final text = customerMessage.content.toLowerCase();
    var updated = context.copyWith(updatedAt: DateTime.now());

    // 检测客户预算信号
    final budgetMatch = RegExp(r'预算[是在约]?\s*(\d+)').firstMatch(text);
    if (budgetMatch != null) {
      final budget = double.tryParse(budgetMatch.group(1)!);
      if (budget != null) {
        updated = updated.copyWith(
          customerBudgetHigh: budget,
          customerBudgetLow: budget * 0.7,
        );
      }
    }

    // 检测客户报价
    final offerMatch = RegExp(r'(最多|只能|出|给)\s*(\d+)').firstMatch(text);
    if (offerMatch != null) {
      final offer = double.tryParse(offerMatch.group(2)!);
      if (offer != null) {
        updated = updated.copyWith(customerOfferPrice: offer);
      }
    }

    // 检测异议
    final newObjections = <String>[];
    if (text.contains('太贵') || text.contains('价格高')) {
      newObjections.add('价格异议');
    }
    if (text.contains('竞品') || text.contains('对比') || text.contains('别家')) {
      newObjections.add('竞品比较');
    }
    if (text.contains('功能不够') || text.contains('缺少')) {
      newObjections.add('功能缺失');
    }
    if (text.contains('不确定') || text.contains('考虑') || text.contains('再想想')) {
      newObjections.add('决策犹豫');
    }
    if (text.contains('时间') || text.contains('太慢') || text.contains('什么时候')) {
      newObjections.add('交付周期');
    }

    if (newObjections.isNotEmpty) {
      final allObjections = {
        ...updated.keyObjections,
        ...newObjections,
      }.toList();
      updated = updated.copyWith(keyObjections: allObjections);
    }

    // 检测成交信号
    final agreedNew = <String>[];
    if (text.contains('可以') || text.contains('同意') || text.contains('行')) {
      if (text.contains('价格') || text.contains('报价')) agreedNew.add('价格确认');
      if (text.contains('方案') || text.contains('套餐')) agreedNew.add('方案确认');
      if (text.contains('合同') || text.contains('签')) agreedNew.add('合同意向');
    }
    if (text.contains('付款') || text.contains('打款') || text.contains('转账')) {
      agreedNew.add('付款意向');
    }

    if (agreedNew.isNotEmpty) {
      final allAgreed = {...updated.agreedTerms, ...agreedNew}.toList();
      updated = updated.copyWith(agreedTerms: allAgreed);
    }

    // 推进阶段
    updated = _advanceStage(updated, text);

    // 计算deal score
    updated = _recalcDealScore(updated);

    // 决定策略
    final strategy = _decideStrategy(updated, text);

    // 获取报价
    PriceQuote? quote;
    if (updated.productIds.isNotEmpty && _needsQuote(updated.stage, text)) {
      quote = await pricingEngine.computeQuote(
        productId: updated.productIds.first,
        quantity: 1,
        customerBudget: updated.customerBudgetHigh,
      );

      if (quote != null &&
          updated.stage == NegotiationStage.countering &&
          updated.canConcede) {
        quote = await pricingEngine.computeConcession(
          productId: updated.productIds.first,
          quantity: 1,
          currentPrice: updated.ourOfferPrice ?? quote.quotedPrice,
          concessionStep: updated.concessionCount,
        );
        updated = updated.copyWith(
          concessionCount: updated.concessionCount + 1,
          ourOfferPrice: quote?.quotedPrice,
        );
      } else if (quote != null && updated.ourOfferPrice == null) {
        updated = updated.copyWith(ourOfferPrice: quote.quotedPrice);
      }
    }

    // 判断是否需要升级
    bool shouldEscalate = false;
    String? escalateReason;

    if (quote != null && !quote.isAboveFloor) {
      shouldEscalate = true;
      escalateReason = '客户要价已触达底价，需要人工决策';
    } else if (quote != null && quote.requiresApproval) {
      shouldEscalate = true;
      escalateReason = '当前折扣力度需要${quote.approvalLevel}级审批';
    } else if (!updated.canConcede &&
        updated.stage == NegotiationStage.countering) {
      shouldEscalate = true;
      escalateReason = '让步次数已达上限(${updated.maxConcessions}次)，需人工接管';
    } else if (updated.keyObjections.length >= 3) {
      shouldEscalate = true;
      escalateReason = '客户异议累积过多(${updated.keyObjections.length}个)，建议人工介入';
    }

    final suggestedResponse = _buildSuggestedResponse(updated, strategy, quote);

    await repository.upsert(updated);

    return NegotiationDecision(
      updatedContext: updated,
      strategy: strategy,
      suggestedResponse: suggestedResponse,
      priceQuote: quote,
      shouldEscalate: shouldEscalate,
      escalateReason: escalateReason,
    );
  }

  /// 为新会话创建谈判上下文
  Future<NegotiationContext> createContext({
    required String conversationId,
    required String customerId,
    List<String> productIds = const [],
  }) async {
    final ctx = NegotiationContext(
      id: 'neg_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      customerId: customerId,
      stage: NegotiationStage.opening,
      productIds: productIds,
      customerBudgetLow: null,
      customerBudgetHigh: null,
      ourOfferPrice: null,
      customerOfferPrice: null,
      concessionCount: 0,
      maxConcessions: 4,
      dealScore: 0.1,
      keyObjections: const [],
      agreedTerms: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repository.upsert(ctx);
    return ctx;
  }

  NegotiationContext _advanceStage(NegotiationContext ctx, String text) {
    if (ctx.isTerminal) return ctx;

    switch (ctx.stage) {
      case NegotiationStage.opening:
        if (text.contains('价格') ||
            text.contains('报价') ||
            text.contains('多少钱') ||
            text.contains('费用')) {
          return ctx.copyWith(stage: NegotiationStage.exploring);
        }
        if (text.contains('需求') || text.contains('想要') || text.contains('了解')) {
          return ctx.copyWith(stage: NegotiationStage.exploring);
        }
        return ctx;

      case NegotiationStage.exploring:
        if (text.contains('方案') ||
            text.contains('套餐') ||
            text.contains('报个价')) {
          return ctx.copyWith(stage: NegotiationStage.proposing);
        }
        return ctx;

      case NegotiationStage.proposing:
        if (text.contains('太贵') ||
            text.contains('优惠') ||
            text.contains('便宜') ||
            text.contains('让步')) {
          return ctx.copyWith(stage: NegotiationStage.countering);
        }
        if (text.contains('可以') || text.contains('行') || text.contains('合同')) {
          return ctx.copyWith(stage: NegotiationStage.closing);
        }
        return ctx;

      case NegotiationStage.countering:
        if (text.contains('行') ||
            text.contains('就这个') ||
            text.contains('成交') ||
            text.contains('签')) {
          return ctx.copyWith(stage: NegotiationStage.closing);
        }
        if (text.contains('不行') ||
            text.contains('算了') ||
            text.contains('不要了')) {
          return ctx.copyWith(stage: NegotiationStage.stalled);
        }
        return ctx;

      case NegotiationStage.closing:
        if (text.contains('付款') ||
            text.contains('打款') ||
            text.contains('转账') ||
            text.contains('签了')) {
          return ctx.copyWith(stage: NegotiationStage.won);
        }
        if (text.contains('不签') || text.contains('取消')) {
          return ctx.copyWith(stage: NegotiationStage.lost);
        }
        return ctx;

      case NegotiationStage.stalled:
        if (text.contains('重新') ||
            text.contains('再看看') ||
            text.contains('还是想')) {
          return ctx.copyWith(stage: NegotiationStage.countering);
        }
        return ctx;

      default:
        return ctx;
    }
  }

  NegotiationContext _recalcDealScore(NegotiationContext ctx) {
    double score = 0.1;

    // 阶段分
    const stageScores = {
      NegotiationStage.opening: 0.1,
      NegotiationStage.exploring: 0.25,
      NegotiationStage.proposing: 0.45,
      NegotiationStage.countering: 0.55,
      NegotiationStage.closing: 0.8,
      NegotiationStage.won: 1.0,
      NegotiationStage.lost: 0.0,
      NegotiationStage.stalled: 0.2,
    };
    score = stageScores[ctx.stage] ?? 0.1;

    // 成交信号加分
    score += ctx.agreedTerms.length * 0.05;

    // 异议扣分
    score -= ctx.keyObjections.length * 0.03;

    // 预算匹配加分
    if (ctx.customerBudgetHigh != null && ctx.ourOfferPrice != null) {
      if (ctx.ourOfferPrice! <= ctx.customerBudgetHigh!) {
        score += 0.1;
      }
    }

    return ctx.copyWith(dealScore: score.clamp(0.0, 1.0));
  }

  String _decideStrategy(NegotiationContext ctx, String text) {
    switch (ctx.stage) {
      case NegotiationStage.opening:
        return '建立信任，了解需求';
      case NegotiationStage.exploring:
        return '深挖痛点，匹配产品';
      case NegotiationStage.proposing:
        return '呈现价值，锚定报价';
      case NegotiationStage.countering:
        if (ctx.canConcede) return '有限让步，强调价值差异';
        return '坚守底线，转移价值焦点';
      case NegotiationStage.closing:
        return '推动签约，确认条款';
      case NegotiationStage.won:
        return '成交确认，安排交付';
      case NegotiationStage.lost:
        return '礼貌收尾，保留跟进机会';
      case NegotiationStage.stalled:
        return '重新激活，提供新方案或限时优惠';
    }
  }

  bool _needsQuote(NegotiationStage stage, String text) {
    if (stage == NegotiationStage.proposing ||
        stage == NegotiationStage.countering) {
      return true;
    }
    if (text.contains('多少钱') || text.contains('价格') || text.contains('报价')) {
      return true;
    }
    return false;
  }

  String _buildSuggestedResponse(
    NegotiationContext ctx,
    String strategy,
    PriceQuote? quote,
  ) {
    final buf = StringBuffer();
    buf.writeln('[谈判策略: $strategy]');
    buf.writeln(
      '[阶段: ${_stageLabel(ctx.stage)} | 成交分: ${(ctx.dealScore * 100).toInt()}%]',
    );
    if (ctx.keyObjections.isNotEmpty) {
      buf.writeln('[待处理异议: ${ctx.keyObjections.join('、')}]');
    }
    if (quote != null) {
      buf.writeln(
        '[报价: ¥${quote.quotedPrice.toStringAsFixed(0)} '
        '(折${quote.discountPercent.toStringAsFixed(1)}%)]',
      );
    }
    return buf.toString();
  }

  String _stageLabel(NegotiationStage stage) {
    const labels = {
      NegotiationStage.opening: '开场',
      NegotiationStage.exploring: '需求探索',
      NegotiationStage.proposing: '方案报价',
      NegotiationStage.countering: '价格博弈',
      NegotiationStage.closing: '推动成交',
      NegotiationStage.won: '成交',
      NegotiationStage.lost: '丢单',
      NegotiationStage.stalled: '停滞',
    };
    return labels[stage] ?? stage.name;
  }
}
