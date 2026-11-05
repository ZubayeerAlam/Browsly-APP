import '../../../catalog/domain/entities/product.dart';
import '../../../catalog/presentation/providers/paged_products_provider.dart';
import '../../domain/repositories/wishlist_repository.dart';

/// The products on the wishlist screen.
class SavedProductsProvider extends PagedProductsProvider {
  SavedProductsProvider(this._repository);

  final WishlistRepository _repository;

  @override
  Future<ProductPage> fetchPage(ProductCursor? cursor) {
    return _repository.getPage(cursor: cursor);
  }
}
