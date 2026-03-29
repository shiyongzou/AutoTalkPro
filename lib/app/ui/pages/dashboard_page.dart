import 'package:flutter/material.dart';

import '../../app_context.dart';
import '../app_theme.dart';
import '../app_widgets.dart';
import '../../../core/models/order.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({required this.appContext, super.key});

  final AppContext appContext;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // 统计数据
  int totalConversations = 0;
  int totalCustomers = 0;
  int totalOrders = 0;
  int activeOrders = 0;
  int pendingEscalations = 0;
  double totalRevenue = 0;
  int completedOrders = 0;
  int cancelledOrders = 0;
  List<Order> recentOrders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final conversations = await widget.appContext.conversationRepository
        .listConversations();
    final customers = await widget.appContext.conversationRepository
        .listCustomers();
    final orders = await widget.appContext.orderRepository.listAll();
    final activeOrd = await widget.appContext.orderRepository.activeCount();
    final pendingEsc = await widget.appContext.escalationRepository
        .pendingCount();

    final revenue = orders
        .where(
          (o) =>
              o.status == OrderStatus.completed ||
              o.status == OrderStatus.delivered ||
              o.status == OrderStatus.paid,
        )
        .fold<double>(0, (s, o) => s + o.totalAmount);
    final completed = orders
        .where((o) => o.status == OrderStatus.completed)
        .length;
    final cancelled = orders
        .where((o) => o.status == OrderStatus.cancelled)
        .length;

    if (!mounted) return;
    setState(() {
      totalConversations = conversations.length;
      totalCustomers = customers.length;
      totalOrders = orders.length;
      activeOrders = activeOrd;
      pendingEscalations = pendingEsc;
      totalRevenue = revenue;
      completedOrders = completed;
      cancelledOrders = cancelled;
      recentOrders = orders.take(10).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final closeRate = totalOrders > 0
        ? (completedOrders / totalOrders * 100).toStringAsFixed(1)
        : '0.0';

    return AppSurfaceCard(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPanelHeader(title: '数据大盘', subtitle: '实时业务概览，一眼掌握核心指标。'),

            // 核心指标卡片
            Wrap(
              spacing: tokens.spaceMd,
              runSpacing: tokens.spaceMd,
              children: [
                _MetricCard(
                  icon: Icons.attach_money,
                  label: '总营收',
                  value: '¥${totalRevenue.toStringAsFixed(0)}',
                  color: Colors.green,
                  tooltip: '所有已付款/已交付/已完成订单的总金额',
                ),
                _MetricCard(
                  icon: Icons.receipt_long,
                  label: '总订单',
                  value: '$totalOrders',
                  color: Colors.blue,
                  tooltip: '所有订单数量（含已取消）',
                ),
                _MetricCard(
                  icon: Icons.check_circle,
                  label: '成交率',
                  value: '$closeRate%',
                  color: Colors.teal,
                  tooltip: '已完成订单 / 总订单数',
                ),
                _MetricCard(
                  icon: Icons.chat_bubble,
                  label: '总会话',
                  value: '$totalConversations',
                  color: Colors.purple,
                  tooltip: '所有对话会话数量',
                ),
                _MetricCard(
                  icon: Icons.people,
                  label: '总客户',
                  value: '$totalCustomers',
                  color: Colors.orange,
                  tooltip: '客户画像数量',
                ),
                _MetricCard(
                  icon: Icons.trending_up,
                  label: '进行中订单',
                  value: '$activeOrders',
                  color: Colors.amber,
                  tooltip: '待确认/待付款/待交付的订单',
                ),
                _MetricCard(
                  icon: Icons.warning_amber,
                  label: '待处理告警',
                  value: '$pendingEscalations',
                  color: pendingEscalations > 0 ? Colors.red : Colors.grey,
                  tooltip: '需要人工介入的升级告警',
                ),
                _MetricCard(
                  icon: Icons.cancel,
                  label: '取消订单',
                  value: '$cancelledOrders',
                  color: Colors.red.shade300,
                  tooltip: '已取消的订单数',
                ),
              ],
            ),
            SizedBox(height: tokens.spaceLg),

            // 转化漏斗
            Tooltip(
              message: '从获客到成交的转化路径',
              child: Text(
                '转化漏斗',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            SizedBox(height: tokens.spaceSm),
            _FunnelBar(
              label: '客户',
              count: totalCustomers,
              maxCount: totalCustomers,
              color: Colors.blue,
            ),
            _FunnelBar(
              label: '会话',
              count: totalConversations,
              maxCount: totalCustomers,
              color: Colors.purple,
            ),
            _FunnelBar(
              label: '订单',
              count: totalOrders,
              maxCount: totalCustomers,
              color: Colors.orange,
            ),
            _FunnelBar(
              label: '成交',
              count: completedOrders,
              maxCount: totalCustomers,
              color: Colors.green,
            ),
            SizedBox(height: tokens.spaceLg),

            // 最近订单
            Tooltip(
              message: '最近10笔订单的状态',
              child: Text(
                '最近订单',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            SizedBox(height: tokens.spaceSm),
            if (recentOrders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('暂无订单数据', style: TextStyle(color: Colors.grey)),
              )
            else
              ...recentOrders.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          order.customerName,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          order.items.map((i) => i.productName).join(', '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${order.currency}${order.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppStatusTag(
                        label: order.statusLabel,
                        tone: _orderTone(order.status),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: tokens.spaceMd),
            Center(
              child: OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('刷新数据'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppStatusTone _orderTone(OrderStatus s) {
    switch (s) {
      case OrderStatus.completed:
        return AppStatusTone.success;
      case OrderStatus.paid:
      case OrderStatus.delivered:
        return AppStatusTone.success;
      case OrderStatus.pending:
      case OrderStatus.confirmed:
        return AppStatusTone.warning;
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
        return AppStatusTone.danger;
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 160,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: color),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FunnelBar extends StatelessWidget {
  const _FunnelBar({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.color,
  });

  final String label;
  final int count;
  final int maxCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = maxCount > 0 ? (count / maxCount).clamp(0.05, 1.0) : 0.05;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
