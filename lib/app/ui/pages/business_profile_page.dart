import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../app_context.dart';
import '../app_theme.dart';

class BusinessProfilePage extends StatefulWidget {
  const BusinessProfilePage({required this.appContext, super.key});

  final AppContext appContext;

  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  List<Map<String, dynamic>> profiles = [];
  int? activeIndex;
  int selectedIndex = 0;

  /// 内置默认人设（极简版，约150 token）
  static final _defaultPersona = <String, dynamic>{
    'type': 'profession',
    'name': '产科医生',
    'aiName': '小Q',
    'profession': '产科医生',
    'style': '专业简洁，温和，像门诊医生说话',
    'rules': <String>['不能推荐任何产品,特别是药物'],
    'greeting': '您好，我是小Q，请告诉我孕周和症状。',
    'expertise': '苏州市立医院产科专家。信息不足先问孕周和症状。危急情况提示立即就医。结尾加"以上不能替代面诊"。',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('personas');
    if (raw != null) {
      profiles = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    }
    activeIndex = prefs.getInt('active_persona');
    // 首次使用：加载内置默认人设
    if (profiles.isEmpty) {
      profiles.add(Map<String, dynamic>.from(_defaultPersona));
      activeIndex = 0;
      await _save();
    }
    if (selectedIndex >= profiles.length && profiles.isNotEmpty) {
      selectedIndex = 0;
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('personas', jsonEncode(profiles));
    if (activeIndex != null) {
      await prefs.setInt('active_persona', activeIndex!);
    }
  }

  void _addProfile(String type) {
    final p = <String, dynamic>{
      'type': type, // 'profession' 或 'trading'
      'name': type == 'profession' ? '新职业人设' : '新交易人设',
      'aiName': '',
      'profession': '', // 职业型：如"产科医生"
      'style': '',
      'rules': <String>[],
      'greeting': '',
      'expertise': '', // 职业型：擅长领域
    };
    setState(() {
      profiles.add(p);
      selectedIndex = profiles.length - 1;
    });
    _save();
  }

  void _deleteProfile(int index) {
    setState(() {
      profiles.removeAt(index);
      if (activeIndex == index) activeIndex = null;
      if (activeIndex != null && activeIndex! > index) activeIndex = activeIndex! - 1;
      if (selectedIndex >= profiles.length) selectedIndex = profiles.isEmpty ? 0 : profiles.length - 1;
    });
    _save();
  }

  void _activate(int index) {
    setState(() => activeIndex = index);
    _save();

    // 通知用户
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已启用人设: ${profiles[index]['name']}'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // 左侧：人设列表
        SizedBox(
          width: 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(tokens.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('我的人设', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _addProfile('profession'),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('新增人设', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
              if (profiles.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(tokens.spaceLg),
                      child: Text(
                        '还没有人设\n\n点上方按钮创建\n\n例如：产科医生、心理咨询师、律师、健身教练\n\nAI会按你设定的职业身份和专业知识回答问题',
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.6),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: profiles.length,
                    itemBuilder: (context, i) {
                      final p = profiles[i];
                      final isActive = activeIndex == i;
                      final isSelected = selectedIndex == i;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.3),
                        leading: Icon(
                          Icons.person,
                          size: 18,
                          color: isActive ? Colors.green : scheme.onSurfaceVariant,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(p['name'] ?? '', style: const TextStyle(fontSize: 13)),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('使用中', style: TextStyle(fontSize: 10, color: Colors.green.shade800)),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          p['profession'] ?? '未设置职业',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => setState(() => selectedIndex = i),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),

        // 右侧：编辑+启用
        Expanded(
          child: profiles.isEmpty
              ? const Center(child: Text('创建一个人设开始使用'))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(tokens.spaceLg),
                  child: _buildEditor(context, tokens, scheme),
                ),
        ),
      ],
    );
  }

  Widget _buildEditor(BuildContext context, AppThemeTokens tokens, ColorScheme scheme) {
    final p = profiles[selectedIndex];
    final isActive = activeIndex == selectedIndex;
    final rules = (p['rules'] as List?)?.cast<String>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('编辑人设', style: Theme.of(context).textTheme.titleLarge),
            ),
            if (!isActive)
              FilledButton.icon(
                onPressed: () => _activate(selectedIndex),
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text('启用这个人设'),
              ),
            if (isActive)
              Chip(
                avatar: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                label: const Text('当前使用中'),
                backgroundColor: Colors.green.shade50,
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
              tooltip: '删除',
              onPressed: () => _deleteProfile(selectedIndex),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '设定一个职业身份，AI会用这个职业的专业知识回答问题',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        SizedBox(height: tokens.spaceLg),

        _field('人设名称', '给这个人设起个名字，方便区分', p['name'] ?? '', (v) { p['name'] = v; _save(); }),
        _field('AI名字', '对话中AI怎么自称', p['aiName'] ?? '', (v) { p['aiName'] = v; _save(); }),
        _field('职业', '如：产科医生、心理咨询师、律师、健身教练', p['profession'] ?? '', (v) { p['profession'] = v; _save(); }),
        _bigField('擅长领域 / 回答规则', '可以输入详细的专业领域描述、回答框架、注意事项等', p['expertise'] ?? '', (v) { p['expertise'] = v; _save(); }),
        _bigField('说话风格', '如：温柔耐心，用通俗的话解释专业问题，不吓人', p['style'] ?? '', (v) { p['style'] = v; _save(); }),
        _field('开场白', '第一次跟人聊天时说的话', p['greeting'] ?? '', (v) { p['greeting'] = v; _save(); }),

        SizedBox(height: tokens.spaceMd),
        Row(
          children: [
            Text('行为规则', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.primary)),
            const SizedBox(width: 8),
            Text(
              '如：不确定的说"建议就医确认"',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加'),
              onPressed: () {
                rules.add('');
                p['rules'] = rules;
                setState(() {});
                _save();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...List.generate(rules.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: rules[i],
                    decoration: InputDecoration(
                      hintText: '输入一条规则',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      prefixText: '${i + 1}. ',
                    ),
                    style: const TextStyle(fontSize: 14),
                    onChanged: (v) {
                      rules[i] = v;
                      p['rules'] = rules;
                      _save();
                    },
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, size: 18, color: Colors.red.shade300),
                  onPressed: () {
                    rules.removeAt(i);
                    p['rules'] = rules;
                    setState(() {});
                    _save();
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _bigField(String label, String hint, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        style: const TextStyle(fontSize: 13, height: 1.5),
        maxLines: null,
        minLines: 6,
        onChanged: onChanged,
      ),
    );
  }

  Widget _field(String label, String hint, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        style: const TextStyle(fontSize: 14),
        onChanged: onChanged,
      ),
    );
  }
}
