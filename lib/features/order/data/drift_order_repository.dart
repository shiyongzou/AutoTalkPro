import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/models/order.dart';
import '../../../core/persistence/drift_local_database.dart';
import '../domain/order_repository.dart';

class DriftOrderRepository implements OrderRepository {
  const DriftOrderRepository(this._db);
  final DriftLocalDatabase _db;

  @override
  Future<void> upsert(Order order) async {
    final itemsJson = jsonEncode(order.items.map((i) => i.toJson()).toList());
    await _db.customStatement(
      '''INSERT OR REPLACE INTO orders(
        id,conversation_id,customer_id,customer_name,items_json,
        total_amount,currency,status,payment_method,delivery_method,
        delivery_info,notes,paid_at,delivered_at,completed_at,
        created_at,updated_at
      ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        order.id,
        order.conversationId,
        order.customerId,
        order.customerName,
        itemsJson,
        order.totalAmount,
        order.currency,
        order.status.name,
        order.paymentMethod,
        order.deliveryMethod,
        order.deliveryInfo,
        order.notes,
        order.paidAt?.millisecondsSinceEpoch,
        order.deliveredAt?.millisecondsSinceEpoch,
        order.completedAt?.millisecondsSinceEpoch,
        order.createdAt.millisecondsSinceEpoch,
        order.updatedAt.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<Order?> getById(String id) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM orders WHERE id = ?',
          variables: [Variable(id)],
          readsFrom: {},
        )
        .get();
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<List<Order>> listByConversation(String conversationId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM orders WHERE conversation_id = ? ORDER BY created_at DESC',
          variables: [Variable(conversationId)],
          readsFrom: {},
        )
        .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Order>> listByCustomer(String customerId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM orders WHERE customer_id = ? ORDER BY created_at DESC',
          variables: [Variable(customerId)],
          readsFrom: {},
        )
        .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Order>> listByStatus(OrderStatus status) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM orders WHERE status = ? ORDER BY created_at DESC',
          variables: [Variable(status.name)],
          readsFrom: {},
        )
        .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Order>> listAll({int limit = 100}) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM orders ORDER BY created_at DESC LIMIT ?',
          variables: [Variable(limit)],
          readsFrom: {},
        )
        .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<int> activeCount() async {
    final row = await _db
        .customSelect(
          "SELECT COUNT(1) c FROM orders WHERE status NOT IN ('completed','cancelled','refunded')",
          readsFrom: {},
        )
        .getSingle();
    return row.read<int>('c');
  }

  Order _fromRow(QueryRow row) {
    final itemsRaw = jsonDecode(row.read<String>('items_json')) as List;
    final items = itemsRaw
        .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
        .toList();
    DateTime? readTimestamp(String col) {
      final ms = row.readNullable<int>(col);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    }

    return Order(
      id: row.read<String>('id'),
      conversationId: row.read<String>('conversation_id'),
      customerId: row.read<String>('customer_id'),
      customerName: row.read<String>('customer_name'),
      items: items,
      totalAmount: row.read<double>('total_amount'),
      currency: row.read<String>('currency'),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == row.read<String>('status'),
        orElse: () => OrderStatus.pending,
      ),
      paymentMethod: row.readNullable<String>('payment_method'),
      deliveryMethod: row.readNullable<String>('delivery_method'),
      deliveryInfo: row.readNullable<String>('delivery_info'),
      notes: row.readNullable<String>('notes'),
      paidAt: readTimestamp('paid_at'),
      deliveredAt: readTimestamp('delivered_at'),
      completedAt: readTimestamp('completed_at'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at'),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('updated_at'),
      ),
    );
  }
}
