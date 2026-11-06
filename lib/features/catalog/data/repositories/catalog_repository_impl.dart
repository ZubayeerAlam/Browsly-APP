import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/home_banner.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_filters.dart';
import '../../domain/entities/shop.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_remote_data_source.dart';
import '../models/catalog_models.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  const CatalogRepositoryImpl(this._dataSource);

  final CatalogRemoteDataSource _dataSource;

  @override
  Future<List<HomeBanner>> getBanners() {
    return guardFailures(() async {
      final rows = await _dataSource.fetchBanners();
      return rows
          .map(
            (row) => HomeBanner(
              id: row['id'] as String,
              imageUrl: _dataSource.bannerImageUrl(row['image_path'] as String),
              title: row['title'] as String,
              productId: row['product_id'] as String?,
            ),
          )
          .toList();
    });
  }

  @override
  Future<List<Category>> getCategories() {
    return guardFailures(() async {
      final rows = await _dataSource.fetchCategories();
      return rows.map(CategoryModel.fromJson).toList();
    });
  }

  @override
  Future<ProductPage> searchProducts(
    ProductFilters filters, {
    ProductCursor? cursor,
    int limit = 20,
  }) {
    return guardFailures(() async {
      // One extra row shows whether another page exists.
      final rows = await _dataSource.searchProducts(
        ProductFiltersModel.toParams(filters, cursor: cursor, limit: limit + 1),
      );
      return ProductSummaryModel.pageFromRows(
        rows,
        limit,
        _dataSource.productImageUrl,
      );
    });
  }

  @override
  Future<ProductDetail?> getProduct(String id) {
    return guardFailures(() async {
      final row = await _dataSource.fetchProduct(id);
      if (row == null) return null;
      return ProductDetailModel.fromJson(
        row,
        imageUrl: _dataSource.productImageUrl,
        shopAssetUrl: _dataSource.shopAssetUrl,
      );
    });
  }

  @override
  Future<Shop?> getShop(String id) {
    return guardFailures(() async {
      final row = await _dataSource.fetchShop(id);
      return row == null
          ? null
          : ShopModel.fromJson(row, _dataSource.shopAssetUrl);
    });
  }
}
