import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/core/widgets/app_network_image.dart';
import 'package:browsly_app/features/catalog/domain/entities/category.dart';
import 'package:browsly_app/features/catalog/domain/entities/shop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Finder navItem(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

FakeCatalogRepository seededCatalog() {
  final catalog = FakeCatalogRepository()
    ..categories = const [
      Category(
        id: 'fashion',
        name: 'Fashion',
        icon: 'checkroom',
        productCount: 1,
      ),
      Category(id: 'tech', name: 'Tech', icon: 'devices', productCount: 1),
      Category(
        id: 'audio',
        parentId: 'tech',
        name: 'Audio',
        icon: 'devices',
        productCount: 1,
      ),
    ]
    ..products = [
      testProduct(
        '1',
        title: 'Cotton Panjabi',
        price: 1450,
        compareAtPrice: 1800,
      ),
      testProduct('2', title: 'Bluetooth Speaker', stock: 0),
    ]
    ..categoryOf.addAll({'1': 'fashion', '2': 'tech'})
    ..shop = const Shop(
      id: 'shop-1',
      name: 'Test Shop',
      description: 'A shop for testing',
      deliveryFee: 60,
      regionName: 'Dhaka',
    );
  catalog.details['1'] = testDetail(
    '1',
    variants: [
      testVariant(
        'w',
        colour: 'White',
        size: 'M',
        price: 1450,
        compareAtPrice: 1800,
      ),
      testVariant('n', colour: 'Navy', size: 'M', price: 1500, stock: 0),
    ],
  );
  return catalog;
}

/// Tall enough that a whole product page is built without scrolling.
Future<void> pumpOnTallPhone(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  FakeCatalogRepository? catalog,
  FakeWishlistRepository? wishlist,
}) async {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(tester, auth: auth, catalog: catalog, wishlist: wishlist);
}

Future<void> openProducts(WidgetTester tester) async {
  await tester.tap(navItem('Products'));
  await tester.pumpAndSettle();
}

Future<void> openProduct(WidgetTester tester, String title) async {
  await tester.tap(find.text(title).first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AppNetworkImage.debugBuilder = (url) => Text('image:$url');
  });
  tearDown(() {
    AppNetworkImage.debugBuilder = null;
  });

  group('Home', () {
    testWidgets('shows a guest the banner, categories and products', (
      tester,
    ) async {
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(),
        catalog: seededCatalog(),
      );

      expect(find.text('Buy and sell on Browsly'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Fashion'), findsOneWidget);
      expect(find.text('Audio'), findsNothing);
      expect(find.text('Cotton Panjabi'), findsWidgets);
      expect(find.text('৳1,450'), findsWidgets);
    });

    testWidgets('greets a signed-in user and invites them to sell', (
      tester,
    ) async {
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(user: testUser),
        catalog: seededCatalog(),
      );

      expect(find.text('Welcome back, Test!'), findsOneWidget);
      expect(find.text('Start posting'), findsOneWidget);
    });

    testWidgets('can retry after failing', (tester) async {
      final catalog = seededCatalog()..failWith = const NetworkFailure();
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(),
        catalog: catalog,
      );
      expect(find.text('Something went wrong'), findsOneWidget);

      catalog.failWith = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Cotton Panjabi'), findsWidgets);
    });

    testWidgets('a category opens the Products tab filtered to it', (
      tester,
    ) async {
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(),
        catalog: seededCatalog(),
      );

      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();

      expect(find.text('Tech (1)'), findsOneWidget);
      expect(find.text('Bluetooth Speaker'), findsOneWidget);
      expect(find.text('Cotton Panjabi'), findsNothing);
    });
  });

  group('Products', () {
    testWidgets('chips show counts and filter the list', (tester) async {
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(),
        catalog: seededCatalog(),
      );
      await openProducts(tester);

      expect(find.text('All (2)'), findsOneWidget);
      expect(find.text('Sold out'), findsOneWidget);
      expect(find.text('-19%'), findsOneWidget);

      await tester.tap(find.text('Fashion (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Cotton Panjabi'), findsOneWidget);
      expect(find.text('Bluetooth Speaker'), findsNothing);

      await tester.tap(find.text('All (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Bluetooth Speaker'), findsOneWidget);
    });

    testWidgets('scrolling loads the next page', (tester) async {
      final catalog = FakeCatalogRepository()
        ..products = List.generate(30, (i) => testProduct('$i'));
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(),
        catalog: catalog,
      );
      await openProducts(tester);

      await tester.scrollUntilVisible(
        find.text('Product 29'),
        600,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      expect(find.text('Product 29'), findsOneWidget);
    });

    testWidgets('the filter sheet refuses a backwards price range', (
      tester,
    ) async {
      final catalog = seededCatalog();
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(),
        catalog: catalog,
      );
      await openProducts(tester);

      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Min price'),
        '500',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Max price'),
        '100',
      );
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();

      expect(find.text('Must be above min'), findsOneWidget);
      expect(catalog.searches.last.minPrice, isNull);
    });

    testWidgets('applied filters reach the search and show a count', (
      tester,
    ) async {
      final catalog = seededCatalog();
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(),
        catalog: catalog,
      );
      await openProducts(tester);

      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Min price'),
        '100',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Max price'),
        '500',
      );
      await tester.tap(find.text('Used'));
      await tester.pump();
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();

      final search = catalog.searches.last;
      expect(search.minPrice, 100);
      expect(search.maxPrice, 500);
      expect(search.condition, isNotNull);
      expect(find.byTooltip('Filters, 2 in use'), findsOneWidget);
    });
  });

  group('Search', () {
    testWidgets('finds products as you type, and explains no results', (
      tester,
    ) async {
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(),
        catalog: seededCatalog(),
      );

      await tester.tap(find.text('Search products'));
      await tester.pumpAndSettle();
      expect(find.text('What are you looking for?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'speaker');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Bluetooth Speaker'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('No matching products'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('Product details', () {
    testWidgets('shows the price, choices and shop, and goes back', (
      tester,
    ) async {
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(),
        catalog: seededCatalog(),
      );
      await openProducts(tester);

      await openProduct(tester, 'Cotton Panjabi');

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('৳1,450'), findsOneWidget);
      expect(find.text('৳1,800'), findsOneWidget);
      expect(find.text('19% off'), findsOneWidget);
      expect(find.text('White'), findsOneWidget);
      expect(find.text('Test Shop'), findsOneWidget);
      expect(find.text('Delivery ৳60 · Cash on Delivery'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('a sold-out choice cannot be bought', (tester) async {
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(),
        catalog: seededCatalog(),
      );
      await openProducts(tester);
      await openProduct(tester, 'Cotton Panjabi');

      FilledButton buyNow() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Buy Now'),
      );
      expect(buyNow().onPressed, isNotNull);

      await tester.tap(find.text('Navy'));
      await tester.pumpAndSettle();

      expect(find.text('৳1,500'), findsOneWidget);
      expect(find.text('Out of stock'), findsOneWidget);
      expect(buyNow().onPressed, isNull);
    });

    testWidgets('Chat with seller says it is coming, not silently nothing', (
      tester,
    ) async {
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(),
        catalog: seededCatalog(),
      );
      await openProducts(tester);
      await openProduct(tester, 'Cotton Panjabi');

      await tester.ensureVisible(find.text('Chat with seller'));
      await tester.tap(find.text('Chat with seller'));
      await tester.pump();

      expect(find.text('Chat with seller is coming soon.'), findsOneWidget);
    });

    testWidgets('a removed product explains itself', (tester) async {
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(),
        catalog: seededCatalog(),
      );
      await openProducts(tester);

      await openProduct(tester, 'Bluetooth Speaker');

      expect(find.text('This product is not available'), findsOneWidget);
    });

    testWidgets('the gallery counts its photos', (tester) async {
      final catalog = seededCatalog();
      catalog.details['1'] = testDetail('1', imageUrls: ['a', 'b', 'c']);
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(),
        catalog: catalog,
      );
      await openProducts(tester);
      await openProduct(tester, 'Cotton Panjabi');

      expect(find.text('1 / 3'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('the shop link opens the shop and its products', (
      tester,
    ) async {
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(),
        catalog: seededCatalog(),
      );
      await openProducts(tester);
      await openProduct(tester, 'Cotton Panjabi');

      await tester.tap(find.text('Test Shop'));
      await tester.pumpAndSettle();

      expect(find.text('A shop for testing'), findsOneWidget);
      expect(find.text('Dhaka'), findsOneWidget);
      expect(find.text('Cotton Panjabi'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Delivery ৳60 · Cash on Delivery'), findsOneWidget);
    });
  });

  group('Wishlist', () {
    testWidgets('a guest signs in, then returns to the same product', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      await pumpOnTallPhone(tester, auth: auth, catalog: seededCatalog());
      await openProducts(tester);
      await openProduct(tester, 'Cotton Panjabi');

      await tester.tap(find.byTooltip('Save to wishlist'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'a@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Delivery ৳60 · Cash on Delivery'), findsOneWidget);

      // There is no earlier screen now, so back still leads somewhere.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('saved products appear in the wishlist and can be removed', (
      tester,
    ) async {
      final wishlist = FakeWishlistRepository();
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(user: testUser),
        catalog: seededCatalog(),
        wishlist: wishlist,
      );
      await openProducts(tester);

      await tester.tap(find.byTooltip('Save to wishlist').first);
      await tester.pumpAndSettle();
      expect(wishlist.saved.single.id, '1');

      await tester.tap(navItem('Dashboard'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wishlist'));
      await tester.pumpAndSettle();
      expect(find.text('Product 1'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove from wishlist'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(wishlist.saved, isEmpty);
    });

    testWidgets('a failed save tells the user', (tester) async {
      final wishlist = FakeWishlistRepository();
      await pumpOnTallPhone(
        tester,
        auth: FakeAuthRepository(user: testUser),
        catalog: seededCatalog(),
        wishlist: wishlist,
      );
      await openProducts(tester);
      wishlist.failWith = const NetworkFailure();

      await tester.tap(find.byTooltip('Save to wishlist').first);
      await tester.pumpAndSettle();

      expect(
        find.text('We could not update your wishlist. Please try again.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Remove from wishlist'), findsNothing);
    });
  });
}
