import 'package:flutter/material.dart';

import '../../app_context.dart';
import '../app_theme.dart';
import '../app_widgets.dart';
import '../../../core/models/order.dart';

class OrderCenterPage extends StatefulWidget {
  const OrderCenterPage({required this.appContext, super.key});

  final AppContext appContext;

  @override
  State<OrderCenterPage> createState() => _OrderCenterPageState();
}

class _OrderCenterPageState extends State<OrderCenterPage> {
  List<Order> orders = const [];
  String filterStatus = 'all';
  int activeCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.appContext.orderRepository.listAll();
    final active = await widget.appContext.orderRepository.activeCount();
    if (!mounted) return;
    setState(() {
      orders = all;
      activeCount = active;
    });
  }

  List<Order> get filteredOrders {
    if (filterStatus == 'all') return orders;
    return orders.where((o) => o.status.name == filterStatus).toList();
  }

  Future<void> _confirmPayment(Order order) async {
    final method = await _showPaymentMethodDialog();
    if (method == null) return;
    await widget.appContext.orderService.confirmPayment(
      orderId: order.id,
      paymentMethod: method,
    );
    await _load();
  }

  Future<void> _markDelivered(Order order) async {
    final info = await _showDeliveryInfoDialog();
    if (info == null) return;
    await widget.appContext.orderService.markDelivered(
      orderId: order.id,
      deliveryMethod: info['method'],
      deliveryInfo: info['info'],
    );
    await _load();
  }

  Future<void> _markCompleted(Order order) async {
    await widget.appContext.orderService.markCompleted(order.id);
    await _load();
  }

  Future<void> _cancelOrder(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认取消'),
        content: Text('确定要取消订单 ${order.id.length > 15 ? '${order.id.substring(0, 15)}...' : order.id} 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('取消订单'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await widget.appContext.orderService.cancel(order.id);
    await _load();
  }

  Future<String?> _showPaymentMethodDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择付款方式'),
        children: [
          for (final method in ['微信', '支付宝', '银行转账', 'USDT', '现金', '其他'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, method),
              child: Text(method),
            ),
        ],
      ),
    );
  }

  Future<Map<String, String>?> _showDeliveryInfoDialog() async {
    final methodCtl = TextEditingController(text: '微信发送');
    final infoCtl = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('交付信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: methodCtl, decoration: const InputDecoration(labelText: '交付方式', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: infoCtl, decoration: const InputDecoration(labelText: '交付详情(链接/快递号等)', border: OutlineInputBorder()), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {'method': methodCtl.text, 'info': infoCtl.text}),
            child: const Text('确认交付'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final filtered = filteredOrders;
    final totalRevenue = orders
        .where((o) => o.status == OrderStatus.completed || o.status == OrderStatus.delivered || o.status == OrderStatus.paid)
        .fold<double>(0, (s, o) => s + o.totalAmount);

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppPanelHeader(
            title: '订单管理',
            subtitle: '所有交易订单在这里。流程：客户下单→确认收款→交付商品→完成。',
          ),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              SizedBox(width: 140, child: AppMetricTile(label: '总订单', value: '${orders.length}')),
              SizedBox(
                width: 140,
                child: AppMetricTile(
                  label: '进行中',
                  value: '$activeCount',
                  tone: activeCount > 0 ? AppStatusTone.warning : AppStatusTone.neutral,
                ),
              ),
              SizedBox(
                width: 160,
                child: AppMetricTile(
                  label: '累计营收',
                  value: '¥${totalRevenue.toStringAsFixed(0)}',
                  tone: AppStatusTone.success,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceSm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in ['all', 'pending', 'confirmed', 'paid', 'delivered', 'completed', 'cancelled'])
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(s == 'all' ? '全部' : _statusLabel(s), style: const TextStyle(fontSize: 11)),
                      selected: filterStatus == s,
                      onSelected: (_) => setState(() => filterStatus = s),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _load, child: const Text('刷新')),
              ],
            ),
          ),
          SizedBox(height: tokens.spaceMd),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        const Text('暂无订单'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      return _OrderCard(
                        order: order,
                        onConfirmPayment: order.status == OrderStatus.confirmed
                            ? () => _confirmPayment(order) : null,
                        onDeliver: order.status == OrderStatus.paid
                            ? () => _markDelivered(order) : null,
                        onComplete: order.status == OrderStatus.delivered
                            ? () => _markCompleted(order) : null,
                        onCancel: order.isActive && order.status != OrderStatus.paid
                            ? () => _cancelOrder(order) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    const labels = {
      'pending': '待确认',
      'confirmed': '待付款',
      'paid': '待交付',
      'delivered': '已交付',
      'completed': '已完成',
      'cancelled': '已取消',
      'refunded': '已退款',
    };
    return labels[status] ?? status;
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    this.onConfirmPayment,
    this.onDeliver,
    this.onComplete,
    this.onCancel,
  });

  final Order order;
  final VoidCallback? onConfirmPayment;
  final VoidCallback? onDeliver;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeTokens>()!;
    final statusColor = _statusColor(order.status);

    return Card(
      margin: EdgeInsets.only(bottom: tokens.spaceSm),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: statusColor, width: 4)),
        ),
        padding: EdgeInsets.all(tokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        order.items.map((i) => '${i.productName} x${i.quantity}').join(', '),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${order.currency}${order.totalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                AppStatusTag(
                  label: order.statusLabel,
                  tone: _statusTone(order.status),
                ),
              ],
            ),
            SizedBox(height: tokens.spaceSm),
            Row(
              children: [
                Text(
                  '${order.createdAt.month}/${order.createdAt.day} ${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (order.paymentMethod != null) ...[
                  const SizedBox(width: 12),
                  Text('付: ${order.paymentMethod}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
                if (order.deliveryMethod != null) ...[
                  const SizedBox(width: 12),
                  Text('发: ${order.deliveryMethod}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
                const Spacer(),
                if (onConfirmPayment != null)
                  FilledButton.icon(
                    onPressed: onConfirmPayment,
                    icon: const Icon(Icons.payment, size: 14),
                    label: const Text('确认收款', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                  ),
                if (onDeliver != null)
                  FilledButton.icon(
                    onPressed: onDeliver,
                    icon: const Icon(Icons.local_shipping, size: 14),
                    label: const Text('交付', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                  ),
                if (onComplete != null)
                  FilledButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check_circle, size: 14),
                    label: const Text('完成', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      backgroundColor: Colors.green,
                    ),
                  ),
                if (onCancel != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('取消', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending: return Colors.grey;
      case OrderStatus.confirmed: return Colors.orange;
      case OrderStatus.paid: return Colors.blue;
      case OrderStatus.delivered: return Colors.teal;
      case OrderStatus.completed: return Colors.green;
      case OrderStatus.cancelled: return Colors.red;
      case OrderStatus.refunded: return Colors.purple;
    }
  }

  AppStatusTone _statusTone(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending: return AppStatusTone.neutral;
      case OrderStatus.confirmed: return AppStatusTone.warning;
      case OrderStatus.paid: return AppStatusTone.success;
      case OrderStatus.delivered: return AppStatusTone.success;
      case OrderStatus.completed: return AppStatusTone.success;
      case OrderStatus.cancelled: return AppStatusTone.danger;
      case OrderStatus.refunded: return AppStatusTone.danger;
    }
  }
}
