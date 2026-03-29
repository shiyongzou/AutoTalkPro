import 'dart:async';

import '../../../core/models/escalation_alert.dart';

/// 通知事件类型
enum NotificationType {
  escalation,
  dealClosing,
  riskAlert,
  customerWaiting,
  autopilotHold,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.priority,
    required this.conversationId,
    this.actionLabel,
    required this.createdAt,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final EscalationPriority priority;
  final String conversationId;
  final String? actionLabel;
  final DateTime createdAt;
}

/// 应用内通知服务 — 通过 Stream 推送给 UI
class NotificationService {
  final _controller = StreamController<AppNotification>.broadcast();
  final List<AppNotification> _history = [];

  Stream<AppNotification> get stream => _controller.stream;
  List<AppNotification> get history => List.unmodifiable(_history);
  int get unreadCount => _history.where((n) => !_readIds.contains(n.id)).length;

  final Set<String> _readIds = {};

  void notify(AppNotification notification) {
    _history.insert(0, notification);
    // 最多保留100条，同步清理已读ID
    while (_history.length > 100) {
      final removed = _history.removeLast();
      _readIds.remove(removed.id);
    }
    _controller.add(notification);
  }

  void markRead(String id) {
    _readIds.add(id);
  }

  void markAllRead() {
    for (final n in _history) {
      _readIds.add(n.id);
    }
  }

  /// 从升级告警生成通知
  void notifyFromEscalation(EscalationAlert alert) {
    notify(AppNotification(
      id: 'notif_${alert.id}',
      type: NotificationType.escalation,
      title: _priorityEmoji(alert.priority) + alert.title,
      body: alert.suggestedAction,
      priority: alert.priority,
      conversationId: alert.conversationId,
      actionLabel: '查看会话',
      createdAt: DateTime.now(),
    ));
  }

  /// autopilot hold 通知
  void notifyAutopilotHold({
    required String conversationId,
    required String reason,
  }) {
    notify(AppNotification(
      id: 'notif_hold_${DateTime.now().microsecondsSinceEpoch}',
      type: NotificationType.autopilotHold,
      title: '需要人工审核',
      body: reason,
      priority: EscalationPriority.medium,
      conversationId: conversationId,
      actionLabel: '审核回复',
      createdAt: DateTime.now(),
    ));
  }

  String _priorityEmoji(EscalationPriority priority) {
    switch (priority) {
      case EscalationPriority.critical:
        return '[紧急] ';
      case EscalationPriority.high:
        return '[高] ';
      case EscalationPriority.medium:
        return '[中] ';
      case EscalationPriority.low:
        return '';
    }
  }

  void dispose() {
    _controller.close();
  }
}
