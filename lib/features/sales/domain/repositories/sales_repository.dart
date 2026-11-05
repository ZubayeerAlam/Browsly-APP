import '../../../orders/domain/entities/order.dart';
import '../entities/sale.dart';

abstract interface class SalesRepository {
  Future<SalePage> getSales(SaleTab tab, {PageCursor? cursor, int limit = 20});

  /// Null if there is no such order, or it belongs to another shop.
  Future<SaleDetail?> getSale(String id);

  /// Moves an order one step along. [note] is shown to the buyer.
  Future<void> setStatus(String id, OrderStatus status, {String? note});

  /// [reason] is shown to the buyer.
  Future<void> cancel(String id, {String? reason});

  Future<CommissionSummary> getCommissionSummary();

  Future<CommissionPage> getCommissionEntries({
    PageCursor? cursor,
    int limit = 20,
  });
}
