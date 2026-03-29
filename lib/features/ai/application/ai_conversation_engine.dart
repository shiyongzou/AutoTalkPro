import 'dart:convert';
import 'dart:io';

import '../../../core/models/business_profile.dart';
import '../../../core/models/message.dart';
import '../../../core/models/negotiation_context.dart';
import '../../../core/models/sentiment_record.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_settings_repository.dart';

class ConversationReply {
  const ConversationReply({
    required this.content,
    required this.confidence,
    required this.provider,
    required this.model,
    required this.strategy,
    required this.reasoning,
  });

  final String content;
  final double confidence; // 0.0~1.0 AI对回复的信心
  final String provider;
  final String model;
  final String strategy;
  final String? reasoning;
}

class AiConversationEngine {
  AiConversationEngine({
    required AiSettingsRepository settingsRepository,
    AiProviderSettings? initialSettings,
  }) : _settingsRepository = settingsRepository,
       _settings = initialSettings ?? AiProviderSettings.defaults;

  final AiSettingsRepository _settingsRepository;
  AiProviderSettings _settings;

  AiProviderSettings get settings => _settings;

  Future<void> restoreSettings() async {
    final loaded = await _settingsRepository.load();
    if (loaded != null) _settings = loaded;
  }

  Future<void> updateSettings(AiProviderSettings settings) async {
    _settings = settings;
    await _settingsRepository.save(settings);
  }

  /// 生成完整的销售对话回复
  Future<ConversationReply> generateReply({
    required String customerName,
    required List<Message> conversationHistory,
    required String goalStage,
    NegotiationContext? negotiation,
    SentimentRecord? latestSentiment,
    String? productInfo,
    String? priceQuoteInfo,
    String? weeklySuggestion,
    String? businessTemplateName,
    BusinessProfile? businessProfile,
    String? personaPrompt,
  }) async {
    final systemPrompt = _buildSystemPrompt(
      customerName: customerName,
      goalStage: goalStage,
      negotiation: negotiation,
      latestSentiment: latestSentiment,
      productInfo: productInfo,
      priceQuoteInfo: priceQuoteInfo,
      personaPrompt: personaPrompt,
      weeklySuggestion: weeklySuggestion,
      businessTemplateName: businessTemplateName,
      businessProfile: businessProfile,
    );

    final messages = _buildMessageList(systemPrompt, conversationHistory);

    switch (_settings.provider) {
      case AiProviderType.mock:
        return _mockReply(customerName, conversationHistory, negotiation, businessProfile);
      case AiProviderType.openaiCompatible:
        return _openAiReply(messages, negotiation);
    }
  }

  String _buildSystemPrompt({
    required String customerName,
    required String goalStage,
    NegotiationContext? negotiation,
    SentimentRecord? latestSentiment,
    String? productInfo,
    String? priceQuoteInfo,
    String? weeklySuggestion,
    String? businessTemplateName,
    BusinessProfile? businessProfile,
    String? personaPrompt,
  }) {
    final buf = StringBuffer();

    // 如果有自定义人设，优先用（不叠加默认prompt）
    if (personaPrompt != null && personaPrompt.isNotEmpty) {
      buf.writeln(personaPrompt);
      buf.writeln();
      buf.writeln('你正在通过即时通讯与对方对话。');
      buf.writeln('直接输出回复内容，不要输出任何解释、标记或前缀。');
      buf.writeln('用中文回答。');
      return buf.toString();
    }

    final bp = businessProfile;
    final personaName = bp?.personaName ?? '小助';
    final personaStyle = bp?.personaStyle ?? '专业简洁，目标导向';
    final isTrading = bp?.businessType == BusinessType.trading;

    buf.writeln('你叫"$personaName"。你通过微信/TG跟"$customerName"聊天。');
    buf.writeln();

    // ===== 最核心的指令：像做生意的真人说话 =====
    buf.writeln('## 绝对铁律');
    buf.writeln('1. 你是真人在做生意，绝对不能暴露自己是AI');
    buf.writeln('2. 每条消息15-50个字左右，太短显得冷淡，太长像机器人');
    buf.writeln('3. 如果要说的内容超过50字，拆成2-3条短消息用\\n分隔，模拟真人分条发');
    buf.writeln('4. 说话口语化但有温度，像一个热心做生意的人：');
    buf.writeln('   - 不说"您好"、"请问"、"非常感谢您"（太客服）');
    buf.writeln('   - 不说"嗯"、"在"这种一个字的（太冷淡）');
    buf.writeln('   - 要说"在的，你看看要哪个"、"好嘞，我帮你查下"（有温度）');
    buf.writeln('5. 一问一答，对方说一句你回一句，别一次倒一堆信息');
    buf.writeln('6. 偶尔用个表情，但不要每条都带');
    buf.writeln();

    if (isTrading) {
      buf.writeln('## 你的角色：$personaStyle');
      buf.writeln('- 效率高但态度好，问什么答什么不拖泥带水');
      buf.writeln('- 报价直接但带一句引导，比如"200，这个性价比很高"而不是光秃秃一个"200"');
      buf.writeln('- 砍价适当让步，但要表现出犹豫，比如"那就给你减一点吧"');
      buf.writeln('- 没收到钱别发货，但语气要友好');
      buf.writeln('- 整体像做了很多年生意的人：不急不躁，让客户感觉靠谱');
    } else {
      buf.writeln('## 你的角色：$personaStyle');
      buf.writeln('- 聊天节奏自然，先聊需求再报价，不急着推销');
      buf.writeln('- 被砍价别马上降，先扛一下，然后说"帮你申请看看"');
      buf.writeln('- 语气像朋友推荐好东西：真诚热心，不油腻不谄媚');
      buf.writeln('- 适当主动，比如"你那边主要想解决什么问题"，显得上心');
    }
    buf.writeln();

    // 额外人设规则
    if (bp != null && bp.personaRules.isNotEmpty) {
      for (final rule in bp.personaRules) {
        buf.writeln('- $rule');
      }
      buf.writeln();
    }

    buf.writeln('## 回复示例（说话就要像这样，有温度但不啰嗦）');
    if (isTrading) {
      buf.writeln('对方: "有片吗" → 你: "有的，你看看想要哪种的"');
      buf.writeln('对方: "多少钱" → 你: "这个200，性价比很高"');
      buf.writeln('对方: "便宜点呗" → 你: "已经很实在了，那给你减到180吧"');
      buf.writeln('对方: "行 怎么付" → 你: "微信转就行，付了我马上给你安排"');
      buf.writeln('对方: "付了" → 你: "收到了，马上安排给你"');
    } else {
      buf.writeln('对方: "怎么收费" → 你: "看你需要哪个版本，基础版899一个月，专业版2999"');
      buf.writeln('对方: "太贵了" → 你: "理解，不过用过的客户反馈都不错\\n我帮你看看能不能申请个优惠"');
      buf.writeln('对方: "能便宜不" → 你: "我帮你问下领导看看\\n你大概打算用多久"');
      buf.writeln('对方: "那行吧" → 你: "好嘞，我把合同发你，你确认下信息"');
    }
    buf.writeln();

    buf.writeln('## 当前状态');
    buf.writeln('- 销售阶段: $goalStage');

    if (negotiation != null) {
      buf.writeln('- 谈判阶段: ${_negotiationStageLabel(negotiation.stage)}');
      buf.writeln('- 成交可能性: ${(negotiation.dealScore * 100).toInt()}%');
      if (negotiation.keyObjections.isNotEmpty) {
        buf.writeln('- 客户异议: ${negotiation.keyObjections.join("、")}');
      }
      if (negotiation.agreedTerms.isNotEmpty) {
        buf.writeln('- 已达共识: ${negotiation.agreedTerms.join("、")}');
      }
      if (negotiation.concessionCount > 0) {
        buf.writeln('- 已让步${negotiation.concessionCount}次(上限${negotiation.maxConcessions}次)');
      }
    }

    if (latestSentiment != null) {
      buf.writeln('- 客户情绪: ${latestSentiment.emotionTags.join("、")}');
      if (latestSentiment.hasBuyingSignal) {
        buf.writeln('- ⚡ 检测到购买信号: ${latestSentiment.buyingSignals.join("、")}');
      }
      if (latestSentiment.hasObjection) {
        buf.writeln('- ⚠️ 客户异议: ${latestSentiment.objectionPatterns.join("、")}');
      }
    }

    buf.writeln();

    if (productInfo != null && productInfo.isNotEmpty) {
      buf.writeln('## 可用产品信息');
      buf.writeln(productInfo);
      buf.writeln();
    }

    if (priceQuoteInfo != null && priceQuoteInfo.isNotEmpty) {
      buf.writeln('## 当前报价方案');
      buf.writeln(priceQuoteInfo);
      buf.writeln();
    }

    if (weeklySuggestion != null && weeklySuggestion.isNotEmpty) {
      buf.writeln('## 本周行业情报');
      buf.writeln(weeklySuggestion);
      buf.writeln();
    }

    buf.writeln('## 谈判策略指导');
    if (negotiation != null) {
      buf.writeln(_getStrategyGuidance(negotiation));
    } else {
      buf.writeln('- 先建立信任，了解客户需求和痛点');
      buf.writeln('- 不急于报价，先确认客户场景');
    }
    buf.writeln();

    buf.writeln('## 禁止事项');
    buf.writeln('- 不得承诺"100%"、"保证"、"包"等绝对性承诺');
    buf.writeln('- 不得自行低于底价报价');
    buf.writeln('- 不得泄露内部成本和底价信息');
    buf.writeln('- 不得贬低竞品，只做客观对比');
    buf.writeln('- 不得在客户情绪激动时强推销售');
    buf.writeln();

    buf.writeln('直接输出你要发的消息内容。如果要发多条用\\n隔开。不要输出任何解释、标记、括号说明。');

    return buf.toString();
  }

  List<Map<String, String>> _buildMessageList(
    String systemPrompt,
    List<Message> history,
  ) {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    // 取最近6条消息作为上下文（省token，6条足够理解对话）
    final recent = history.length > 6
        ? history.sublist(history.length - 6)
        : history;

    for (final msg in recent) {
      final role = msg.role == 'customer' ? 'user' : 'assistant';
      messages.add({'role': role, 'content': msg.content});
    }

    return messages;
  }

  Future<ConversationReply> _openAiReply(
    List<Map<String, String>> messages,
    NegotiationContext? negotiation,
  ) async {
    final apiBase = _settings.apiBase;
    final apiKey = _settings.apiKey;

    if (apiBase == null || apiBase.trim().isEmpty ||
        apiKey == null || apiKey.trim().isEmpty) {
      return _fallbackMockReply('openai-compatible(no-config)');
    }

    // Strip trailing slashes and /v1 suffix to avoid double /v1/v1
    var cleanBase = apiBase.replaceAll(RegExp(r'/+$'), '');
    if (cleanBase.endsWith('/v1')) {
      cleanBase = cleanBase.substring(0, cleanBase.length - 3);
    }
    final endpoint = Uri.parse('$cleanBase/v1/chat/completions');

    // gpt-5.x用max_completion_tokens，旧模型用max_tokens
    final isGpt5 = _settings.model.startsWith('gpt-5');
    final body = {
      'model': _settings.model,
      'temperature': _settings.temperature,
      'messages': messages,
      if (isGpt5) 'max_completion_tokens': 500
      else 'max_tokens': 300,
    };

    try {
      final jsonBody = jsonEncode(body);

      // 用dart:io的HttpClient——彻底避免http包的latin1编码问题
      final ioClient = HttpClient();
      ioClient.connectionTimeout = const Duration(seconds: 10);
      final request = await ioClient.postUrl(endpoint);
      request.headers.set('Authorization', 'Bearer ${apiKey.trim()}');
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.add(utf8.encode(jsonBody));

      final response = await request.close().timeout(const Duration(seconds: 60));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        ioClient.close();
        return _fallbackMockReply('openai-compatible(http-${response.statusCode})');
      }

      // 收集所有字节后UTF-8解码
      final bytes = await response.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
      ioClient.close();

      final responseText = utf8.decode(bytes);
      final decoded = jsonDecode(responseText);
      final content = _extractContent(decoded);
      if (content == null || content.trim().isEmpty) {
        return _fallbackMockReply('openai-compatible(empty)');
      }

      return ConversationReply(
        content: content.trim(),
        confidence: 0.85,
        provider: 'openai-compatible',
        model: _settings.model,
        strategy: negotiation != null ? _negotiationStageLabel(negotiation.stage) : 'general',
        reasoning: null,
      );
    } catch (e) {
      // ignore: avoid_print
      print('[AI Engine Error] $e');
      return _fallbackMockReply('openai-compatible(error)');
    }
  }

  String? _extractContent(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map<String, dynamic>) return null;
    final message = first['message'];
    if (message is! Map<String, dynamic>) return null;
    final content = message['content'];
    if (content is String) return content;
    return null;
  }

  ConversationReply _fallbackMockReply(String provider) {
    return ConversationReply(
      content: '',
      confidence: 0.0,
      provider: provider,
      model: _settings.model,
      strategy: 'fallback',
      reasoning: 'API不可用',
    );
  }

  Future<ConversationReply> _mockReply(
    String customerName,
    List<Message> history,
    NegotiationContext? negotiation,
    BusinessProfile? businessProfile,
  ) async {
    final isTrading = businessProfile?.businessType == BusinessType.trading;
    final latestCustomer = history
        .where((m) => m.role == 'customer')
        .toList();
    final latestText = latestCustomer.isEmpty
        ? ''
        : latestCustomer.last.content;

    String reply;
    String strategy;
    double confidence;

    // ===== 交易模式 =====
    if (isTrading) {
      if (negotiation == null || negotiation.stage == NegotiationStage.opening) {
        reply = '在的，看看要什么';
        strategy = '开场';
        confidence = 0.90;
      } else if (negotiation.stage == NegotiationStage.exploring ||
                 negotiation.stage == NegotiationStage.proposing) {
        if (negotiation.ourOfferPrice != null) {
          reply = '这个${negotiation.ourOfferPrice!.toStringAsFixed(0)}，性价比很高的';
          strategy = '报价';
          confidence = 0.90;
        } else {
          reply = '你具体要哪个，我帮你看下价格';
          strategy = '确认';
          confidence = 0.85;
        }
      } else if (negotiation.stage == NegotiationStage.countering) {
        if (latestText.contains('便宜') || latestText.contains('贵')) {
          reply = '这个价已经很实在了\n那就给你再减一点吧，最低了哈';
          strategy = '让步';
          confidence = 0.80;
        } else {
          reply = '你去对比下就知道了，这个价真不贵';
          strategy = '坚守';
          confidence = 0.78;
        }
      } else if (negotiation.stage == NegotiationStage.closing) {
        reply = '好嘞，你付了我马上给你安排';
        strategy = '成交';
        confidence = 0.92;
      } else if (negotiation.stage == NegotiationStage.won) {
        reply = '收到了，马上安排给你，稍等';
        strategy = '交付';
        confidence = 0.95;
      } else {
        reply = '还在吗，之前聊的那个还需要不';
        strategy = '跟进';
        confidence = 0.70;
      }

      return ConversationReply(
        content: reply,
        confidence: confidence,
        provider: 'mock',
        model: _settings.model,
        strategy: strategy,
        reasoning: 'Mock(交易)',
      );
    }

    // ===== 销售/商务模式 =====
    if (negotiation == null || negotiation.stage == NegotiationStage.opening) {
      reply = '在的，你是想了解哪方面的';
      strategy = '开场';
      confidence = 0.85;
    } else if (negotiation.stage == NegotiationStage.exploring) {
      reply = '明白你的情况了，我们有个方案挺适合的\n要不我给你报个价你参考下';
      strategy = '引导';
      confidence = 0.80;
    } else if (negotiation.stage == NegotiationStage.proposing) {
      reply = '这个方案性价比很高，同行基本没这个价\n而且现在签还有个优惠活动';
      strategy = '报价';
      confidence = 0.78;
    } else if (negotiation.stage == NegotiationStage.countering) {
      if (latestText.contains('太贵') || latestText.contains('便宜')) {
        reply = '理解，很多客户一开始也这么觉得\n不过用了之后反馈都不错\n我帮你申请看看能不能再低点';
        strategy = '异议处理';
        confidence = 0.75;
      } else {
        reply = '这已经是最大诚意了，包含了所有服务\n你觉得可以的话咱推进一下';
        strategy = '坚守';
        confidence = 0.72;
      }
    } else if (negotiation.stage == NegotiationStage.closing) {
      reply = '好嘞，我把合同发你\n你确认下公司信息，争取今天搞定';
      strategy = '签约';
      confidence = 0.90;
    } else if (negotiation.stage == NegotiationStage.won) {
      reply = '谢谢信任，合同马上安排\n后面有专人对接你，有什么随时找我';
      strategy = '确认';
      confidence = 0.95;
    } else if (negotiation.stage == NegotiationStage.stalled) {
      reply = '好久没聊了，最近上了点新功能\n挺适合你之前说的那个需求的，有空聊两句不';
      strategy = '激活';
      confidence = 0.68;
    } else {
      reply = '好的，还有什么想了解的吗';
      strategy = '通用';
      confidence = 0.65;
    }

    return ConversationReply(
      content: reply,
      confidence: confidence,
      provider: 'mock',
      model: _settings.model,
      strategy: strategy,
      reasoning: 'Mock模式: 基于谈判阶段生成',
    );
  }

  String _getStrategyGuidance(NegotiationContext neg) {
    switch (neg.stage) {
      case NegotiationStage.opening:
        return '- 建立信任和亲和力\n- 开放式提问了解客户背景\n- 不要急于推产品';
      case NegotiationStage.exploring:
        return '- 深挖客户痛点和需求优先级\n- 了解预算范围和决策流程\n- 识别关键决策人';
      case NegotiationStage.proposing:
        return '- 先讲价值再报价\n- 用案例和数据支撑\n- 给出清晰的方案对比\n- 锚定在较高价位';
      case NegotiationStage.countering:
        if (neg.canConcede) {
          return '- 不直接降价，先强调差异化价值\n- 必须让步时用"申请特批"包装\n- 每次让步幅度递减\n- 让步时要求对方也有承诺(如签约时间)';
        }
        return '- 已达让步上限，坚守价格底线\n- 转移焦点到增值服务\n- 如果客户坚持，建议人工接管';
      case NegotiationStage.closing:
        return '- 快速推进签约流程\n- 确认合同细节\n- 制造紧迫感(名额有限、优惠截止等)';
      case NegotiationStage.won:
        return '- 表示感谢和重视\n- 安排后续对接人\n- 适当提及升级或增购机会';
      case NegotiationStage.lost:
        return '- 礼貌收尾，不纠缠\n- 留下好印象\n- 保持联系渠道畅通';
      case NegotiationStage.stalled:
        return '- 用新信息重新激活(新功能、限时优惠)\n- 不提之前的分歧\n- 重新建立对话节奏';
    }
  }

  String _negotiationStageLabel(NegotiationStage stage) {
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
