enum OrderStatus {
  pending,     // 待确认
  confirmed,   // 已确认，等待付款
  paid,        // 已付款，待交付
  delivered,   // 已交付
  completed,   // 完成
  cancelled,   // 取消
  refunded,    // 退款
}

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'totalPrice': totalPrice,
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    productId: json['productId'] as String,
    productName: json['productName'] as String,
    quantity: json['quantity'] as int,
    unitPrice: (json['unitPrice'] as num).toDouble(),
    totalPrice: (json['totalPrice'] as num).toDouble(),
  );
}

class Order {
  const Order({
    required this.id,
    required this.conversationId,
    required this.customerId,
    required this.customerName,
    required this.items,
    required this.totalAmount,
    required this.currency,
    required this.status,
    this.paymentMethod,
    this.deliveryMethod,
    this.deliveryInfo,
    this.notes,
    this.paidAt,
    this.deliveredAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String conversationId;
  final String customerId;
  final String customerName;
  final List<OrderItem> items;
  final double totalAmount;
  final String currency;
  final OrderStatus status;
  final String? paymentMethod;  // '微信', '支付宝', 'USDT', '银行转账'
  final String? deliveryMethod; // '网盘链接', '微信发送', '邮件', '快递'
  final String? deliveryInfo;   // 交付详情（如网盘链接）
  final String? notes;
  final DateTime? paidAt;
  final DateTime? deliveredAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order copyWith({
    OrderStatus? status,
    String? paymentMethod,
    String? deliveryMethod,
    String? deliveryInfo,
    String? notes,
    DateTime? paidAt,
    DateTime? deliveredAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id,
      conversationId: conversationId,
      customerId: customerId,
      customerName: customerName,
      items: items,
      totalAmount: totalAmount,
      currency: currency,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      deliveryInfo: deliveryInfo ?? this.deliveryInfo,
      notes: notes ?? this.notes,
      paidAt: paidAt ?? this.paidAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => status == OrderStatus.pending || status == OrderStatus.confirmed;
  bool get isActive => status != OrderStatus.cancelled && status != OrderStatus.refunded && status != OrderStatus.completed;

  String get statusLabel {
    switch (status) {
      case OrderStatus.pending: return '待确认';
      case OrderStatus.confirmed: return '待付款';
      case OrderStatus.paid: return '待交付';
      case OrderStatus.delivered: return '已交付';
      case OrderStatus.completed: return '已完成';
      case OrderStatus.cancelled: return '已取消';
      case OrderStatus.refunded: return '已退款';
    }
  }
}
