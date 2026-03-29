import 'package:flutter/material.dart';

import '../../../core/platform_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_context.dart';
import '../app_theme.dart';
import '../../../features/ai/domain/ai_provider.dart';

class AiCenterPage extends StatefulWidget {
  const AiCenterPage({required this.appContext, super.key});

  final AppContext appContext;

  @override
  State<AiCenterPage> createState() => _AiCenterPageState();
}

class _AiCenterPageState extends State<AiCenterPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _customModelController = TextEditingController();
  late String _selectedPlatformId;
  late String _selectedModel;
  late double _creativity;

  // 每个平台单独存key
  final Map<String, String> _platformKeys = {};

  @override
  void initState() {
    super.initState();
    final settings = widget.appContext.aiConversationEngine.settings;
    _selectedModel = settings.model;
    _creativity = settings.temperature;
    _selectedPlatformId = _findPlatformId(_selectedModel);
    _loadAllKeys();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  Future<void> _loadAllKeys() async {
    final prefs = await SharedPreferences.getInstance();
    for (final p in AiProviderSettings.platforms) {
      final key = prefs.getString('ai.apiKey.${p.id}') ?? '';
      _platformKeys[p.id] = key;
    }
    // 加载当前平台的key到输入框
    _apiKeyController.text = _platformKeys[_selectedPlatformId] ?? '';
    if (mounted) setState(() {});
  }

  String _findPlatformId(String model) {
    for (final p in AiProviderSettings.platforms) {
      if (p.models.contains(model)) return p.id;
    }
    return AiProviderSettings.platforms.first.id;
  }

  ({
    String id,
    String label,
    String apiBase,
    String description,
    List<String> models,
  })?
  get _currentPlatform {
    return AiProviderSettings.platforms
        .where((p) => p.id == _selectedPlatformId)
        .firstOrNull;
  }

  void _onPlatformChanged(String platformId) {
    // 保存当前平台的key
    _platformKeys[_selectedPlatformId] = _apiKeyController.text.trim();
    // 切换平台
    final platform = AiProviderSettings.platforms.firstWhere(
      (p) => p.id == platformId,
    );
    setState(() {
      _selectedPlatformId = platformId;
      _selectedModel = platform.models.first;
      _apiKeyController.text = _platformKeys[platformId] ?? '';
      _customModelController.clear();
    });
  }

  Future<void> _save() async {
    final platform = _currentPlatform;
    if (platform == null) {
      _showMessage('请先选择平台', false);
      return;
    }

    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty && !platform.apiBase.contains('localhost')) {
      _showMessage('请填写API Key', false);
      return;
    }

    // 保存当前平台的key
    _platformKeys[_selectedPlatformId] = apiKey;

    try {
      // 持久化每个平台的key
      final prefs = await SharedPreferences.getInstance();
      for (final entry in _platformKeys.entries) {
        if (entry.value.isNotEmpty) {
          await prefs.setString('ai.apiKey.${entry.key}', entry.value);
        }
      }

      final settings = AiProviderSettings(
        provider: AiProviderType.openaiCompatible,
        model: _selectedModel,
        apiBase: platform.apiBase,
        apiKey: apiKey.isEmpty ? null : apiKey,
        temperature: _creativity,
      );

      await widget.appContext.aiConversationEngine.updateSettings(settings);
      await widget.appContext.aiDraftService.updateSettings(settings);

      _showMessage('保存成功 — ${platform.label} / $_selectedModel', true);
    } catch (e) {
      _showMessage('保存失败: $e', false);
    }
  }

  void _showMessage(String text, bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openKeyPage() async {
    final platform = _currentPlatform;
    if (platform == null) return;
    final base = platform.apiBase.toLowerCase();
    final String url;
    if (base.contains('deepseek')) {
      url = 'https://platform.deepseek.com/api_keys';
    } else if (base.contains('dashscope')) {
      url = 'https://dashscope.console.aliyun.com/apiKey';
    } else if (base.contains('moonshot')) {
      url = 'https://platform.moonshot.cn/console/api-keys';
    } else if (base.contains('bigmodel')) {
      url = 'https://open.bigmodel.cn/usercenter/apikeys';
    } else if (base.contains('lingyiwanwu')) {
      url = 'https://platform.lingyiwanwu.com/apikeys';
    } else if (base.contains('volces')) {
      url = 'https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey';
    } else if (base.contains('anthropic')) {
      url = 'https://console.anthropic.com/settings/keys';
    } else if (base.contains('minimax')) {
      url =
          'https://platform.minimaxi.com/user-center/basic-information/interface-key';
    } else {
      url = 'https://platform.openai.com/api-keys';
    }
    await PlatformUtils.openUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final scheme = Theme.of(context).colorScheme;
    final platform = _currentPlatform;

    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI 设置', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '选择AI平台和模型，配置API Key',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
          ),
          SizedBox(height: tokens.spaceLg),

          // ── 第一步：选平台 ──
          Text('1. 选择AI平台', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '不同平台需要不同的Key，选你注册了的',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          SizedBox(height: tokens.spaceSm),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: AiProviderSettings.platforms.map((p) {
              final isSelected = p.id == _selectedPlatformId;
              final hasKey = (_platformKeys[p.id] ?? '').isNotEmpty;
              return GestureDetector(
                onTap: () => _onPlatformChanged(p.id),
                child: Container(
                  width: 170,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primaryContainer.withValues(alpha: 0.5)
                        : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? scheme.primary
                          : scheme.outlineVariant.withValues(alpha: 0.5),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_off,
                            size: 16,
                            color: isSelected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (hasKey)
                            Icon(
                              Icons.key,
                              size: 12,
                              color: Colors.green.shade400,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          SizedBox(height: tokens.spaceLg),

          if (platform != null) ...[
            // ── 第二步：选模型 ──
            Text('2. 选择模型', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '选一个，或在下方输入新模型名',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            SizedBox(height: tokens.spaceSm),
            Wrap(
              spacing: tokens.spaceSm,
              runSpacing: tokens.spaceSm,
              children: platform.models.map((model) {
                final isSelected = model == _selectedModel;
                return ChoiceChip(
                  label: Text(model),
                  selected: isSelected,
                  onSelected: (_) => setState(() {
                    _selectedModel = model;
                    _customModelController.clear();
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _customModelController,
              decoration: const InputDecoration(
                hintText: '列表没有？输入新模型名回车确认',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  setState(() => _selectedModel = v.trim());
                }
              },
            ),
            const SizedBox(height: 4),
            Text(
              '当前: $_selectedModel',
              style: TextStyle(
                fontSize: 12,
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),

            SizedBox(height: tokens.spaceLg),

            // ── 第三步：API Key ──
            if (!platform.apiBase.contains('localhost')) ...[
              Text(
                '3. 填写 ${platform.label} 的 API Key',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '每个平台的Key不一样，切换平台会自动切换Key',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              SizedBox(height: tokens.spaceSm),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'sk-...',
                  border: const OutlineInputBorder(),
                  suffixIcon: TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('去获取', style: TextStyle(fontSize: 12)),
                    onPressed: _openKeyPage,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ] else ...[
              Text('3. 无需Key', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '确保已安装并运行Ollama（ollama.com）',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],

            SizedBox(height: tokens.spaceLg),

            // ── 回复风格 ──
            Text('4. 回复风格', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('稳定', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Slider(
                    value: _creativity,
                    min: 0.0,
                    max: 1.5,
                    divisions: 15,
                    onChanged: (v) => setState(() => _creativity = v),
                  ),
                ),
                const Text('灵活', style: TextStyle(fontSize: 13)),
              ],
            ),
            Center(
              child: Text(
                _creativityLabel(_creativity),
                style: TextStyle(
                  fontSize: 13,
                  color: _creativity > 1.0 ? Colors.red : scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_creativity > 1.0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '⚠️ 超过1.0可能导致回复混乱或出现乱码，建议保持在0.7左右',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
              ),

            SizedBox(height: tokens.spaceLg),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('保存设置'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _creativityLabel(double value) {
    if (value <= 0.3) return '非常稳定';
    if (value <= 0.5) return '比较稳定';
    if (value <= 0.7) return '适中（推荐）';
    if (value <= 1.0) return '比较灵活';
    return '非常灵活';
  }
}
