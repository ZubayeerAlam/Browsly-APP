import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_filters.dart';
import '../../domain/entities/shop.dart';

typedef UrlBuilder = String Function(String path);

double _money(Object? value) => (value as num).toDouble();

double? _moneyOrNull(Object? value) => (value as num?)?.toDouble();

abstract final class CategoryModel {
  static Category fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    parentId: json['parent_id'] as String?,
    name: json['name'] as String,
    icon: json['icon'] as String,
    productCount: json['product_count'] as int,
  );
}

abstract final class ProductSummaryModel {
  static ProductSummary fromJson(
    Map<String, dynamic> json,
    UrlBuilder imageUrl,
  ) {
    final imagePath = json['image_path'] as String?;
    return ProductSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      shopId: json['shop_id'] as String,
      shopName: json['shop_name'] as String,
      imageUrl: imagePath == null ? null : imageUrl(imagePath),
      price: _money(json['price']),
      compareAtPrice: _moneyOrNull(json['compare_at_price']),
      ratingAvg: _money(json['rating_avg']),
      ratingCount: json['rating_count'] as int,
      soldCount: json['sold_count'] as int,
      totalStock: json['total_stock'] as int,
    );
  }

  /// Turns one more row than a page needs into a page and its next cursor.
  static ProductPage pageFromRows(
    List<Map<String, dynamic>> rows,
    int limit,
    UrlBuilder imageUrl,
  ) {
    final kept = rows.take(limit).toList();
    final last = kept.isEmpty ? null : kept.last;
    return ProductPage(
      items: kept.map((row) => fromJson(row, imageUrl)).toList(),
      next: rows.length > limit && last != null
          ? ProductCursor(
              key: last['cursor_key'] as String,
              id: last['id'] as String,
            )
          : null,
    );
  }
}

abstract final class ProductDetailModel {
  static ProductDetail fromJson(
    Map<String, dynamic> json, {
    required UrlBuilder imageUrl,
    required UrlBuilder shopAssetUrl,
  }) {
    final shop = json['shops'] as Map<String, dynamic>;
    final category = json['categories'] as Map<String, dynamic>?;
    final logoPath = shop['logo_path'] as String?;
    final images =
        (json['product_images'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .toList()
          ..sort(
            (a, b) =>
                (a['sort_order'] as int).compareTo(b['sort_order'] as int),
          );
    final variants =
        (json['product_variants'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(_variantFromJson)
            .toList()
          ..sort((a, b) => a.price.compareTo(b.price));
    return ProductDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      isNew: json['condition'] == 'new',
      categoryName: category?['name'] as String?,
      ratingAvg: _money(json['rating_avg']),
      ratingCount: json['rating_count'] as int,
      soldCount: json['sold_count'] as int,
      imageUrls: images
          .map((image) => imageUrl(image['storage_path'] as String))
          .toList(),
      variants: variants,
      shop: ProductShop(
        id: shop['id'] as String,
        name: shop['name'] as String,
        logoUrl: logoPath == null ? null : shopAssetUrl(logoPath),
        deliveryFee: _money(shop['delivery_fee']),
        ratingAvg: _money(shop['rating_avg']),
        ratingCount: shop['rating_count'] as int,
      ),
    );
  }

  static ProductVariant _variantFromJson(Map<String, dynamic> json) {
    final options = json['options'] as Map<String, dynamic>;
    return ProductVariant(
      id: json['id'] as String,
      colour: options['colour'] as String?,
      size: options['size'] as String?,
      price: _money(json['price']),
      compareAtPrice: _moneyOrNull(json['compare_at_price']),
      stock: json['stock'] as int,
    );
  }
}

abstract final class ShopModel {
  static Shop fromJson(Map<String, dynamic> json, UrlBuilder assetUrl) {
    final logoPath = json['logo_path'] as String?;
    final bannerPath = json['banner_path'] as String?;
    final region = json['regions'] as Map<String, dynamic>?;
    return Shop(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      deliveryFee: _money(json['delivery_fee']),
      logoUrl: logoPath == null ? null : assetUrl(logoPath),
      bannerUrl: bannerPath == null ? null : assetUrl(bannerPath),
      regionId: json['region_id'] as String?,
      regionName: region?['name'] as String?,
      ratingAvg: _money(json['rating_avg']),
      ratingCount: json['rating_count'] as int,
    );
  }
}

abstract final class ProductFiltersModel {
  static String sortToJson(ProductSort sort) => switch (sort) {
    ProductSort.newest => 'newest',
    ProductSort.popular => 'popular',
    ProductSort.priceLow => 'price_low',
    ProductSort.priceHigh => 'price_high',
    ProductSort.rating => 'rating',
    ProductSort.relevance => 'relevance',
  };

  static Map<String, dynamic> toParams(
    ProductFilters filters, {
    required ProductCursor? cursor,
    required int limit,
  }) => {
    'p_query': filters.hasQuery ? filters.query : null,
    'p_category_id': filters.categoryId,
    'p_shop_id': filters.shopId,
    'p_min_price': filters.minPrice,
    'p_max_price': filters.maxPrice,
    'p_condition': switch (filters.condition) {
      ProductConditionFilter.isNew => 'new',
      ProductConditionFilter.used => 'used',
      null => null,
    },
    'p_min_rating': filters.minRating,
    'p_in_stock_only': filters.inStockOnly,
    'p_sort': sortToJson(filters.effectiveSort),
    'p_cursor_key': cursor?.key,
    'p_cursor_id': cursor?.id,
    'p_limit': limit,
  };
}
