import '../../../catalog/domain/entities/product.dart';

abstract interface class WishlistRepository {
  /// The IDs of every product the signed-in user has saved.
  Future<Set<String>> getSavedIds();

  Future<void> add(String productId);

  Future<void> remove(String productId);

  /// Saved products that are still live, newest first.
  Future<ProductPage> getPage({ProductCursor? cursor, int limit = 20});
}
