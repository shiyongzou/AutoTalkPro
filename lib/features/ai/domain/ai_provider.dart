enum AiProviderType { mock, openaiCompatible }

class AiProviderSettings {
  const AiProviderSettings({
    required this.provider,
    required this.model,
    this.apiBase,
    this.apiKey,
    this.temperature = 0.6,
  });

  final AiProviderType provider;
  final String model;
  final String? apiBase;
  final String? apiKey;
  final double temperature;

  AiProviderSettings copyWith({
    AiProviderType? provider,
    String? model,
    String? apiBase,
    String? apiKey,
    double? temperature,
  }) {
    return AiProviderSettings(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      apiBase: apiBase ?? this.apiBase,
      apiKey: apiKey ?? this.apiKey,
      temperature: temperature ?? this.temperature,
    );
  }

  static const defaults = AiProviderSettings(
    provider: AiProviderType.mock,
    model: 'mock-sales-v1',
    temperature: 0.6,
  );

  // ── 预设模型（快捷切换用）──

  static const gpt4o = AiProviderSettings(
    provider: AiProviderType.openaiCompatible,
    model: 'gpt-4o',
    apiBase: 'https://api.openai.com',
    temperature: 0.7,
  );

  static const gpt4oMini = AiProviderSettings(
    provider: AiProviderType.openaiCompatible,
    model: 'gpt-4o-mini',
    apiBase: 'https://api.openai.com',
    temperature: 0.7,
  );

  static const deepseek = AiProviderSettings(
    provider: AiProviderType.openaiCompatible,
    model: 'deepseek-chat',
    apiBase: 'https://api.deepseek.com',
    temperature: 0.7,
  );

  static const qwen = AiProviderSettings(
    provider: AiProviderType.openaiCompatible,
    model: 'qwen-plus',
    apiBase: 'https://dashscope.aliyuncs.com/compatible-mode',
    temperature: 0.7,
  );

  static const moonshot = AiProviderSettings(
    provider: AiProviderType.openaiCompatible,
    model: 'moonshot-v1-8k',
    apiBase: 'https://api.moonshot.cn',
    temperature: 0.7,
  );

  static const glm4 = AiProviderSettings(
    provider: AiProviderType.openaiCompatible,
    model: 'glm-4',
    apiBase: 'https://open.bigmodel.cn/api/paas',
    temperature: 0.7,
  );

  static const yi = AiProviderSettings(
    provider: AiProviderType.openaiCompatible,
    model: 'yi-large',
    apiBase: 'https://api.lingyiwanwu.com',
    temperature: 0.7,
  );

  static const doubao = AiProviderSettings(
    provider: AiProviderType.openaiCompatible,
    model: 'doubao-pro-4k',
    apiBase: 'https://ark.cn-beijing.volces.com/api',
    temperature: 0.7,
  );

  static const ollama = AiProviderSettings(
    provider: AiProviderType.openaiCompatible,
    model: 'qwen2',
    apiBase: 'http://localhost:11434',
    temperature: 0.7,
  );

  /// 平台列表（每个平台下有多个模型可选）
  static const List<
    ({
      String id,
      String label,
      String apiBase,
      String description,
      List<String> models,
    })
  >
  platforms = [
    (
      id: 'openai',
      label: 'OpenAI',
      apiBase: 'https://api.openai.com',
      description: '最聪明的模型，需要海外网络',
      models: [
        'gpt-5.4',
        'gpt-5.4-mini',
        'gpt-5.4-pro',
        'gpt-5',
        'gpt-5-mini',
        'gpt-4.1',
        'gpt-4.1-mini',
        'gpt-4o',
        'gpt-4o-mini',
        'o3-mini',
      ],
    ),
    (
      id: 'anthropic',
      label: 'Claude',
      apiBase: 'https://api.anthropic.com',
      description: 'Anthropic出品，代码和推理最强',
      models: [
        'claude-opus-4-6',
        'claude-sonnet-4-6',
        'claude-haiku-4-5',
        'claude-sonnet-4-5-20241022',
        'claude-3-opus-20240229',
      ],
    ),
    (
      id: 'deepseek',
      label: 'DeepSeek',
      apiBase: 'https://api.deepseek.com',
      description: '国产最强，中文好，便宜，推荐',
      models: [
        'deepseek-chat',
        'deepseek-reasoner',
        'DeepSeek-V3',
        'DeepSeek-V3.2',
        'DeepSeek-R1',
        'DeepSeek-R1-0528',
        'DeepSeek-Prover-V2-671B',
      ],
    ),
    (
      id: 'qwen',
      label: '通义千问',
      apiBase: 'https://dashscope.aliyuncs.com/compatible-mode',
      description: '阿里出品，国内直连',
      models: [
        'qwen3-235b-a22b',
        'qwen-max',
        'qwen-plus',
        'qwen-turbo',
        'qwen-long',
        'qwen2.5-72b-instruct',
        'qwen2.5-32b-instruct',
      ],
    ),
    (
      id: 'moonshot',
      label: 'Moonshot / Kimi',
      apiBase: 'https://api.moonshot.cn',
      description: '月之暗面，擅长长文本',
      models: ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k'],
    ),
    (
      id: 'glm',
      label: '智谱GLM',
      apiBase: 'https://open.bigmodel.cn/api/paas',
      description: '清华团队，中文自然',
      models: [
        'glm-4-plus',
        'glm-4',
        'glm-4-flash',
        'glm-4-air',
        'glm-4-long',
        'glm-4v',
        'glm-3-turbo',
      ],
    ),
    (
      id: 'doubao',
      label: '豆包',
      apiBase: 'https://ark.cn-beijing.volces.com/api',
      description: '字节出品，速度最快',
      models: [
        'doubao-pro-256k',
        'doubao-pro-32k',
        'doubao-pro-4k',
        'doubao-lite-32k',
        'doubao-lite-4k',
      ],
    ),
    (
      id: 'minimax',
      label: 'MiniMax',
      apiBase: 'https://api.minimax.chat',
      description: '海螺AI，多模态能力强',
      models: ['MiniMax-Text-01', 'abab6.5s-chat'],
    ),
    (
      id: 'ollama',
      label: 'Ollama本地',
      apiBase: 'http://localhost:11434',
      description: '本地运行，完全免费，不联网',
      models: [
        'qwen2.5',
        'qwen3',
        'llama3.3',
        'deepseek-r1',
        'deepseek-v3',
        'mistral',
        'gemma2',
        'phi4',
        'command-r',
      ],
    ),
  ];

  /// 兼容旧代码的presets（从platforms生成）
  static final List<({String key, String label, AiProviderSettings settings})>
  presets = platforms
      .expand(
        (p) => p.models.map(
          (m) => (
            key: m,
            label: '${p.label} / $m',
            settings: AiProviderSettings(
              provider: AiProviderType.openaiCompatible,
              model: m,
              apiBase: p.apiBase,
              temperature: 0.7,
            ),
          ),
        ),
      )
      .toList();
}
