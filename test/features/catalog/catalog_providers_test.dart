import 'dart:async';

import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/core/state/view_state.dart';
import 'package:browsly_app/features/catalog/domain/entities/product_filters.dart';
import 'package:browsly_app/features/catalog/presentation/providers/product_detail_provider.dart';
import 'package:browsly_app/features/catalog/presentation/providers/product_list_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeCatalogRepository catalog;

  setUp(() => catalog = FakeCatalogRepository());

  group('paging', () {
    setUp(() {
      catalog.products = List.generate(45, (i) => testProduct('$i'));
    });

    test('loads each page once, until the last one', () async {
      final provider = ProductListProvider(catalog);

      await provider.reload();
      expect(provider.state.data, hasLength(20));
      expect(provider.hasMore, isTrue);

      await provider.loadMore();
      expect(provider.state.data, hasLength(40));

      await provider.loadMore();
      expect(provider.state.data, hasLength(45));
      expect(provider.hasMore, isFalse);

      final ids = provider.state.data!.map((product) => product.id).toSet();
      expect(ids, hasLength(45));

      final searchesSoFar = catalog.searches.length;
      await provider.loadMore();
      expect(catalog.searches, hasLength(searchesSoFar));
    });

    test('ignores a second request while one is loading', () async {
      final provider = ProductListProvider(catalog);
      await provider.reload();
      final searchesSoFar = catalog.searches.length;

      await Future.wait([provider.loadMore(), provider.loadMore()]);

      expect(catalog.searches.length, searchesSoFar + 1);
      expect(provider.state.data, hasLength(40));
    });

    test('a failed next page keeps the list and can be retried', () async {
      final provider = ProductListProvider(catalog);
      await provider.reload();

      catalog.failWith = const NetworkFailure();
      await provider.loadMore();
      expect(provider.state.data, hasLength(20));
      expect(provider.state.status, ViewStatus.success);
      expect(provider.loadMoreFailure, isA<NetworkFailure>());

      catalog.failWith = null;
      await provider.loadMore();
      expect(provider.state.data, hasLength(40));
      expect(provider.loadMoreFailure, isNull);
    });

    test('a next page from before a filter change is dropped', () async {
      final provider = ProductListProvider(catalog);
      await provider.reload();

      final slowPage = Completer<void>();
      catalog.searchGate = slowPage.future;
      final oldPage = provider.loadMore();
      await provider.applyFilters(const ProductFilters(query: 'product 44'));
      slowPage.complete();
      await oldPage;

      expect(provider.state.data!.single.id, '44');
    });
  });

  group('states', () {
    test('no results is empty, not an error', () async {
      final provider = ProductListProvider(catalog);

      await provider.reload();

      expect(provider.state.status, ViewStatus.empty);
    });

    test('a failed first load is an error', () async {
      catalog.failWith = const NetworkFailure();
      final provider = ProductListProvider(catalog);

      await provider.reload();

      expect(provider.state.status, ViewStatus.error);
      expect(provider.state.data, isNull);
    });

    test('a failed refresh keeps the old list', () async {
      catalog.products = [testProduct('1')];
      final provider = ProductListProvider(catalog);
      await provider.reload();

      catalog.failWith = const NetworkFailure();
      await provider.reload(keepList: true);

      expect(provider.state.status, ViewStatus.error);
      expect(provider.state.data, hasLength(1));
    });

    test('a failed filter change does not show the old results', () async {
      catalog.products = [testProduct('1')];
      final provider = ProductListProvider(catalog);
      await provider.reload();

      catalog.failWith = const NetworkFailure();
      await provider.applyFilters(const ProductFilters(minPrice: 5));

      expect(provider.state.data, isNull);
    });

    test('failed categories do not stop the list', () async {
      catalog.failWith = const NetworkFailure();
      final provider = ProductListProvider(catalog);

      await provider.loadCategories();

      expect(provider.categories, isEmpty);
    });
  });

  group('search', () {
    const delay = Duration(milliseconds: 10);
    Future<void> settle() => Future<void>.delayed(delay * 3);

    setUp(() {
      catalog.products = [
        testProduct('1', title: 'Red bag'),
        testProduct('2', title: 'Blue shoes'),
      ];
    });

    test('waits for a pause in typing', () async {
      final provider = ProductListProvider(catalog, searchDelay: delay);

      provider.setQuery('b');
      provider.setQuery('ba');
      provider.setQuery('bag');
      await settle();

      expect(catalog.searches.map((search) => search.query), ['bag']);
      expect(provider.state.data!.single.id, '1');
    });

    test('a slow old search cannot replace a newer one', () async {
      final provider = ProductListProvider(catalog, searchDelay: delay);
      final slowSearch = Completer<void>();
      catalog.searchGate = slowSearch.future;

      provider.setQuery('bag');
      await settle();
      provider.setQuery('shoes');
      await settle();
      slowSearch.complete();
      await settle();

      expect(provider.state.data!.single.id, '2');
    });

    test(
      'clearing the text returns to the start and drops any search',
      () async {
        final provider = ProductListProvider(catalog, searchDelay: delay);
        provider.setQuery('bag');
        await settle();

        final slowSearch = Completer<void>();
        catalog.searchGate = slowSearch.future;
        provider.setQuery('shoes');
        await settle();
        provider.setQuery('  ');
        slowSearch.complete();
        await settle();

        expect(provider.state.status, ViewStatus.initial);
        expect(provider.filters.hasQuery, isFalse);
      },
    );

    test('a timer does not fire after leaving the screen', () async {
      final provider = ProductListProvider(catalog, searchDelay: delay);

      provider.setQuery('bag');
      provider.dispose();
      await settle();

      expect(catalog.searches, isEmpty);
    });

    test('filters wait until something has been typed', () async {
      final provider = ProductListProvider(catalog, searchDelay: delay);

      await provider.applySearchFilters(
        const ProductFilters(inStockOnly: true),
      );
      expect(catalog.searches, isEmpty);

      provider.setQuery('bag');
      await settle();
      expect(catalog.searches.single.inStockOnly, isTrue);
    });
  });

  test('changing category reloads, and the same one does nothing', () async {
    final provider = ProductListProvider(catalog);
    await provider.reload();

    await provider.setCategory('fashion');
    expect(catalog.searches.last.categoryId, 'fashion');

    final searchesSoFar = catalog.searches.length;
    await provider.setCategory('fashion');
    expect(catalog.searches, hasLength(searchesSoFar));
  });

  group('choosing a colour and size', () {
    Future<ProductDetailProvider> loaded() async {
      catalog.details['p'] = testDetail(
        'p',
        variants: [
          testVariant('white-m', colour: 'White', size: 'M', stock: 0),
          testVariant('white-l', colour: 'White', size: 'L', price: 1100),
          testVariant('navy-l', colour: 'Navy', size: 'L', price: 1200),
          testVariant('navy-xl', colour: 'Navy', size: 'XL', price: 1300),
        ],
      );
      final provider = ProductDetailProvider(catalog, 'p');
      await provider.load();
      return provider;
    }

    test('starts on the first variant in stock', () async {
      final provider = await loaded();

      expect(provider.selected?.id, 'white-l');
      expect(provider.colours, ['White', 'Navy']);
      expect(provider.sizes, ['M', 'L', 'XL']);
    });

    test('keeps the size when the new colour has it', () async {
      final provider = await loaded();

      provider.selectColour('Navy');

      expect(provider.selected?.id, 'navy-l');
    });

    test('moves to a real option when the new colour lacks the size', () async {
      final provider = await loaded();
      provider.selectColour('Navy');
      provider.selectSize('XL');

      provider.selectColour('White');

      expect(provider.selected?.id, 'white-l');
    });

    test('marks which sizes the colour offers', () async {
      final provider = await loaded();

      expect(provider.isSizeOffered('M'), isTrue);
      expect(provider.isSizeOffered('XL'), isFalse);
    });

    test('ignores a size the colour does not offer', () async {
      final provider = await loaded();

      provider.selectSize('XL');

      expect(provider.selected?.id, 'white-l');
    });

    test('shows the first variant when everything is sold out', () async {
      catalog.details['p'] = testDetail(
        'p',
        variants: [testVariant('a', stock: 0), testVariant('b', stock: 0)],
      );
      final provider = ProductDetailProvider(catalog, 'p');

      await provider.load();

      expect(provider.selected?.id, 'a');
      expect(provider.selected?.isInStock, isFalse);
    });

    test('keeps the choice across a refresh', () async {
      final provider = await loaded();
      provider.selectColour('Navy');

      await provider.load();

      expect(provider.selected?.id, 'navy-l');
    });

    test('a missing product is empty, not an error', () async {
      final provider = ProductDetailProvider(catalog, 'gone');

      await provider.load();

      expect(provider.state.status, ViewStatus.empty);
    });
  });
}
