import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/core/widgets/app_network_image.dart';
import 'package:browsly_app/features/cart/domain/entities/cart.dart';
import 'package:browsly_app/features/orders/data/models/order_models.dart';
import 'package:browsly_app/features/orders/domain/entities/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fakes.dart';
import 'checkout_provider_test.dart' show address;

void main() {
  late FakeCartRepository cart;
  late FakeOrderRepository orders;
  late FakeAddressRepository addresses;
  late FakeCatalogRepository catalog;

  setUp(() {
    AppNetworkImage.debugBuilder = (url) => const SizedBox();
    cart = FakeCartRepository();
    orders = FakeOrderRepository();
    addresses = FakeAddressRepository()
      ..addresses = [address('a1', isDefault: true)];
    catalog = FakeCatalogRepository()..products = [testProduct('1')];
    catalog.details['1'] = testDetail('1');
  });

  tearDown(() => AppNetworkImage.debugBuilder = null);

  Future<void> pump(WidgetTester tester, {bool verified = true}) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      auth: FakeAuthRepository(user: verified ? verifiedUser : testUser),
      cart: cart,
      orders: orders,
      addresses: addresses,
      catalog: catalog,
    );
  }

  Future<void> goTo(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }

  group('the phone\'s Back button', () {
    Future<String> backFrom(WidgetTester tester, String location) async {
      await pump(tester);
      await goTo(tester, location);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);
      return GoRouter.of(context).routerDelegate.currentConfiguration.uri
          .toString();
    }

    testWidgets('Android is always told the app handles Back', (tester) async {
      final told = <bool>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
            told.add(call.arguments as bool);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pump(tester);
      await goTo(tester, '/orders');
      await goTo(tester, '/dashboard');

      expect(told, isNotEmpty);
      expect(told, everyElement(isTrue));
    });

    testWidgets('order details goes to My Orders', (tester) async {
      orders.order = testOrder();
      expect(await backFrom(tester, '/orders/order-1'), '/orders');
    });

    testWidgets('My Orders goes to the Dashboard', (tester) async {
      expect(await backFrom(tester, '/orders'), '/dashboard');
    });

    testWidgets('checkout goes to the cart', (tester) async {
      cart.lines = [testCartLine('v1')];
      expect(await backFrom(tester, '/checkout'), '/cart');
    });

    testWidgets('Buy Now checkout goes to Products', (tester) async {
      expect(await backFrom(tester, '/checkout/v1'), '/products');
    });

    testWidgets('a confirm dialog closes first, and stays on the screen', (
      tester,
    ) async {
      orders.order = testOrder();
      await pump(tester);
      await goTo(tester, '/orders/order-1');
      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();
      expect(find.text('Keep order'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Keep order'), findsNothing);
      expect(find.text('Order details'), findsOneWidget);
    });
  });

  testWidgets('a guest pressing the cart icon goes to sign in', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository(), catalog: catalog);

    await tester.tap(find.byTooltip('Cart'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('the cart button on a card adds and shows in the badge', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Add to cart').first);
    await tester.pumpAndSettle();

    expect(cart.calls, ['addProduct:1']);
    expect(find.text('Added to cart'), findsOneWidget);
    expect(find.byTooltip('Cart, 1 item'), findsOneWidget);

    // It must clear by itself, because it covers the product cards.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Added to cart'), findsNothing);
  });

  testWidgets('a product with choices opens its page from the card', (
    tester,
  ) async {
    await pump(tester);
    cart.failWith = const ServerFailure('x', code: 'VARIANT_REQUIRED');

    await tester.tap(find.byTooltip('Add to cart').first);
    await tester.pumpAndSettle();

    expect(find.text('Buy Now'), findsOneWidget);
  });

  testWidgets('own listing refusal is explained', (tester) async {
    await pump(tester);
    cart.failWith = const ServerFailure('x', code: 'OWN_PRODUCT');

    await tester.tap(find.byTooltip('Add to cart').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('your own listing'), findsOneWidget);
  });

  testWidgets('an empty cart offers browsing', (tester) async {
    await pump(tester);
    await goTo(tester, '/cart');

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Browse products'), findsOneWidget);
  });

  testWidgets('the cart changes quantities and shows server totals', (
    tester,
  ) async {
    cart.lines = [testCartLine('v1', quantity: 2, stock: 3)];
    await pump(tester);
    await goTo(tester, '/cart');

    expect(find.text('৳2,060'), findsOneWidget);

    await tester.tap(find.byTooltip('One more'));
    await tester.pumpAndSettle();

    expect(cart.calls, ['setQuantity:v1:3']);
    expect(find.text('৳3,060'), findsOneWidget);
    // That is all the stock, so no more can be added.
    final more = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.add_circle_outline_rounded),
    );
    expect(more.onPressed, isNull);

    await tester.tap(find.byTooltip('Remove from cart'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  testWidgets('a problem line blocks checkout until it is fixed', (
    tester,
  ) async {
    cart.lines = [
      testCartLine('v1', problem: CartProblem.unavailable),
      testCartLine('v2'),
    ];
    await pump(tester);
    await goTo(tester, '/cart');

    expect(find.text('No longer available'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Checkout'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('checkout needs a verified phone', (tester) async {
    cart.lines = [testCartLine('v1')];
    await pump(tester, verified: false);
    await goTo(tester, '/checkout');

    expect(find.text('Checkout'), findsNothing);
    expect(find.textContaining('phone', findRichText: true), findsWidgets);
  });

  testWidgets('placing an order empties the badge and shows success', (
    tester,
  ) async {
    cart.lines = [testCartLine('v1')];
    orders.onPlaced = () => cart.lines = [];
    await pump(tester);
    await goTo(tester, '/checkout');

    expect(find.text('Cash on Delivery'), findsOneWidget);
    await tester.tap(find.text('Place order · ৳1,060'));
    await tester.pumpAndSettle();

    expect(orders.lastAddressId, 'a1');
    expect(orders.lastExpectedTotal, 1060);
    expect(find.text('Your order is placed'), findsOneWidget);
    expect(find.text('BR-100001'), findsOneWidget);
  });

  testWidgets('checkout without an address asks for one first', (tester) async {
    cart.lines = [testCartLine('v1')];
    addresses.addresses = [];
    await pump(tester);
    await goTo(tester, '/checkout');

    expect(find.text('Add a delivery address'), findsOneWidget);
    expect(orders.placeKeys, isEmpty);
  });

  testWidgets('a refused order stays on checkout with the reason', (
    tester,
  ) async {
    cart.lines = [testCartLine('v1')];
    orders.failWith = const ServerFailure('x', code: 'OUT_OF_STOCK');
    await pump(tester);
    await goTo(tester, '/checkout');

    await tester.tap(find.text('Place order · ৳1,060'));
    await tester.pumpAndSettle();

    expect(find.textContaining('enough stock'), findsOneWidget);
    expect(find.text('Your order is placed'), findsNothing);
  });

  testWidgets('Buy Now from product details checks out that variant', (
    tester,
  ) async {
    await pump(tester);
    await goTo(tester, '/product/1');

    await tester.tap(find.text('Buy Now'));
    await tester.pumpAndSettle();

    expect(cart.calls.single, startsWith('getBuyNow:'));
    expect(find.text('Checkout'), findsOneWidget);
  });

  testWidgets('a buyer can cancel a pending order after confirming', (
    tester,
  ) async {
    orders.order = testOrder();
    await pump(tester);
    await goTo(tester, '/orders/order-1');

    expect(find.text('Pending'), findsOneWidget);
    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep order'));
    await tester.pumpAndSettle();
    expect(orders.lastCancelledGroupId, isNull);

    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel order').last);
    await tester.pumpAndSettle();

    expect(orders.lastCancelledGroupId, 'group-1');
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Cancel order'), findsNothing);
    expect(find.text('To pay after cancellations'), findsOneWidget);
  });

  testWidgets('an order out for delivery cannot be cancelled', (tester) async {
    orders.order = testOrder(status: OrderStatus.outForDelivery);
    await pump(tester);
    await goTo(tester, '/orders/order-1');

    expect(find.text('Out for delivery'), findsOneWidget);
    expect(find.text('Cancel order'), findsNothing);
  });

  testWidgets('My Orders lists orders and opens the details', (tester) async {
    orders.order = testOrder();
    orders.summaries = [
      OrderSummary(
        id: 'order-1',
        orderNumber: 'BR-100001',
        grandTotal: 1060,
        createdAt: DateTime(2026, 11, 5),
        groups: const [
          OrderGroupSummary(
            id: 'group-1',
            shopName: 'Test Shop',
            status: OrderStatus.packaging,
            itemCount: 3,
            firstTitle: 'Test Lamp',
          ),
        ],
      ),
    ];
    await pump(tester);
    await goTo(tester, '/orders');

    expect(find.text('Test Lamp and 2 more'), findsOneWidget);
    expect(find.text('Packaging'), findsOneWidget);

    await tester.tap(find.text('BR-100001'));
    await tester.pumpAndSettle();
    expect(find.text('Order details'), findsOneWidget);
  });

  test('order rows parse, sorted by shop, with a deleted seller', () {
    final detail = OrderModel.detailFromJson({
      'id': 'o1',
      'order_number': 'BR-1',
      'subtotal': 300,
      'delivery_total': 60,
      'grand_total': 360,
      'created_at': '2026-11-05T10:00:00Z',
      'seller_order_groups': [
        {
          'id': 'g2',
          'shop_id': null,
          'shop_name': 'Zeta',
          'status': 'cancelled',
          'subtotal': 100,
          'delivery_fee': 60,
          'shipping_address': {'recipient_name': 'A', 'line1': 'B'},
          'order_items': <Map<String, dynamic>>[],
        },
        {
          'id': 'g1',
          'shop_id': 's1',
          'shop_name': 'Alpha',
          'status': 'out_for_delivery',
          'subtotal': 200,
          'delivery_fee': 0,
          'shipping_address': {'recipient_name': 'A', 'line1': 'B'},
          'order_items': [
            {
              'id': 'i1',
              'product_id': null,
              'product_title': 'Lamp',
              'variant_name': 'Default',
              'image_path': null,
              'unit_price': 100,
              'quantity': 2,
              'line_total': 200,
              'created_at': '2026-11-05T10:00:00Z',
            },
          ],
        },
      ],
    }, (path) => path);

    expect(detail.groups.first.shopName, 'Alpha');
    expect(detail.groups.first.status, OrderStatus.outForDelivery);
    expect(detail.groups.last.shopId, isNull);
    expect(detail.amountToPay, 200);
    expect(detail.hasClosedParts, isTrue);
    expect(detail.groups.first.items.single.variantLabel, isNull);
  });
}
