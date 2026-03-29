import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_context.dart';
import '../app_theme.dart';
import '../app_widgets.dart';
import '../../../core/models/script_template.dart';

class ScriptLibraryPage extends StatefulWidget {
  const ScriptLibraryPage({required this.appContext, super.key});

  final AppContext appContext;

  @override
  State<ScriptLibraryPage> createState() => _ScriptLibraryPageState();
}

class _ScriptLibraryPageState extends State<ScriptLibraryPage> {
  List<ScriptTemplate> scripts = const [];
  SalesScriptCategory? filterCategory;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = filterCategory == null
        ? await widget.appContext.scriptRepository.listAll()
        : await widget.appContext.scriptRepository.listByCategory(
            filterCategory!,
          );
    if (!mounted) return;
    setState(() => scripts = rows);
  }

  Future<void> _showForm({ScriptTemplate? existing}) async {
    final titleCtl = TextEditingController(text: existing?.title ?? '');
    final contentCtl = TextEditingController(text: existing?.content ?? '');
    final tagsCtl = TextEditingController(text: existing?.tags.join('、') ?? '');
    SalesScriptCategory category =
        existing?.category ?? SalesScriptCategory.custom;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setFormState) => AlertDialog(
          title: Text(existing == null ? '新增话术' : '编辑话术'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: titleCtl,
                        decoration: const InputDecoration(
                          labelText: '标题 *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<SalesScriptCategory>(
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: '分类',
                          border: OutlineInputBorder(),
                        ),
                        items: SalesScriptCategory.values
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  _categoryLabel(c),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setFormState(() => category = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtl,
                  decoration: const InputDecoration(
                    labelText: '话术内容 *',
                    hintText: '支持变量: {客户名} {产品} {价格}',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagsCtl,
                  decoration: const InputDecoration(
                    labelText: '标签(顿号分隔)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtl.text.trim().isEmpty ||
                    contentCtl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(const SnackBar(content: Text('标题和内容不能为空')));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final now = DateTime.now();
    final tags = tagsCtl.text
        .trim()
        .split(RegExp(r'[、,，]'))
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
    final script = ScriptTemplate(
      id: existing?.id ?? 'script_${now.microsecondsSinceEpoch}',
      category: category,
      title: titleCtl.text.trim(),
      content: contentCtl.text.trim(),
      tags: tags,
      useCount: existing?.useCount ?? 0,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await widget.appContext.scriptRepository.upsert(script);
    await _load();
  }

  Future<void> _delete(ScriptTemplate script) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除话术"${script.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await widget.appContext.scriptRepository.delete(script.id);
    await _load();
  }

  void _copyToClipboard(ScriptTemplate script) {
    Clipboard.setData(ClipboardData(text: script.content));
    widget.appContext.scriptRepository.incrementUseCount(script.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制: ${script.title}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppPanelHeader(
            title: '话术库',
            subtitle: '常用话术管理，点击即可复制到剪贴板，也可在对话中一键插入。',
          ),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              SizedBox(
                width: 120,
                child: AppMetricTile(label: '总话术', value: '${scripts.length}'),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceSm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('全部', style: TextStyle(fontSize: 11)),
                  selected: filterCategory == null,
                  onSelected: (_) {
                    setState(() => filterCategory = null);
                    _load();
                  },
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                ...SalesScriptCategory.values.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(
                        _categoryLabel(c),
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: filterCategory == c,
                      onSelected: (_) {
                        setState(() => filterCategory = c);
                        _load();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: '新增一条常用话术',
                  child: FilledButton.icon(
                    onPressed: () => _showForm(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('新增话术'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.spaceMd),
          Expanded(
            child: scripts.isEmpty
                ? const Center(child: Text('暂无话术，点击"新增话术"添加常用回复模板'))
                : ListView.builder(
                    itemCount: scripts.length,
                    itemBuilder: (context, index) {
                      final s = scripts[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: tokens.spaceSm),
                        child: ListTile(
                          leading: Tooltip(
                            message: '点击复制到剪贴板',
                            child: IconButton(
                              icon: const Icon(Icons.content_copy, size: 18),
                              onPressed: () => _copyToClipboard(s),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                s.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AppStatusTag(label: s.categoryLabel),
                              if (s.useCount > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '使用${s.useCount}次',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            s.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: '编辑此话术',
                                child: IconButton(
                                  icon: const Icon(Icons.edit, size: 16),
                                  onPressed: () => _showForm(existing: s),
                                ),
                              ),
                              Tooltip(
                                message: '删除此话术',
                                child: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: Colors.red.shade300,
                                  ),
                                  onPressed: () => _delete(s),
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _copyToClipboard(s),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(SalesScriptCategory c) {
    switch (c) {
      case SalesScriptCategory.greeting:
        return '开场白';
      case SalesScriptCategory.quote:
        return '报价';
      case SalesScriptCategory.objection:
        return '异议处理';
      case SalesScriptCategory.closing:
        return '成交';
      case SalesScriptCategory.followUp:
        return '跟进';
      case SalesScriptCategory.afterSales:
        return '售后';
      case SalesScriptCategory.custom:
        return '自定义';
    }
  }
}
