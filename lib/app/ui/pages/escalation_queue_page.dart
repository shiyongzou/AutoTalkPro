import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_context.dart';
import '../app_theme.dart';
import '../app_widgets.dart';
import '../../../core/models/escalation_alert.dart';
import '../../../features/notification/application/notification_service.dart';

class EscalationQueuePage extends StatefulWidget {
  const EscalationQueuePage({required this.appContext, super.key});

  final AppContext appContext;

  @override
  State<EscalationQueuePage> createState() => _EscalationQueuePageState();
}

class _EscalationQueuePageState extends State<EscalationQueuePage> {
  List<EscalationAlert> pendingAlerts = const [];
  List<EscalationAlert> allAlerts = const [];
  List<AppNotification> notifications = const [];
  StreamSubscription<AppNotification>? _notifSub;
  bool showAll = false;

  @override
  void initState() {
    super.initState();
    _load();
    _notifSub = widget.appContext.notificationService.stream.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final pending = await widget.appContext.escalationRepository.listPending();
    final all = await widget.appContext.escalationRepository.listAll();
    if (!mounted) return;
    setState(() {
      pendingAlerts = pending;
      allAlerts = all;
      notifications = widget.appContext.notificationService.history;
    });
  }

  Future<void> _resolve(EscalationAlert alert) async {
    await widget.appContext.escalationService.resolve(
      alertId: alert.id,
      resolvedBy: 'operator',
    );
    await _load();
  }

  Future<void> _dismiss(EscalationAlert alert) async {
    await widget.appContext.escalationService.dismiss(alert.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final displayAlerts = showAll ? allAlerts : pendingAlerts;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppPanelHeader(
            title: '升级队列',
            subtitle: '需要人工介入的会话在这里排队，按紧急程度排序，处理完点"已处理"。',
          ),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              SizedBox(
                width: 140,
                child: AppMetricTile(
                  label: '待处理',
                  value: '${pendingAlerts.length}',
                  tone: pendingAlerts.isEmpty
                      ? AppStatusTone.success
                      : AppStatusTone.danger,
                ),
              ),
              SizedBox(
                width: 140,
                child: AppMetricTile(
                  label: '总告警',
                  value: '${allAlerts.length}',
                ),
              ),
              SizedBox(
                width: 140,
                child: AppMetricTile(
                  label: '通知',
                  value: '${widget.appContext.notificationService.unreadCount}',
                  tone: widget.appContext.notificationService.unreadCount > 0
                      ? AppStatusTone.warning
                      : AppStatusTone.neutral,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Wrap(
            spacing: tokens.spaceSm,
            children: [
              FilterChip(
                label: const Text('待处理'),
                selected: !showAll,
                onSelected: (_) => setState(() => showAll = false),
              ),
              FilterChip(
                label: const Text('全部'),
                selected: showAll,
                onSelected: (_) => setState(() => showAll = true),
              ),
              OutlinedButton(onPressed: _load, child: const Text('刷新')),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Expanded(
            child: displayAlerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.green.shade300,
                        ),
                        const SizedBox(height: 8),
                        const Text('暂无待处理告警'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: displayAlerts.length,
                    itemBuilder: (context, index) {
                      final alert = displayAlerts[index];
                      return _AlertCard(
                        alert: alert,
                        onResolve: alert.isPending
                            ? () => _resolve(alert)
                            : null,
                        onDismiss: alert.isPending
                            ? () => _dismiss(alert)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, this.onResolve, this.onDismiss});

  final EscalationAlert alert;
  final VoidCallback? onResolve;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final priorityColor = _priorityColor(alert.priority);

    return Card(
      margin: EdgeInsets.only(bottom: tokens.spaceSm),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: priorityColor, width: 4)),
        ),
        padding: EdgeInsets.all(tokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_reasonIcon(alert.reason), size: 18, color: priorityColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: priorityColor,
                    ),
                  ),
                ),
                AppStatusTag(
                  label: _priorityLabel(alert.priority),
                  tone: _priorityTone(alert.priority),
                ),
                const SizedBox(width: 8),
                AppStatusTag(
                  label: _statusLabel(alert.status),
                  tone: alert.isPending
                      ? AppStatusTone.warning
                      : AppStatusTone.success,
                ),
              ],
            ),
            SizedBox(height: tokens.spaceSm),
            Text(alert.detail, style: const TextStyle(fontSize: 12)),
            SizedBox(height: tokens.spaceSm),
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 14,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    alert.suggestedAction,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            if (alert.isPending) ...[
              SizedBox(height: tokens.spaceSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text('忽略', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onResolve,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                    ),
                    child: const Text('已处理', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
            if (alert.resolvedBy != null)
              Text(
                '已由 ${alert.resolvedBy} 处理',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(EscalationPriority p) {
    switch (p) {
      case EscalationPriority.critical:
        return Colors.red.shade700;
      case EscalationPriority.high:
        return Colors.orange.shade700;
      case EscalationPriority.medium:
        return Colors.amber.shade700;
      case EscalationPriority.low:
        return Colors.grey;
    }
  }

  String _priorityLabel(EscalationPriority p) {
    switch (p) {
      case EscalationPriority.critical:
        return '紧急';
      case EscalationPriority.high:
        return '高';
      case EscalationPriority.medium:
        return '中';
      case EscalationPriority.low:
        return '低';
    }
  }

  AppStatusTone _priorityTone(EscalationPriority p) {
    switch (p) {
      case EscalationPriority.critical:
        return AppStatusTone.danger;
      case EscalationPriority.high:
        return AppStatusTone.danger;
      case EscalationPriority.medium:
        return AppStatusTone.warning;
      case EscalationPriority.low:
        return AppStatusTone.neutral;
    }
  }

  String _statusLabel(EscalationStatus s) {
    switch (s) {
      case EscalationStatus.pending:
        return '待处理';
      case EscalationStatus.acknowledged:
        return '已确认';
      case EscalationStatus.resolved:
        return '已处理';
      case EscalationStatus.dismissed:
        return '已忽略';
    }
  }

  IconData _reasonIcon(EscalationReason r) {
    switch (r) {
      case EscalationReason.riskDetected:
        return Icons.shield;
      case EscalationReason.highValueDeal:
        return Icons.attach_money;
      case EscalationReason.customerAngry:
        return Icons.mood_bad;
      case EscalationReason.authorityExceeded:
        return Icons.lock;
      case EscalationReason.complexNegotiation:
        return Icons.handshake;
      case EscalationReason.customerWaitingTooLong:
        return Icons.timer;
      case EscalationReason.priceFloorBreached:
        return Icons.trending_down;
      case EscalationReason.repeatedObjection:
        return Icons.replay;
      case EscalationReason.aiConfidenceLow:
        return Icons.psychology;
      case EscalationReason.manualRequest:
        return Icons.person;
    }
  }
}
