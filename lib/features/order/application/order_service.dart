import '../../../core/models/order.dart';
import '../../../core/models/product.dart';
import '../domain/order_repository.dart';

class OrderService {
  const OrderService({required this.repository});
  final OrderRepository repository;

  /// 从会话中创建订单
  Future<Order> createOrder({
    required String conversationId,
    required String customerId,
    required String customerName,
    required List<Product> products,
    required Map<String, int> quantities,
    required Map<String, double> prices,
    String currency = '¥',
    String? notes,
  }) async {
    if (products.isEmpty) {
      throw ArgumentError('产品列表不能为空');
    }

    final items = <OrderItem>[];
    double total = 0;

    for (final product in products) {
      final qty = quantities[product.id] ?? 1;
      if (qty <= 0) throw ArgumentError('数量必须大于0: ${product.name}');
      final price = prices[product.id] ?? product.basePrice;
      if (price < 0) throw ArgumentError('价格不能为负: ${product.name}');
      final lineTotal = price * qty;
      items.add(
        OrderItem(
          productId: product.id,
          productName: product.name,
          quantity: qty,
          unitPrice: price,
          totalPrice: lineTotal,
        ),
      );
      total += lineTotal;
    }

    final now = DateTime.now();
    final order = Order(
      id: 'ord_${now.microsecondsSinceEpoch}',
      conversationId: conversationId,
      customerId: customerId,
      customerName: customerName,
      items: items,
      totalAmount: total,
      currency: currency,
      status: OrderStatus.pending,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    await repository.upsert(order);
    return order;
  }

  /// 快速创建单品订单（适合交易场景）
  Future<Order> quickOrder({
    required String conversationId,
    required String customerId,
    required String customerName,
    required String productName,
    required double price,
    int quantity = 1,
    String currency = '¥',
  }) async {
    if (price < 0) throw ArgumentError('价格不能为负');
    if (quantity <= 0) throw ArgumentError('数量必须大于0');
    if (productName.trim().isEmpty) throw ArgumentError('产品名称不能为空');

    final now = DateTime.now();
    final item = OrderItem(
      productId: 'quick_${now.microsecondsSinceEpoch}',
      productName: productName,
      quantity: quantity,
      unitPrice: price,
      totalPrice: price * quantity,
    );

    final order = Order(
      id: 'ord_${now.microsecondsSinceEpoch}',
      conversationId: conversationId,
      customerId: customerId,
      customerName: customerName,
      items: [item],
      totalAmount: price * quantity,
      currency: currency,
      status: OrderStatus.confirmed,
      createdAt: now,
      updatedAt: now,
    );

    await repository.upsert(order);
    return order;
  }

  Future<Order?> confirmPayment({
    required String orderId,
    required String paymentMethod,
  }) async {
    final order = await repository.getById(orderId);
    if (order == null) return null;
    // 状态机：只有 pending/confirmed 状态可以确认收款
    if (order.status != OrderStatus.pending &&
        order.status != OrderStatus.confirmed) {
      return null;
    }
    final updated = order.copyWith(
      status: OrderStatus.paid,
      paymentMethod: paymentMethod,
      paidAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repository.upsert(updated);
    return updated;
  }

  Future<Order?> markDelivered({
    required String orderId,
    String? deliveryMethod,
    String? deliveryInfo,
  }) async {
    final order = await repository.getById(orderId);
    if (order == null) return null;
    // 状态机：只有 paid 状态可以标记交付
    if (order.status != OrderStatus.paid) {
      return null;
    }
    final updated = order.copyWith(
      status: OrderStatus.delivered,
      deliveryMethod: deliveryMethod,
      deliveryInfo: deliveryInfo,
      deliveredAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repository.upsert(updated);
    return updated;
  }

  Future<Order?> markCompleted(String orderId) async {
    final order = await repository.getById(orderId);
    if (order == null) return null;
    // 状态机：只有 delivered 状态可以标记完成
    if (order.status != OrderStatus.delivered) {
      return null;
    }
    final updated = order.copyWith(
      status: OrderStatus.completed,
      completedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repository.upsert(updated);
    return updated;
  }

  Future<Order?> cancel(String orderId) async {
    final order = await repository.getById(orderId);
    if (order == null) return null;
    // 状态机：已完成/已退款/已取消不能再取消
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.refunded) {
      return null;
    }
    // 已付款的订单不能直接取消（需走退款流程）
    if (order.status == OrderStatus.paid ||
        order.status == OrderStatus.delivered) {
      return null;
    }
    final updated = order.copyWith(
      status: OrderStatus.cancelled,
      updatedAt: DateTime.now(),
    );
    await repository.upsert(updated);
    return updated;
  }
}
