import '../../../../core/errors/error_mapper.dart';
import '../../../catalog/data/models/catalog_models.dart';
import '../../../catalog/domain/entities/product.dart';
import '../../domain/repositories/wishlist_repository.dart';
import '../datasources/wishlist_remote_data_source.dart';

class WishlistRepositoryImpl implements WishlistRepository {
  const WishlistRepositoryImpl(this._dataSource);

  final WishlistRemoteDataSource _dataSource;

  @override
  Future<Set<String>> getSavedIds() {
    return guardFailures(() async {
      final rows = await _dataSource.fetchSavedIds();
      return rows.map((row) => row['product_id'] as String).toSet();
    });
  }

  @override
  Future<void> add(String productId) {
    return guardFailures(() => _dataSource.add(productId));
  }

  @override
  Future<void> remove(String productId) {
    return guardFailures(() => _dataSource.remove(productId));
  }

  @override
  Future<ProductPage> getPage({ProductCursor? cursor, int limit = 20}) {
    return guardFailures(() async {
      // One extra row shows whether another page exists.
      final rows = await _dataSource.fetchPage({
        'p_cursor_key': cursor?.key,
        'p_cursor_id': cursor?.id,
        'p_limit': limit + 1,
      });
      return ProductSummaryModel.pageFromRows(
        rows,
        limit,
        _dataSource.productImageUrl,
      );
    });
  }
}
