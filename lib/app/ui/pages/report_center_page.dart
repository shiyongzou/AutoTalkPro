import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app_context.dart';
import '../app_theme.dart';
import '../app_widgets.dart';
import '../charts/report_charts.dart';
import '../../../core/models/audit_log.dart';
import '../../../core/models/industry_market_intel.dart';
import '../../../features/release/application/release_gate_service.dart';
import '../../../features/report/application/report_generator_service.dart';

class ReportCenterPage extends StatefulWidget {
  const ReportCenterPage({required this.appContext, super.key});

  final AppContext appContext;

  @override
  State<ReportCenterPage> createState() => _ReportCenterPageState();
}

class _ReportCenterPageState extends State<ReportCenterPage> {
  ReportSummary? summary;
  ReleaseGateResult? gateResult;
  List<IndustryMarketIntel> intelList = const [];
  List<AuditLog> auditLogs = const [];
  String? lastGateExportPath;
  String? lastGateMarkdownExportPath;
  String? lastReportJsonExportPath;
  String? lastReportMarkdownExportPath;
  bool loadingAudit = false;

  final TextEditingController _auditConversationController =
      TextEditingController();
  final TextEditingController _auditRequestController = TextEditingController();
  String _auditStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadAudit();
  }

  @override
  void dispose() {
    _auditConversationController.dispose();
    _auditRequestController.dispose();
    super.dispose();
  }

  Future<void> _generate(ReportPeriod period) async {
    final result = await widget.appContext.reportGenerator.build(period);
    final intel = await widget.appContext.knowledgeCenterRepository.listIntel();
    if (!mounted) return;
    setState(() {
      summary = result;
      intelList = intel;
    });
  }

  Future<void> _loadAudit() async {
    setState(() => loadingAudit = true);

    final logs = await widget.appContext.auditRepository.query(
      AuditQuery(
        conversationId: _auditConversationController.text.trim().isEmpty
            ? null
            : _auditConversationController.text.trim(),
        requestId: _auditRequestController.text.trim().isEmpty
            ? null
            : _auditRequestController.text.trim(),
        status: _auditStatusFilter == 'all' ? null : _auditStatusFilter,
        limit: 80,
      ),
    );

    if (!mounted) return;
    setState(() {
      auditLogs = logs;
      loadingAudit = false;
    });
  }

  Future<void> _runCommercialGate() async {
    final result = await widget.appContext.releaseGateService.evaluate(
      channelManager: widget.appContext.channelManager,
      telegramConfig: widget.appContext.telegramConfig,
      weComConfig: widget.appContext.weComConfig,
      qaEnabled: true,
      dispatchIdempotencyEnabled: true,
      auditEnabled: true,
    );
    if (!mounted) return;
    setState(() {
      gateResult = result;
    });
  }

  Future<void> _exportGateReport() async {
    if (gateResult == null) {
      _showSnack('请先运行商用门禁自检，再导出报告。');
      return;
    }

    const jsonType = XTypeGroup(label: 'json', extensions: ['json']);
    final location = await getSaveLocation(
      acceptedTypeGroups: const [jsonType],
      suggestedName: 'latest_gate.json',
      confirmButtonText: '导出',
    );
    if (location == null) return;

    final target = File(location.path);
    await target.parent.create(recursive: true);
    await target.writeAsString(
      gateResult!.toCommercialReportPrettyJson(
        ciStatus: 'manual',
        ciDetail: 'exported_from_report_center',
      ),
    );

    if (!mounted) return;
    setState(() => lastGateExportPath = target.path);
    _showSnack('门禁 JSON 已导出: ${target.path}');
  }

  Future<void> _exportGateMarkdown() async {
    if (gateResult == null) {
      _showSnack('请先运行商用门禁自检，再导出报告。');
      return;
    }

    const markdownType = XTypeGroup(label: 'markdown', extensions: ['md']);
    final location = await getSaveLocation(
      acceptedTypeGroups: const [markdownType],
      suggestedName: 'latest_gate.md',
      confirmButtonText: '导出',
    );
    if (location == null) return;

    final target = File(location.path);
    await target.parent.create(recursive: true);
    await target.writeAsString(
      gateResult!.toMarkdownSummary(
        ciStatus: 'manual',
        ciDetail: 'exported_from_report_center',
      ),
    );

    if (!mounted) return;
    setState(() => lastGateMarkdownExportPath = target.path);
    _showSnack('门禁 Markdown 已导出: ${target.path}');
  }

  Future<void> _exportReportJson() async {
    if (summary == null) {
      _showSnack('请先生成日报/周报/月报，再导出 JSON。');
      return;
    }

    const jsonType = XTypeGroup(label: 'json', extensions: ['json']);
    final location = await getSaveLocation(
      acceptedTypeGroups: const [jsonType],
      suggestedName: 'report_summary_${summary!.period.name}.json',
      confirmButtonText: '导出',
    );
    if (location == null) return;

    final target = File(location.path);
    await target.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await target.writeAsString(encoder.convert(summary!.toJson()));

    if (!mounted) return;
    setState(() => lastReportJsonExportPath = target.path);
    _showSnack('报告 JSON 已导出: ${target.path}');
  }

  Future<void> _exportReportMarkdown() async {
    if (summary == null) {
      _showSnack('请先生成日报/周报/月报，再导出 Markdown。');
      return;
    }

    const markdownType = XTypeGroup(label: 'markdown', extensions: ['md']);
    final location = await getSaveLocation(
      acceptedTypeGroups: const [markdownType],
      suggestedName: 'report_summary_${summary!.period.name}.md',
      confirmButtonText: '导出',
    );
    if (location == null) return;

    final target = File(location.path);
    await target.parent.create(recursive: true);
    await target.writeAsString(summary!.toMarkdown());

    if (!mounted) return;
    setState(() => lastReportMarkdownExportPath = target.path);
    _showSnack('报告 Markdown 已导出: ${target.path}');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppPanelHeader(
            title: 'Report Center',
            subtitle: '报告生成、商用门禁检查与导出统一操作面板。',
          ),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              SizedBox(
                width: 160,
                child: AppMetricTile(
                  label: '门禁状态',
                  value: gateResult == null
                      ? '未检查'
                      : (gateResult!.passed ? '通过' : '阻断'),
                  tone: gateResult == null
                      ? AppStatusTone.neutral
                      : (gateResult!.passed
                            ? AppStatusTone.success
                            : AppStatusTone.danger),
                ),
              ),
              SizedBox(
                width: 160,
                child: AppMetricTile(
                  label: '报告周期',
                  value: summary == null ? '未生成' : '已生成',
                  tone: summary == null
                      ? AppStatusTone.neutral
                      : AppStatusTone.success,
                ),
              ),
              SizedBox(
                width: 160,
                child: AppMetricTile(
                  label: '情报条数',
                  value: '${intelList.length}',
                ),
              ),
              SizedBox(
                width: 160,
                child: AppMetricTile(
                  label: '审计记录',
                  value: loadingAudit ? '加载中' : '${auditLogs.length}',
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Wrap(
            spacing: tokens.spaceMd,
            runSpacing: tokens.spaceSm,
            children: [
              FilledButton(
                onPressed: () => _generate(ReportPeriod.daily),
                child: const Text('生成日报'),
              ),
              FilledButton(
                onPressed: () => _generate(ReportPeriod.weekly),
                child: const Text('生成周报'),
              ),
              FilledButton(
                onPressed: () => _generate(ReportPeriod.monthly),
                child: const Text('生成月报'),
              ),
              OutlinedButton.icon(
                onPressed: _runCommercialGate,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('运行商用门禁自检'),
              ),
              OutlinedButton.icon(
                onPressed: gateResult == null ? null : _exportGateReport,
                icon: const Icon(Icons.download_outlined),
                label: const Text('导出门禁JSON'),
              ),
              OutlinedButton.icon(
                onPressed: gateResult == null ? null : _exportGateMarkdown,
                icon: const Icon(Icons.description_outlined),
                label: const Text('导出门禁Markdown'),
              ),
              OutlinedButton.icon(
                onPressed: summary == null ? null : _exportReportJson,
                icon: const Icon(Icons.data_object_outlined),
                label: const Text('导出报告JSON'),
              ),
              OutlinedButton.icon(
                onPressed: summary == null ? null : _exportReportMarkdown,
                icon: const Icon(Icons.description_outlined),
                label: const Text('导出Markdown摘要'),
              ),
              OutlinedButton.icon(
                onPressed: loadingAudit ? null : _loadAudit,
                icon: const Icon(Icons.manage_search_outlined),
                label: const Text('刷新审计查询'),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          if (gateResult != null) ReleaseGateCard(result: gateResult!),
          if (lastGateExportPath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppStatusTag(
                label: '已导出门禁JSON: $lastGateExportPath',
                tone: AppStatusTone.success,
              ),
            ),
          if (lastGateMarkdownExportPath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppStatusTag(
                label: '已导出门禁Markdown: $lastGateMarkdownExportPath',
                tone: AppStatusTone.success,
              ),
            ),
          if (lastReportJsonExportPath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppStatusTag(
                label: '已导出报告JSON: $lastReportJsonExportPath',
                tone: AppStatusTone.success,
              ),
            ),
          if (lastReportMarkdownExportPath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppStatusTag(
                label: '已导出Markdown摘要: $lastReportMarkdownExportPath',
                tone: AppStatusTone.success,
              ),
            ),
          AppSurfaceCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('审计检索', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _auditConversationController,
                        decoration: const InputDecoration(
                          labelText: 'conversationId（可选）',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _auditRequestController,
                        decoration: const InputDecoration(
                          labelText: 'requestId（可选）',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _auditStatusFilter,
                        decoration: const InputDecoration(labelText: '状态'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('全部')),
                          DropdownMenuItem(
                            value: 'check',
                            child: Text('check'),
                          ),
                          DropdownMenuItem(value: 'pass', child: Text('pass')),
                          DropdownMenuItem(
                            value: 'blocked',
                            child: Text('blocked'),
                          ),
                          DropdownMenuItem(
                            value: 'success',
                            child: Text('success'),
                          ),
                          DropdownMenuItem(
                            value: 'failed',
                            child: Text('failed'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _auditStatusFilter = value ?? 'all');
                        },
                      ),
                    ),
                    FilledButton(
                      onPressed: loadingAudit ? null : _loadAudit,
                      child: const Text('查询'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: loadingAudit
                      ? const Center(child: CircularProgressIndicator())
                      : auditLogs.isEmpty
                      ? const Center(child: Text('暂无匹配审计记录'))
                      : ListView.separated(
                          itemCount: auditLogs.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final log = auditLogs[index];
                            final meta = [
                              if (log.requestId != null)
                                'requestId=${log.requestId}',
                              if (log.operator != null)
                                'operator=${log.operator}',
                              if (log.channel != null) 'channel=${log.channel}',
                              if (log.templateVersion != null)
                                'template=${log.templateVersion}',
                              if (log.model != null) 'model=${log.model}',
                              if (log.latencyMs != null)
                                'latency=${log.latencyMs}ms',
                            ].join(' · ');

                            return ListTile(
                              dense: true,
                              title: Text('${log.stage} / ${log.status}'),
                              subtitle: Text(
                                '${log.conversationId} · ${log.createdAt.toLocal()}${meta.isEmpty ? '' : '\n$meta'}',
                              ),
                              isThreeLine: meta.isNotEmpty,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (summary == null)
            const Expanded(child: Center(child: Text('请选择报告周期，生成统计结果。')))
          else
            Expanded(
              child: ListView(
                children: [
                  Text('生成时间: ${summary!.generatedAt.toLocal()}'),
                  SizedBox(height: tokens.spaceSm),
                  KpiBarChart(summary: summary!),
                  SizedBox(height: tokens.spaceLg),
                  ConversationPieChart(summary: summary!),
                  SizedBox(height: tokens.spaceLg),
                  StageFunnelChart(summary: summary!),
                  SizedBox(height: tokens.spaceLg),
                  OperationsFunnelCard(summary: summary!),
                  SizedBox(height: tokens.spaceLg),
                  RiskTrendLineChart(summary: summary!),
                  SizedBox(height: tokens.spaceLg),
                  TopRiskConversationCard(summary: summary!),
                  SizedBox(height: tokens.spaceLg),
                  TopRiskCustomerCard(summary: summary!),
                  SizedBox(height: tokens.spaceLg),
                  KnowledgeIntelSummaryCard(intelList: intelList),
                  SizedBox(height: tokens.spaceLg),
                  ReportSnapshotCard(summary: summary!),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
