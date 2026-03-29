import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/models/message.dart';
import '../../knowledge/application/weekly_communication_advisor.dart';
import '../domain/ai_draft.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_settings_repository.dart';

class AiDraftService {
  AiDraftService({
    required AiSettingsRepository settingsRepository,
    required WeeklyCommunicationAdvisor weeklyCommunicationAdvisor,
    http.Client? httpClient,
    AiProviderSettings? initialSettings,
  }) : _settingsRepository = settingsRepository,
       _weeklyCommunicationAdvisor = weeklyCommunicationAdvisor,
       _client = httpClient ?? http.Client(),
       _settings = initialSettings ?? AiProviderSettings.defaults;

  final AiSettingsRepository _settingsRepository;
  final WeeklyCommunicationAdvisor _weeklyCommunicationAdvisor;
  final http.Client _client;
  AiProviderSettings _settings;

  AiProviderSettings get settings => _settings;

  Future<void> restoreSettings() async {
    final loaded = await _settingsRepository.load();
    if (loaded != null) {
      _settings = loaded;
    }
  }

  Future<void> updateSettings(AiProviderSettings settings) async {
    _settings = settings;
    await _settingsRepository.save(settings);
  }

  Future<AiDraftResult> generateDraft({
    required String customerName,
    required String goalStage,
    required List<Message> messages,
    String industry = '跨境电商SaaS',
    String? templateName,
  }) async {
    final latestCustomerMessage = messages
        .where((m) => m.role == 'customer')
        .fold<Message?>(null, (prev, curr) {
          if (prev == null) return curr;
          return curr.sentAt.isAfter(prev.sentAt) ? curr : prev;
        });

    final advice = await _weeklyCommunicationAdvisor.suggest(
      industry: industry,
      templateName: templateName ?? goalStage,
    );

    final request = AiDraftRequest(
      customerName: customerName,
      latestCustomerMessage: latestCustomerMessage?.content ?? '您好',
      goalStage: goalStage,
      style: '专业简洁，目标导向',
      weeklySuggestion: advice.summary,
    );

    switch (_settings.provider) {
      case AiProviderType.mock:
        return _mockDraft(request);
      case AiProviderType.openaiCompatible:
        return _openAiCompatibleDraft(request);
    }
  }

  Future<AiDraftResult> _openAiCompatibleDraft(AiDraftRequest request) async {
    final apiBase = _settings.apiBase;
    final apiKey = _settings.apiKey;

    if (apiBase == null ||
        apiBase.trim().isEmpty ||
        apiKey == null ||
        apiKey.trim().isEmpty) {
      return _mockDraft(
        request,
        provider: 'openai-compatible(fallback)',
        model: _settings.model,
      );
    }

    final endpoint = Uri.parse(
      '${apiBase.replaceAll(RegExp(r'/+$'), '')}/v1/chat/completions',
    );

    final body = {
      'model': _settings.model,
      'temperature': _settings.temperature,
      'messages': [
        {'role': 'system', 'content': '你是业务沟通助手。输出一条可直接发送给客户的回复，简洁、专业、目标导向。'},
        {
          'role': 'user',
          'content':
              '客户名: ${request.customerName}\n当前阶段: ${request.goalStage}\n客户消息: ${request.latestCustomerMessage}\n本周沟通建议: ${request.weeklySuggestion}\n风格: ${request.style}\n请生成回复。',
        },
      ],
    };

    try {
      final response = await _client
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _mockDraft(
          request,
          provider: 'openai-compatible(http-${response.statusCode}-fallback)',
          model: _settings.model,
        );
      }

      final decoded = jsonDecode(response.body);
      final content = _extractContent(decoded);
      if (content == null || content.trim().isEmpty) {
        return _mockDraft(
          request,
          provider: 'openai-compatible(empty-fallback)',
          model: _settings.model,
        );
      }

      return AiDraftResult(
        content: content.trim(),
        provider: 'openai-compatible',
        model: _settings.model,
        rationale: '已通过 OpenAI-compatible 接口生成',
      );
    } catch (_) {
      return _mockDraft(
        request,
        provider: 'openai-compatible(error-fallback)',
        model: _settings.model,
      );
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

  Future<AiDraftResult> _mockDraft(
    AiDraftRequest request, {
    String provider = 'mock',
    String? model,
  }) async {
    final text =
        '您好${request.customerName}，收到您这边“${request.latestCustomerMessage}”。\n'
        '结合本周行业情报建议：${request.weeklySuggestion}\n'
        '我这边建议先确认您的核心需求和预算区间，我可以按您场景给到最匹配方案与报价。\n'
        '您方便说下预计使用时间和主要关注点吗？';
    return AiDraftResult(
      content: text,
      provider: provider,
      model: model ?? _settings.model,
      rationale: '当前阶段(${request.goalStage})优先做需求确认并结合本周沟通建议推进。',
    );
  }
}
