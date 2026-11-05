import 'package:browsly_app/features/catalog/data/models/catalog_models.dart';
import 'package:browsly_app/features/catalog/domain/entities/product.dart';
import 'package:browsly_app/features/catalog/domain/entities/product_filters.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row(String id, {String? image = 'a/1.jpg'}) => {
  'id': id,
  'title': 'Title $id',
  'shop_id': 'shop',
  'shop_name': 'Shop',
  'image_path': image,
  'price': 1450,
  'compare_at_price': 1800.5,
  'rating_avg': 4.7,
  'rating_count': 42,
  'sold_count': 310,
  'total_stock': 21,
  'cursor_key': '1793000000.123456',
};

String urlOf(String path) => 'https://cdn/$path';

void main() {
  group('product pages', () {
    test('an extra row means another page, and is not shown', () {
      final page = ProductSummaryModel.pageFromRows(
        [row('1'), row('2'), row('3')],
        2,
        urlOf,
      );

      expect(page.items.map((product) => product.id), ['1', '2']);
      expect(page.next?.id, '2');
      expect(page.next?.key, '1793000000.123456');
    });

    test('no extra row means the last page', () {
      final page = ProductSummaryModel.pageFromRows([row('1')], 2, urlOf);

      expect(page.items, hasLength(1));
      expect(page.next, isNull);
    });

    test('an empty result has no next page', () {
      final page = ProductSummaryModel.pageFromRows([], 2, urlOf);

      expect(page.items, isEmpty);
      expect(page.next, isNull);
    });

    test('parses whole-number and decimal money, and missing photos', () {
      final page = ProductSummaryModel.pageFromRows(
        [row('1'), row('2', image: null)],
        2,
        urlOf,
      );

      expect(page.items[0].price, 1450.0);
      expect(page.items[0].compareAtPrice, 1800.5);
      expect(page.items[0].imageUrl, 'https://cdn/a/1.jpg');
      expect(page.items[1].imageUrl, isNull);
    });
  });

  test('product details put photos in order and variants by price', () {
    final product = ProductDetailModel.fromJson(
      {
        'id': 'p',
        'title': 'T',
        'description': 'D',
        'condition': 'used',
        'rating_avg': 0,
        'rating_count': 0,
        'sold_count': 0,
        'shops': {
          'id': 's',
          'name': 'Shop',
          'logo_path': null,
          'delivery_fee': 60,
          'rating_avg': 4,
          'rating_count': 2,
        },
        'categories': null,
        'product_images': [
          {'storage_path': 'second.jpg', 'sort_order': 1},
          {'storage_path': 'first.jpg', 'sort_order': 0},
        ],
        'product_variants': [
          {
            'id': 'b',
            'options': {'colour': 'Red', 'size': 'M'},
            'price': 900,
            'compare_at_price': null,
            'stock': 1,
          },
          {
            'id': 'a',
            'options': <String, dynamic>{},
            'price': 500,
            'compare_at_price': 700,
            'stock': 0,
          },
        ],
      },
      imageUrl: urlOf,
      shopAssetUrl: urlOf,
    );

    expect(product.imageUrls, [
      'https://cdn/first.jpg',
      'https://cdn/second.jpg',
    ]);
    expect(product.variants.map((variant) => variant.id), ['a', 'b']);
    expect(product.variants[0].colour, isNull);
    expect(product.variants[1].colour, 'Red');
    expect(product.isNew, isFalse);
    expect(product.categoryName, isNull);
    expect(product.shop.logoUrl, isNull);
  });

  group('filters', () {
    test('become the search function parameters', () {
      final params = ProductFiltersModel.toParams(
        const ProductFilters(
          categoryId: 'c',
          minPrice: 100,
          condition: ProductConditionFilter.isNew,
          inStockOnly: true,
          sort: ProductSort.priceLow,
        ),
        cursor: const ProductCursor(key: '-50', id: 'x'),
        limit: 21,
      );

      expect(params['p_category_id'], 'c');
      expect(params['p_min_price'], 100);
      expect(params['p_condition'], 'new');
      expect(params['p_in_stock_only'], isTrue);
      expect(params['p_sort'], 'price_low');
      expect(params['p_cursor_key'], '-50');
      expect(params['p_cursor_id'], 'x');
      expect(params['p_limit'], 21);
    });

    test('default to newest, or best match when searching', () {
      expect(const ProductFilters().effectiveSort, ProductSort.newest);
      expect(
        const ProductFilters(query: 'bag').effectiveSort,
        ProductSort.relevance,
      );
      expect(
        const ProductFilters(
          query: 'bag',
          sort: ProductSort.rating,
        ).effectiveSort,
        ProductSort.rating,
      );
    });

    test('count only choices from the filter sheet', () {
      expect(
        const ProductFilters(query: 'bag', categoryId: 'c').refinementCount,
        0,
      );
      expect(
        const ProductFilters(
          minPrice: 1,
          maxPrice: 2,
          inStockOnly: true,
        ).refinementCount,
        2,
      );
    });

    test('keep the shop and search when filters change', () {
      final filters = const ProductFilters(
        query: 'bag',
        shopId: 's',
        minRating: 4,
      ).withRefinements(inStockOnly: true);

      expect(filters.query, 'bag');
      expect(filters.shopId, 's');
      expect(filters.minRating, isNull);
      expect(filters.inStockOnly, isTrue);
    });
  });

  group('discounts', () {
    test('round to a whole percent', () {
      expect(discountPercentOf(1450, 1800), 19);
    });

    test('need a higher original price', () {
      expect(discountPercentOf(100, null), isNull);
      expect(discountPercentOf(100, 100), isNull);
      expect(discountPercentOf(100, 90), isNull);
    });
  });
}
