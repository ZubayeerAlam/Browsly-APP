import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/core/errors/error_mapper.dart';
import 'package:browsly_app/core/widgets/app_network_image.dart';
import 'package:browsly_app/features/orders/domain/entities/order.dart';
import 'package:browsly_app/features/orders/presentation/widgets/order_timeline.dart';
import 'package:browsly_app/features/sales/data/models/sale_models.dart';
import 'package:browsly_app/features/sales/domain/entities/sale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeSalesRepository sales;

  setUp(() {
    AppNetworkImage.debugBuilder = (url) => const SizedBox();
    sales = FakeSalesRepository();
  });

  tearDown(() => AppNetworkImage.debugBuilder = null);

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      auth: FakeAuthRepository(user: verifiedUser),
      sales: sales,
    );
  }

  Future<void> goTo(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }

  Finder inScreen(String text) => find.text(text);

  testWidgets('tabs show only orders with that status', (tester) async {
    sales.sales = [
      testSale(id: 'a'),
      testSale(id: 'b', status: OrderStatus.packaging),
    ];
    await pump(tester);
    await goTo(tester, '/sales');

    expect(inScreen('BR-100001'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(5));

    await tester.tap(find.widgetWithText(Tab, 'Complete'));
    await tester.pumpAndSettle();
    expect(find.text('No sales yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Packaging'));
    await tester.pumpAndSettle();
    expect(inScreen('BR-100001'), findsOneWidget);
  });

  testWidgets('a seller moves an order through every step to Complete', (
    tester,
  ) async {
    sales.sale = testSaleDetail();
    await pump(tester);
    await goTo(tester, '/sale/sale-1');

    expect(find.text('Test Person'), findsOneWidget);
    expect(find.textContaining('+8801700000000'), findsOneWidget);
    expect(find.text('Cash to collect'), findsOneWidget);

    await tester.tap(find.text('Start packaging'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark out for delivery'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel order'), findsNothing);
    await tester.tap(find.text('Delivered, cash collected'));
    await tester.pumpAndSettle();
    expect(find.textContaining('collected ৳1,060'), findsOneWidget);
    expect(find.textContaining('৳10 commission'), findsOneWidget);

    await tester.tap(find.text('Not yet'));
    await tester.pumpAndSettle();
    expect(sales.calls.last, contains('outForDelivery'));

    await tester.tap(find.text('Delivered, cash collected'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm delivered'));
    await tester.pumpAndSettle();

    expect(sales.calls, [
      'setStatus:sale-1:packaging:null',
      'setStatus:sale-1:outForDelivery:null',
      'setStatus:sale-1:completed:null',
    ]);
    expect(find.text('Commission charged: ৳10'), findsOneWidget);
    expect(find.text('Start packaging'), findsNothing);
    expect(find.text('Delivered, cash collected'), findsNothing);
  });

  testWidgets('a seller can cancel and give the buyer a reason', (
    tester,
  ) async {
    sales.sale = testSaleDetail();
    await pump(tester);
    await goTo(tester, '/sale/sale-1');

    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Out of stock ');
    await tester.tap(find.text('Cancel order').last);
    await tester.pumpAndSettle();

    expect(sales.calls, ['cancel:sale-1:Out of stock']);
    expect(find.text('No commission on this order'), findsOneWidget);
    expect(find.text('Start packaging'), findsNothing);
  });

  testWidgets('backing out of cancelling changes nothing', (tester) async {
    sales.sale = testSaleDetail();
    await pump(tester);
    await goTo(tester, '/sale/sale-1');

    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep order'));
    await tester.pumpAndSettle();

    expect(sales.calls, isEmpty);
  });

  testWidgets('a failed delivery can be recorded', (tester) async {
    sales.sale = testSaleDetail(status: OrderStatus.outForDelivery);
    await pump(tester);
    await goTo(tester, '/sale/sale-1');

    await tester.tap(find.text('Delivery failed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delivery failed').last);
    await tester.pumpAndSettle();

    expect(sales.calls, ['setStatus:sale-1:deliveryFailed:null']);
  });

  testWidgets('a refused change is explained, and the order reloaded', (
    tester,
  ) async {
    sales
      ..sale = testSaleDetail()
      ..actionFailure = const ServerFailure('x', code: 'INVALID_STATUS_CHANGE');
    await pump(tester);
    await goTo(tester, '/sale/sale-1');

    await tester.tap(find.text('Start packaging'));
    await tester.pumpAndSettle();

    expect(find.textContaining('already moved on'), findsOneWidget);
  });

  testWidgets('another shop\'s order shows as not found', (tester) async {
    await pump(tester);
    await goTo(tester, '/sale/other');

    expect(find.text('We could not find this order'), findsOneWidget);
  });

  testWidgets('Commission shows what is owed and the history', (tester) async {
    sales
      ..summary = const CommissionSummary(
        balance: 6,
        totalCharged: 10,
        totalPaid: 4,
        commissionRate: 1,
        blockLimit: 5000,
        isBlocked: false,
      )
      ..entries = [
        CommissionEntry(
          id: 'b',
          type: CommissionEntryType.settlement,
          amount: -4,
          createdAt: DateTime(2026, 11, 6),
          method: 'bKash',
          reference: 'TX1',
        ),
        CommissionEntry(
          id: 'a',
          type: CommissionEntryType.charge,
          amount: 10,
          createdAt: DateTime(2026, 11, 5),
          orderNumber: 'BR-100001',
        ),
      ];
    await pump(tester);
    await goTo(tester, '/commission');

    expect(find.text('৳6'), findsOneWidget);
    expect(find.text('Charged ৳10 · Paid ৳4'), findsOneWidget);
    expect(find.textContaining('1% of the listing price'), findsOneWidget);
    expect(find.text('Payment by bKash'), findsOneWidget);
    expect(find.text('−৳4'), findsOneWidget);
    expect(find.text('Commission on BR-100001'), findsOneWidget);
    expect(find.text('+৳10'), findsOneWidget);
    expect(find.textContaining("can't post new listings"), findsNothing);
  });

  testWidgets('a seller over the limit is told', (tester) async {
    sales.summary = const CommissionSummary(
      balance: 6000,
      totalCharged: 6000,
      totalPaid: 0,
      commissionRate: 1,
      blockLimit: 5000,
      isBlocked: true,
    );
    await pump(tester);
    await goTo(tester, '/commission');

    expect(find.textContaining("can't post new listings"), findsOneWidget);
  });

  group('the buyer timeline', () {
    Future<void> show(
      WidgetTester tester,
      OrderStatus status,
      List<OrderStatusEvent> history,
    ) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderTimeline(status: status, history: history),
          ),
        ),
      );
    }

    OrderStatusEvent event(OrderStatus status, {String? note}) {
      return OrderStatusEvent(
        status: status,
        createdAt: DateTime(2026, 11, 5, 14, 30),
        note: note,
      );
    }

    testWidgets('shows all four steps while in progress', (tester) async {
      await show(tester, OrderStatus.packaging, [
        event(OrderStatus.pending),
        event(OrderStatus.packaging),
      ]);

      for (final label in [
        'Pending',
        'Packaging',
        'Out for delivery',
        'Complete',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('5 Nov, 2:30 PM'), findsNWidgets(2));
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
      expect(
        find.byIcon(Icons.radio_button_unchecked_rounded),
        findsNWidgets(2),
      );
    });

    testWidgets('stops at the step reached, with the reason', (tester) async {
      await show(tester, OrderStatus.cancelled, [
        event(OrderStatus.pending),
        event(OrderStatus.cancelled, note: 'Out of stock'),
      ]);

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Out of stock'), findsOneWidget);
      expect(find.text('Complete'), findsNothing);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    });
  });

  test('sale rows parse from the server', () {
    final detail = SaleModel.detailFromJson({
      'id': 'g1',
      'order_number': 'BR-1',
      'status': 'out_for_delivery',
      'subtotal': 1000,
      'delivery_fee': 60,
      'commission_total': 10,
      'created_at': '2026-11-05T10:00:00Z',
      'shipping_address': {
        'recipient_name': 'A',
        'phone': '+880',
        'line1': 'B',
      },
      'items': [
        {
          'id': 'i1',
          'product_id': null,
          'product_title': 'Lamp',
          'variant_name': 'Default',
          'image_path': 'p/a.jpg',
          'unit_price': 1000,
          'quantity': 1,
          'line_total': 1000,
        },
      ],
      'history': [
        {
          'status': 'pending',
          'note': null,
          'created_at': '2026-11-05T10:00:00Z',
        },
      ],
    }, (path) => 'url/$path');

    expect(detail.status, OrderStatus.outForDelivery);
    expect(detail.amountToCollect, 1060);
    expect(detail.items.single.imageUrl, 'url/p/a.jpg');
    expect(detail.history.single.status, OrderStatus.pending);
    expect(SaleModel.statusesFor(SaleTab.closed), [
      'cancelled',
      'delivery_failed',
    ]);
  });

  test('owing commission explains why an account cannot be deleted', () {
    final failure = mapErrorToFailure(
      const FunctionException(
        status: 409,
        details: {'code': 'OWES_COMMISSION'},
      ),
    );

    expect((failure as ServerFailure).code, 'OWES_COMMISSION');
    expect(failure.message, contains('owe commission'));
  });
}
