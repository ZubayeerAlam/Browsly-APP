import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_data_source.dart';
import '../models/order_models.dart';

class OrderRepositoryImpl implements OrderRepository {
  const OrderRepositoryImpl(this._dataSource);

  final OrderRemoteDataSource _dataSource;

  @override
  Future<PlacedOrder> placeOrder({
    required String addressId,
    required String idempotencyKey,
    required double expectedTotal,
    String? buyNowVariantId,
  }) {
    return guardFailures(() async {
      return OrderModel.placedFromJson(
        await _dataSource.placeOrder(
          addressId: addressId,
          idempotencyKey: idempotencyKey,
          expectedTotal: expectedTotal,
          buyNowVariantId: buyNowVariantId,
        ),
      );
    });
  }

  @override
  Future<OrderPage> getMyOrders({OrderCursor? cursor, int limit = 20}) {
    return guardFailures(() async {
      // One extra row shows whether another page exists.
      final rows = await _dataSource.fetchPage({
        'p_cursor_key': cursor?.key,
        'p_cursor_id': cursor?.id,
        'p_limit': limit + 1,
      });
      return OrderModel.pageFromRows(rows, limit, _dataSource.productImageUrl);
    });
  }

  @override
  Future<OrderDetail?> getOrder(String id) {
    return guardFailures(() async {
      final row = await _dataSource.fetchOrder(id);
      return row == null
          ? null
          : OrderModel.detailFromJson(row, _dataSource.productImageUrl);
    });
  }

  @override
  Future<void> cancelGroup(String groupId) {
    return guardFailures(() => _dataSource.cancelGroup(groupId));
  }
}
