import '../entities/order.dart';

abstract interface class OrderRepository {
  /// Sending the same [idempotencyKey] again returns the first order instead of
  /// creating a second one. Without [buyNowVariantId], this orders the cart.
  Future<PlacedOrder> placeOrder({
    required String addressId,
    required String idempotencyKey,
    required double expectedTotal,
    String? buyNowVariantId,
  });

  Future<OrderPage> getMyOrders({OrderCursor? cursor, int limit = 20});

  /// Null if there is no such order, or it belongs to someone else.
  Future<OrderDetail?> getOrder(String id);

  Future<void> cancelGroup(String groupId);
}
