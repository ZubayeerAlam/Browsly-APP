import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/core/widgets/app_network_image.dart';
import 'package:browsly_app/core/widgets/pill_chip.dart';
import 'package:browsly_app/features/chat/domain/entities/chat.dart';
import 'package:browsly_app/features/chat/presentation/providers/chat_room_provider.dart';
import 'package:browsly_app/features/notifications/domain/entities/app_notification.dart';
import 'package:browsly_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:browsly_app/features/orders/domain/entities/order.dart';
import 'package:browsly_app/features/reviews/domain/entities/review.dart';
import 'package:browsly_app/features/statistics/domain/entities/seller_stats.dart';
import 'package:browsly_app/features/statistics/presentation/widgets/daily_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fakes.dart';

ChatMessage message(String id, String body, {String? sender, int minute = 0}) {
  return ChatMessage(
    id: id,
    conversationId: 'chat-1',
    senderId: sender,
    body: body,
    createdAt: DateTime(2026, 11, 6, 10, minute),
  );
}

SellerStats testStats() {
  return SellerStats(
    views: 200,
    clicks: 150,
    orders: 4,
    sales: 5200,
    daily: [
      for (var day = 1; day <= 7; day++)
        DayStats(
          day: DateTime(2026, 11, day),
          views: day * 10,
          clicks: day,
          orders: 1,
          sales: day * 100.0,
        ),
    ],
    topProducts: const [
      TopProduct(id: '1', title: 'Best Lamp', views: 90, units: 3, sales: 3000),
    ],
  );
}

void main() {
  late FakeChatRepository chat;
  late FakeNotificationRepository notifications;
  late FakeReviewRepository reviews;
  late FakeReportRepository reports;
  late FakeStatisticsRepository statistics;
  late FakeOrderRepository orders;
  late FakeCatalogRepository catalog;
  late FakeSalesRepository sales;

  setUp(() {
    AppNetworkImage.debugBuilder = (url) => const SizedBox();
    chat = FakeChatRepository();
    notifications = FakeNotificationRepository();
    reviews = FakeReviewRepository();
    reports = FakeReportRepository();
    statistics = FakeStatisticsRepository();
    orders = FakeOrderRepository();
    sales = FakeSalesRepository();
    catalog = FakeCatalogRepository()..products = [testProduct('1')];
    catalog.details['1'] = testDetail('1');
  });

  tearDown(() => AppNetworkImage.debugBuilder = null);

  Future<void> pump(WidgetTester tester, {bool signedIn = true}) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      auth: FakeAuthRepository(user: signedIn ? verifiedUser : null),
      chat: chat,
      notifications: notifications,
      reviews: reviews,
      reports: reports,
      statistics: statistics,
      orders: orders,
      catalog: catalog,
      sales: sales,
    );
  }

  Future<void> goTo(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }

  group('Chat', () {
    testWidgets('Chat with seller opens the chat from a product', (
      tester,
    ) async {
      await pump(tester);
      await goTo(tester, '/product/1');

      await tester.ensureVisible(find.text('Chat with seller'));
      await tester.tap(find.text('Chat with seller'));
      await tester.pumpAndSettle();

      expect(chat.calls, contains('startForProduct:1'));
      expect(find.textContaining('Fixed price'), findsOneWidget);
    });

    testWidgets('a guest pressing Chat with seller goes to sign in', (
      tester,
    ) async {
      await pump(tester, signedIn: false);
      await goTo(tester, '/product/1');

      await tester.ensureVisible(find.text('Chat with seller'));
      await tester.tap(find.text('Chat with seller'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(chat.calls, isEmpty);
    });

    testWidgets('chatting about your own listing is explained', (tester) async {
      chat.failWith = const ServerFailure('x', code: 'OWN_PRODUCT');
      await pump(tester);
      await goTo(tester, '/product/1');

      await tester.ensureVisible(find.text('Chat with seller'));
      await tester.tap(find.text('Chat with seller'));
      await tester.pumpAndSettle();

      expect(find.textContaining('your own listing'), findsOneWidget);
    });

    testWidgets('messages send, arrive live and mark as read', (tester) async {
      chat.messages = [message('m1', 'Hello', sender: 'seller')];
      await pump(tester);
      await goTo(tester, '/chats/chat-1');

      expect(find.text('Hello'), findsOneWidget);
      expect(chat.calls, contains('markRead'));
      chat.calls.clear();

      await tester.enterText(find.byType(TextField), '  Is it new?  ');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(chat.calls, ['send:Is it new?']);
      expect(find.text('Is it new?'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      chat.calls.clear();
      chat.receive(
        message('m2', 'Yes, brand new', sender: 'seller', minute: 9),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yes, brand new'), findsOneWidget);
      expect(chat.calls, ['markRead']);

      // The same message arriving again, such as your own, appears once.
      chat.receive(
        message('m2', 'Yes, brand new', sender: 'seller', minute: 9),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yes, brand new'), findsOneWidget);
    });

    testWidgets('a refused message keeps what was typed', (tester) async {
      await pump(tester);
      await goTo(tester, '/chats/chat-1');
      chat.failWith = const ServerFailure('x', code: 'MESSAGE_RATE_LIMIT');

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      expect(find.textContaining('too quickly'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Hello',
      );
    });

    testWidgets('someone else\'s chat shows as not found', (tester) async {
      chat.header = null;
      await pump(tester);
      await goTo(tester, '/chats/other');

      expect(find.text('We could not find this chat'), findsOneWidget);
    });

    testWidgets('long pressing their message offers a report', (tester) async {
      chat.messages = [message('m1', 'Rude message', sender: 'seller')];
      await pump(tester);
      await goTo(tester, '/chats/chat-1');

      await tester.longPress(find.text('Rude message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Offensive or abusive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();

      expect(reports.reports, ['message:m1:offensive:null']);
      expect(find.textContaining('look into this'), findsOneWidget);
    });

    testWidgets('your own message cannot be reported', (tester) async {
      chat.messages = [message('m1', 'Mine', sender: verifiedUser.id)];
      await pump(tester);
      await goTo(tester, '/chats/chat-1');

      await tester.longPress(find.text('Mine'));
      await tester.pumpAndSettle();

      expect(find.text('Send report'), findsNothing);
    });

    testWidgets('the chat list shows unread chats', (tester) async {
      chat.conversations = [
        Conversation(
          id: 'chat-1',
          otherName: 'Dhaka Style House',
          productTitle: 'Test Lamp',
          lastMessage: 'See you soon',
          lastMessageAt: DateTime(2026, 11, 6),
          unreadCount: 2,
        ),
      ];
      await pump(tester);
      await goTo(tester, '/chats');

      expect(find.text('Dhaka Style House'), findsOneWidget);
      expect(find.text('See you soon'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    test('the room only offers paging when a full page arrived', () async {
      chat.messages = [message('m1', 'One')];
      final room = ChatRoomProvider(chat, 'chat-1', 'me');
      addTearDown(room.dispose);
      TestWidgetsFlutterBinding.ensureInitialized();

      await room.load();
      await room.loadMore();

      expect(room.messages, hasLength(1));
      expect(room.isMine(message('m2', 'x', sender: 'me')), isTrue);
    });
  });

  group('Notifications', () {
    testWidgets('badges show unread counts, and only when signed in', (
      tester,
    ) async {
      notifications.counts = const UnreadCounts(notifications: 3, chat: 2);
      await pump(tester);

      expect(find.byTooltip('Notifications, 3 unread'), findsOneWidget);
      expect(find.byTooltip('Chats, 2 unread'), findsOneWidget);
    });

    testWidgets('guests do not see them', (tester) async {
      await pump(tester, signedIn: false);

      expect(find.byTooltip('Notifications'), findsNothing);
      expect(find.byTooltip('Chats'), findsNothing);
    });

    testWidgets('a live notification updates the badge at once', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byTooltip('Notifications'), findsOneWidget);

      notifications.counts = const UnreadCounts(notifications: 1);
      notifications.receive(
        AppNotification(
          id: 'n1',
          type: AppNotificationType.orderUpdate,
          title: 'x',
          body: 'y',
          createdAt: DateTime(2026),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Notifications, 1 unread'), findsOneWidget);
    });

    testWidgets('tapping one marks it read and opens it', (tester) async {
      orders.order = testOrder();
      notifications.items = [
        AppNotification(
          id: 'n1',
          type: AppNotificationType.orderUpdate,
          title: 'Your order is on its way',
          body: 'Keep the cash ready.',
          createdAt: DateTime(2026, 11, 6),
          orderId: 'order-1',
        ),
      ];
      await pump(tester);
      await goTo(tester, '/notifications');

      await tester.tap(find.text('Your order is on its way'));
      await tester.pumpAndSettle();

      expect(notifications.markedRead, ['n1']);
      expect(find.text('Order details'), findsOneWidget);
    });

    testWidgets('all can be marked read', (tester) async {
      notifications.items = [
        AppNotification(
          id: 'n1',
          type: AppNotificationType.listingLive,
          title: 'Your listing is live',
          body: 'Lamp',
          createdAt: DateTime(2026, 11, 6),
        ),
      ];
      await pump(tester);
      await goTo(tester, '/notifications');

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(notifications.markedRead, [null]);
    });

    test('each type opens the right screen', () {
      AppNotification of(
        AppNotificationType type, {
        String? groupId,
        String? orderId,
        String? conversationId,
      }) => AppNotification(
        id: 'n',
        type: type,
        title: '',
        body: '',
        createdAt: DateTime(2026),
        groupId: groupId,
        orderId: orderId,
        conversationId: conversationId,
      );

      expect(
        notificationRoute(of(AppNotificationType.newOrder, groupId: 'g')),
        '/sale/g',
      );
      expect(
        notificationRoute(of(AppNotificationType.orderUpdate, orderId: 'o')),
        '/orders/o',
      );
      expect(
        notificationRoute(of(AppNotificationType.listingLive)),
        '/my-posts',
      );
      expect(
        notificationRoute(of(AppNotificationType.commissionPayment)),
        '/commission',
      );
      expect(
        notificationRoute(
          of(AppNotificationType.chatMessage, conversationId: 'c'),
        ),
        '/chats/c',
      );
    });

    testWidgets('a new order refreshes the Sales list by itself', (
      tester,
    ) async {
      await pump(tester);
      await goTo(tester, '/sales');
      expect(find.text('No sales yet'), findsOneWidget);

      sales.sales = [testSale()];
      notifications.receive(
        AppNotification(
          id: 'n1',
          type: AppNotificationType.newOrder,
          title: 'New order',
          body: '',
          createdAt: DateTime(2026),
          groupId: 'sale-1',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BR-100001'), findsOneWidget);
    });
  });

  group('Reviews', () {
    testWidgets('a product shows its newest reviews', (tester) async {
      reviews.reviews = [
        for (var i = 1; i <= 4; i++)
          Review(
            id: 'r$i',
            rating: 5,
            comment: 'Comment $i',
            reviewerName: 'Rahima',
            createdAt: DateTime(2026, 11, i),
          ),
      ];
      await pump(tester);
      await goTo(tester, '/product/1');

      expect(find.text('Comment 3'), findsOneWidget);
      expect(find.text('Comment 4'), findsNothing);

      await tester.ensureVisible(find.text('See all reviews'));
      await tester.tap(find.text('See all reviews'));
      await tester.pumpAndSettle();
      expect(find.text('Comment 4'), findsOneWidget);
    });

    testWidgets('a completed item can be reviewed', (tester) async {
      orders.order = testOrder(status: OrderStatus.completed);
      await pump(tester);
      await goTo(tester, '/orders/order-1');

      // The fake item has no product ID, as after a seller's account is gone.
      expect(find.text('Write a review'), findsNothing);

      orders.order = testOrderWithProduct(OrderStatus.completed);
      await goTo(tester, '/dashboard');
      await goTo(tester, '/orders/order-1');

      await tester.tap(find.text('Write a review'));
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(FilledButton, 'Submit review');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);

      await tester.tap(find.byTooltip('4 out of 5'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), ' Very good ');
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(reviews.submitted, ['item-1:4:Very good']);
    });

    testWidgets('an unfinished order cannot be reviewed', (tester) async {
      orders.order = testOrderWithProduct(OrderStatus.outForDelivery);
      await pump(tester);
      await goTo(tester, '/orders/order-1');

      expect(find.text('Write a review'), findsNothing);
    });

    testWidgets('a product can be reported', (tester) async {
      await pump(tester);
      await goTo(tester, '/product/1');

      await tester.tap(find.byTooltip('Report this product'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fake or misleading'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Not genuine');
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();

      expect(reports.reports, ['product:1:fake:Not genuine']);
    });

    testWidgets('a report needs a reason', (tester) async {
      await pump(tester);
      await goTo(tester, '/product/1');

      await tester.tap(find.byTooltip('Report this product'));
      await tester.pumpAndSettle();

      final button = find.widgetWithText(FilledButton, 'Send report');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    });
  });

  group('Statistics', () {
    testWidgets('someone with no shop is invited to start', (tester) async {
      await pump(tester);
      await goTo(tester, '/statistics');

      expect(find.text('No statistics yet'), findsOneWidget);
      expect(find.text('Start posting'), findsOneWidget);
    });

    testWidgets('shows totals, the trend and top products', (tester) async {
      statistics.stats = testStats();
      await pump(tester);
      await goTo(tester, '/statistics');

      expect(find.text('200'), findsOneWidget);
      expect(find.text('৳5,200'), findsOneWidget);
      expect(find.text('2.0 per 100 views'), findsOneWidget);
      expect(find.text('Highest day: 70'), findsOneWidget);
      expect(find.text('Best Lamp'), findsOneWidget);

      await tester.tap(find.widgetWithText(PillChip, 'Sales'));
      await tester.pumpAndSettle();
      expect(find.text('Highest day: ৳700'), findsOneWidget);
    });

    testWidgets('the period can change', (tester) async {
      statistics.stats = testStats();
      await pump(tester);
      await goTo(tester, '/statistics');

      await tester.tap(find.text('Last 30 days'));
      await tester.pumpAndSettle();

      expect(statistics.requestedDays.last, 30);
    });

    testWidgets('a chart with no activity draws no bars', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyBarChart(
              label: 'Views',
              formatValue: (value) => '$value',
              points: [ChartPoint(day: DateTime(2026, 11), value: 0)],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(FractionallySizedBox), findsNothing);
    });

    testWidgets('the Dashboard card appears only for a shop owner', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Your shop today'), findsNothing);
    });

    testWidgets('the Dashboard card shows today and alerts', (tester) async {
      statistics.dashboard = const SellerDashboard(
        viewsToday: 12,
        clicksToday: 9,
        salesToday: 1450,
        newOrders: 2,
        ratingAvg: 4.5,
        ratingCount: 8,
        lowStock: 1,
        amountOwed: 14.5,
      );
      await pump(tester);

      expect(find.text('Your shop today'), findsOneWidget);
      expect(find.text('৳1,450'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(
        find.text('2 new orders · 1 low on stock · ৳14.50 owed'),
        findsOneWidget,
      );

      await tester.tap(find.text('View Insights'));
      await tester.pumpAndSettle();
      expect(find.text('No statistics yet'), findsOneWidget);
    });

    testWidgets('opening a product from a card counts a click and a view', (
      tester,
    ) async {
      await pump(tester);
      await goTo(tester, '/products');

      await tester.tap(find.text('Product 1').first);
      await tester.pumpAndSettle();

      expect(statistics.tracked, ['click:1', 'view:1']);
    });

    testWidgets('adding to the cart is counted', (tester) async {
      await pump(tester);
      await goTo(tester, '/product/1');

      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();

      expect(statistics.tracked, contains('cartAdd:1'));
    });
  });
}

OrderDetail testOrderWithProduct(OrderStatus status) {
  return OrderDetail(
    id: 'order-1',
    orderNumber: 'BR-100001',
    subtotal: 1000,
    deliveryTotal: 60,
    grandTotal: 1060,
    createdAt: DateTime(2026, 11, 5),
    groups: [
      OrderGroup(
        id: 'group-1',
        shopId: 'shop-1',
        shopName: 'Test Shop',
        status: status,
        subtotal: 1000,
        deliveryFee: 60,
        items: const [
          OrderItem(
            id: 'item-1',
            productId: '1',
            title: 'Test Lamp',
            unitPrice: 1000,
            quantity: 1,
            lineTotal: 1000,
          ),
        ],
      ),
    ],
  );
}
