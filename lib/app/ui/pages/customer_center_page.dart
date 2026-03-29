import 'package:flutter/material.dart';

import '../../app_context.dart';
import '../app_theme.dart';
import '../app_widgets.dart';
import '../../../core/models/customer_profile.dart';

class CustomerCenterPage extends StatefulWidget {
  const CustomerCenterPage({required this.appContext, super.key});

  final AppContext appContext;

  @override
  State<CustomerCenterPage> createState() => _CustomerCenterPageState();
}

class _CustomerCenterPageState extends State<CustomerCenterPage> {
  List<CustomerProfile> customers = const [];
  CustomerProfile? selectedCustomer;
  String searchQuery = '';
  String filterSegment = 'all';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await widget.appContext.conversationRepository.listCustomers();
    if (!mounted) return;
    setState(() => customers = rows);
  }

  List<CustomerProfile> get filteredCustomers {
    var result = customers;
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((c) =>
        c.name.toLowerCase().contains(q) ||
        (c.company?.toLowerCase().contains(q) ?? false) ||
        (c.email?.toLowerCase().contains(q) ?? false) ||
        (c.phone?.contains(q) ?? false)
      ).toList();
    }
    if (filterSegment != 'all') {
      result = result.where((c) => c.segment == filterSegment).toList();
    }
    return result;
  }

  Future<void> _showCustomerForm({CustomerProfile? existing}) async {
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final companyCtl = TextEditingController(text: existing?.company ?? '');
    final emailCtl = TextEditingController(text: existing?.email ?? '');
    final phoneCtl = TextEditingController(text: existing?.phone ?? '');
    final industryCtl = TextEditingController(text: existing?.industry ?? '');
    final notesCtl = TextEditingController(text: existing?.notes ?? '');
    String segment = existing?.segment ?? '中意向';
    String lifeCycle = existing?.lifeCycleStage ?? 'lead';
    String budgetLevel = existing?.budgetLevel ?? 'medium';
    bool isDecisionMaker = existing?.isDecisionMaker ?? false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setFormState) => AlertDialog(
          title: Text(existing == null ? '新增客户' : '编辑客户'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtl, decoration: const InputDecoration(labelText: '姓名 *', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: companyCtl, decoration: const InputDecoration(labelText: '公司', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: emailCtl, decoration: const InputDecoration(labelText: '邮箱', border: OutlineInputBorder()))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: phoneCtl, decoration: const InputDecoration(labelText: '电话', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: industryCtl, decoration: const InputDecoration(labelText: '行业', border: OutlineInputBorder()))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: segment,
                          decoration: const InputDecoration(labelText: '意向度', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: '高意向', child: Text('高意向')),
                            DropdownMenuItem(value: '中意向', child: Text('中意向')),
                            DropdownMenuItem(value: '低意向', child: Text('低意向')),
                            DropdownMenuItem(value: '已成交', child: Text('已成交')),
                            DropdownMenuItem(value: '已流失', child: Text('已流失')),
                          ],
                          onChanged: (v) { if (v != null) setFormState(() => segment = v); },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: lifeCycle,
                          decoration: const InputDecoration(labelText: '生命周期', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'lead', child: Text('线索')),
                            DropdownMenuItem(value: 'prospect', child: Text('意向')),
                            DropdownMenuItem(value: 'opportunity', child: Text('商机')),
                            DropdownMenuItem(value: 'customer', child: Text('客户')),
                            DropdownMenuItem(value: 'churned', child: Text('流失')),
                          ],
                          onChanged: (v) { if (v != null) setFormState(() => lifeCycle = v); },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: budgetLevel,
                          decoration: const InputDecoration(labelText: '预算等级', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('低')),
                            DropdownMenuItem(value: 'medium', child: Text('中')),
                            DropdownMenuItem(value: 'high', child: Text('高')),
                            DropdownMenuItem(value: 'enterprise', child: Text('企业级')),
                          ],
                          onChanged: (v) { if (v != null) setFormState(() => budgetLevel = v); },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('决策人'),
                    value: isDecisionMaker,
                    onChanged: (v) => setFormState(() => isDecisionMaker = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  TextField(
                    controller: notesCtl,
                    decoration: const InputDecoration(labelText: '备注', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (nameCtl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('姓名不能为空')),
                  );
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
    final profile = CustomerProfile(
      id: existing?.id ?? 'cust_${now.microsecondsSinceEpoch}',
      name: nameCtl.text.trim(),
      segment: segment,
      tags: existing?.tags ?? const [],
      lastContactAt: existing?.lastContactAt ?? now,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      company: companyCtl.text.trim().isEmpty ? null : companyCtl.text.trim(),
      email: emailCtl.text.trim().isEmpty ? null : emailCtl.text.trim(),
      phone: phoneCtl.text.trim().isEmpty ? null : phoneCtl.text.trim(),
      industry: industryCtl.text.trim().isEmpty ? null : industryCtl.text.trim(),
      budgetLevel: budgetLevel,
      isDecisionMaker: isDecisionMaker,
      lifeCycleStage: lifeCycle,
      riskScore: existing?.riskScore ?? 0,
      notes: notesCtl.text.trim().isEmpty ? null : notesCtl.text.trim(),
      preferredChannel: existing?.preferredChannel,
      totalRevenue: existing?.totalRevenue ?? 0,
    );

    await widget.appContext.conversationRepository.upsertCustomer(profile);
    await _load();
    if (mounted && selectedCustomer?.id == profile.id) {
      setState(() => selectedCustomer = profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final filtered = filteredCustomers;
    final highIntent = customers.where((c) => c.segment == '高意向').length;
    final decisionMakers = customers.where((c) => c.isDecisionMaker).length;
    final totalRevenue = customers.fold<double>(0, (s, c) => s + c.totalRevenue);

    return Row(
      children: [
        // 左侧: 客户列表
        SizedBox(
          width: 320,
          child: AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(tokens.spaceMd),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('客户中心', style: Theme.of(context).textTheme.titleSmall),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.person_add, size: 20),
                            tooltip: '新增客户',
                            onPressed: () => _showCustomerForm(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            onPressed: _load,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '搜索客户...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 13),
                        onChanged: (v) => setState(() => searchQuery = v),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final seg in ['all', '高意向', '中意向', '低意向', '已成交', '已流失'])
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: FilterChip(
                                  label: Text(seg == 'all' ? '全部' : seg, style: const TextStyle(fontSize: 11)),
                                  selected: filterSegment == seg,
                                  onSelected: (_) => setState(() => filterSegment = seg),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 指标
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd),
                  child: Wrap(
                    spacing: tokens.spaceSm,
                    runSpacing: tokens.spaceSm,
                    children: [
                      _MiniMetric(label: '总数', value: '${customers.length}'),
                      _MiniMetric(label: '高意向', value: '$highIntent', color: Colors.green),
                      _MiniMetric(label: '决策人', value: '$decisionMakers', color: Colors.blue),
                      _MiniMetric(label: '总营收', value: '¥${totalRevenue.toStringAsFixed(0)}', color: Colors.orange),
                    ],
                  ),
                ),
                SizedBox(height: tokens.spaceSm),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('暂无客户', style: TextStyle(fontSize: 12)))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final c = filtered[index];
                            final isSelected = selectedCustomer?.id == c.id;
                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: _segmentColor(c.segment).withValues(alpha: 0.2),
                                child: Text(
                                  c.name.isNotEmpty ? c.name[0] : '?',
                                  style: TextStyle(fontSize: 12, color: _segmentColor(c.segment)),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(c.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                  ),
                                  if (c.isDecisionMaker)
                                    Icon(Icons.verified, size: 14, color: Colors.blue.shade400),
                                ],
                              ),
                              subtitle: Text(
                                [c.company, c.segment].where((s) => s != null && s.isNotEmpty).join(' · '),
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () => setState(() => selectedCustomer = c),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: tokens.spaceSm),

        // 右侧: 客户详情
        Expanded(
          child: selectedCustomer == null
              ? const AppSurfaceCard(child: Center(child: Text('选择客户查看详情')))
              : AppSurfaceCard(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(tokens.spaceLg),
                    child: _buildCustomerDetail(context, tokens, selectedCustomer!),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCustomerDetail(BuildContext context, AppThemeTokens tokens, CustomerProfile c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _segmentColor(c.segment).withValues(alpha: 0.2),
              child: Text(c.name.isNotEmpty ? c.name[0] : '?',
                  style: TextStyle(fontSize: 24, color: _segmentColor(c.segment))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(c.name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(width: 8),
                      AppStatusTag(label: c.segment, tone: _segmentTone(c.segment)),
                      if (c.isDecisionMaker) ...[
                        const SizedBox(width: 8),
                        const AppStatusTag(label: '决策人', tone: AppStatusTone.success),
                      ],
                    ],
                  ),
                  if (c.company != null)
                    Text(c.company!, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showCustomerForm(existing: c),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('编辑'),
            ),
          ],
        ),
        SizedBox(height: tokens.spaceLg),

        // 信息卡片网格
        Wrap(
          spacing: tokens.spaceMd,
          runSpacing: tokens.spaceMd,
          children: [
            _InfoCard(icon: Icons.email, label: '邮箱', value: c.email ?? '-'),
            _InfoCard(icon: Icons.phone, label: '电话', value: c.phone ?? '-'),
            _InfoCard(icon: Icons.business, label: '行业', value: c.industry ?? '-'),
            _InfoCard(icon: Icons.account_balance_wallet, label: '预算级别', value: _budgetLabel(c.budgetLevel)),
            _InfoCard(icon: Icons.timeline, label: '生命周期', value: _lifeCycleLabel(c.lifeCycleStage)),
            _InfoCard(icon: Icons.attach_money, label: '累计营收', value: '¥${c.totalRevenue.toStringAsFixed(0)}'),
            _InfoCard(icon: Icons.shield, label: '风险评分', value: '${c.riskScore}/100'),
            _InfoCard(icon: Icons.access_time, label: '最近联系', value: c.lastContactAt?.toLocal().toString().substring(0, 10) ?? '-'),
          ],
        ),

        if (c.notes != null && c.notes!.isNotEmpty) ...[
          SizedBox(height: tokens.spaceLg),
          Text('备注', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: tokens.spaceSm),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(tokens.spaceMd),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(c.notes!, style: const TextStyle(fontSize: 13)),
          ),
        ],

        if (c.tags.isNotEmpty) ...[
          SizedBox(height: tokens.spaceLg),
          Text('标签', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: tokens.spaceSm),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: c.tags.map((t) => Chip(
              label: Text(t, style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
            )).toList(),
          ),
        ],
      ],
    );
  }

  Color _segmentColor(String segment) {
    switch (segment) {
      case '高意向': return Colors.green;
      case '中意向': return Colors.orange;
      case '低意向': return Colors.grey;
      case '已成交': return Colors.blue;
      case '已流失': return Colors.red;
      default: return Colors.grey;
    }
  }

  AppStatusTone _segmentTone(String segment) {
    switch (segment) {
      case '高意向': return AppStatusTone.success;
      case '中意向': return AppStatusTone.warning;
      case '已成交': return AppStatusTone.success;
      case '已流失': return AppStatusTone.danger;
      default: return AppStatusTone.neutral;
    }
  }

  String _budgetLabel(String? level) {
    switch (level) {
      case 'low': return '低';
      case 'medium': return '中';
      case 'high': return '高';
      case 'enterprise': return '企业级';
      default: return '-';
    }
  }

  String _lifeCycleLabel(String stage) {
    switch (stage) {
      case 'lead': return '线索';
      case 'prospect': return '意向';
      case 'opportunity': return '商机';
      case 'customer': return '客户';
      case 'churned': return '流失';
      default: return stage;
    }
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
