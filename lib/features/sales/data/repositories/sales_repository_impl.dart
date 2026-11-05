import '../../../../core/errors/error_mapper.dart';
import '../../../orders/data/models/order_models.dart';
import '../../../orders/domain/entities/order.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sales_repository.dart';
import '../datasources/sales_remote_data_source.dart';
import '../models/sale_models.dart';

class SalesRepositoryImpl implements SalesRepository {
  const SalesRepositoryImpl(this._dataSource);

  final SalesRemoteDataSource _dataSource;

  @override
  Future<SalePage> getSales(SaleTab tab, {PageCursor? cursor, int limit = 20}) {
    return guardFailures(() async {
      // One extra row shows whether another page exists.
      final rows = await _dataSource.fetchSales({
        'p_statuses': SaleModel.statusesFor(tab),
        'p_cursor_key': cursor?.key,
        'p_cursor_id': cursor?.id,
        'p_limit': limit + 1,
      });
      return SaleModel.pageFromRows(rows, limit, _dataSource.productImageUrl);
    });
  }

  @override
  Future<SaleDetail?> getSale(String id) {
    return guardFailures(() async {
      final json = await _dataSource.fetchSale(id);
      return json == null
          ? null
          : SaleModel.detailFromJson(json, _dataSource.productImageUrl);
    });
  }

  @override
  Future<void> setStatus(String id, OrderStatus status, {String? note}) {
    return guardFailures(
      () => _dataSource.setStatus(id, OrderModel.statusToJson(status), note),
    );
  }

  @override
  Future<void> cancel(String id, {String? reason}) {
    return guardFailures(() => _dataSource.cancel(id, reason));
  }

  @override
  Future<CommissionSummary> getCommissionSummary() {
    return guardFailures(() async {
      return SaleModel.summaryFromJson(
        await _dataSource.fetchCommissionSummary(),
      );
    });
  }

  @override
  Future<CommissionPage> getCommissionEntries({
    PageCursor? cursor,
    int limit = 20,
  }) {
    return guardFailures(() async {
      // One extra row shows whether another page exists.
      final rows = await _dataSource.fetchCommissionEntries({
        'p_cursor_key': cursor?.key,
        'p_cursor_id': cursor?.id,
        'p_limit': limit + 1,
      });
      return SaleModel.entriesFromRows(rows, limit);
    });
  }
}
