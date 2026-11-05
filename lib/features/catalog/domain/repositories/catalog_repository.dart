import '../entities/category.dart';
import '../entities/product.dart';
import '../entities/product_filters.dart';
import '../entities/shop.dart';

abstract interface class CatalogRepository {
  Future<List<Category>> getCategories();

  Future<ProductPage> searchProducts(
    ProductFilters filters, {
    ProductCursor? cursor,
    int limit = 20,
  });

  /// Null when the product doesn't exist or is no longer available.
  Future<ProductDetail?> getProduct(String id);

  /// Null when the shop doesn't exist or is no longer available.
  Future<Shop?> getShop(String id);
}
