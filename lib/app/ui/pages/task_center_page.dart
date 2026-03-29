import 'package:flutter/material.dart';

import '../../app_context.dart';
import '../app_theme.dart';
import '../app_widgets.dart';
import '../../../core/models/conversation.dart';

class TaskCenterPage extends StatefulWidget {
  const TaskCenterPage({required this.appContext, super.key});

  final AppContext appContext;

  @override
  State<TaskCenterPage> createState() => _TaskCenterPageState();
}

class _TaskCenterPageState extends State<TaskCenterPage> {
  List<Conversation> conversations = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.appContext.conversationRepository
        .listConversations();
    if (!mounted) return;
    setState(() => conversations = rows);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;

    final active = conversations.where((c) => c.status == 'active').length;
    final closing = conversations.where((c) => c.goalStage == 'closing').length;
    final proposal = conversations
        .where((c) => c.goalStage == 'proposal')
        .length;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppPanelHeader(
            title: 'Task Center',
            subtitle: '销售漏斗任务追踪：按目标阶段查看全部跟进会话。',
          ),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              SizedBox(
                width: 140,
                child: AppMetricTile(
                  label: '会话总数',
                  value: '${conversations.length}',
                ),
              ),
              SizedBox(
                width: 140,
                child: AppMetricTile(
                  label: '进行中',
                  value: '$active',
                  tone: active > 0
                      ? AppStatusTone.success
                      : AppStatusTone.neutral,
                ),
              ),
              SizedBox(
                width: 140,
                child: AppMetricTile(
                  label: '报价阶段',
                  value: '$proposal',
                  tone: proposal > 0
                      ? AppStatusTone.warning
                      : AppStatusTone.neutral,
                ),
              ),
              SizedBox(
                width: 140,
                child: AppMetricTile(
                  label: '成交阶段',
                  value: '$closing',
                  tone: closing > 0
                      ? AppStatusTone.success
                      : AppStatusTone.neutral,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新任务统计'),
          ),
          SizedBox(height: tokens.spaceMd),
          Expanded(
            child: conversations.isEmpty
                ? const Center(
                    child: Text('暂无任务，先在 Conversation Center 创建示例会话'),
                  )
                : ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final c = conversations[index];
                      final stageTone = switch (c.goalStage) {
                        'closing' => AppStatusTone.success,
                        'proposal' => AppStatusTone.warning,
                        'discover' => AppStatusTone.neutral,
                        _ => AppStatusTone.neutral,
                      };
                      final stageLabel = switch (c.goalStage) {
                        'closing' => '成交阶段',
                        'proposal' => '报价阶段',
                        'discover' => '发现需求',
                        _ => c.goalStage,
                      };
                      final statusTone = c.status == 'active'
                          ? AppStatusTone.success
                          : AppStatusTone.neutral;
                      final updatedTime = c.updatedAt
                          .toLocal()
                          .toString()
                          .substring(0, 16);
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.task_alt_outlined),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: tokens.spaceSm),
                            AppStatusTag(label: stageLabel, tone: stageTone),
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            AppStatusTag(
                              label: c.status == 'active' ? '进行中' : c.status,
                              tone: statusTone,
                            ),
                            SizedBox(width: tokens.spaceSm),
                            Text(
                              '客户: ${c.customerId}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: Text(
                          updatedTime,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
