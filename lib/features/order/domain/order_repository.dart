import '../../../core/models/order.dart';

abstract class OrderRepository {
  Future<void> upsert(Order order);
  Future<Order?> getById(String id);
  Future<List<Order>> listByConversation(String conversationId);
  Future<List<Order>> listByCustomer(String customerId);
  Future<List<Order>> listByStatus(OrderStatus status);
  Future<List<Order>> listAll({int limit = 100});
  Future<int> activeCount();
}
