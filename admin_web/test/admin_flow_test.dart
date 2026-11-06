import 'package:browsly_admin/core/errors/app_failure.dart';
import 'package:browsly_admin/features/orders/orders_data.dart';
import 'package:browsly_admin/features/products/products_data.dart';
import 'package:browsly_admin/features/reports/reports_data.dart';
import 'package:browsly_admin/features/settlements/settlements_data.dart';
import 'package:browsly_admin/features/users/users_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late Fakes fakes;

  setUp(() => fakes = Fakes());

  group('Login', () {
    testWidgets('someone signed out only sees the login page', (tester) async {
      fakes.auth.signedIn = false;
      await pumpAdmin(tester, fakes);

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('an admin gets in', (tester) async {
      fakes.auth.signedIn = false;
      await pumpAdmin(tester, fakes);

      await tester.enterText(find.byType(TextField).first, 'a@example.test');
      await tester.enterText(find.byType(TextField).last, 'secret-value');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Waiting for review'), findsOneWidget);
    });

    testWidgets('someone who is not an admin is signed out and told', (
      tester,
    ) async {
      fakes.auth
        ..signedIn = false
        ..admin = false;
      await pumpAdmin(tester, fakes);

      await tester.enterText(find.byType(TextField).first, 'a@example.test');
      await tester.enterText(find.byType(TextField).last, 'secret-value');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('This account is not an admin.'), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(fakes.auth.signedIn, isFalse);
    });

    testWidgets('a saved session of a non-admin does not get in', (
      tester,
    ) async {
      fakes.auth.admin = false;
      await pumpAdmin(tester, fakes);

      expect(find.byType(NavigationRail), findsNothing);
      expect(fakes.auth.signedIn, isFalse);
    });

    testWidgets('a wrong password is explained', (tester) async {
      fakes.auth
        ..signedIn = false
        ..failSignIn = const AuthFailure('The email or password is incorrect.');
      await pumpAdmin(tester, fakes);

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('The email or password is incorrect.'), findsOneWidget);
    });

    testWidgets('logging out returns to login', (tester) async {
      await pumpAdmin(tester, fakes);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
    });
  });

  group('Product Review', () {
    testWidgets('shows the listing and the AI reason', (tester) async {
      fakes.review.queue = [queued('1')];
      await pumpAdmin(tester, fakes);
      await openPage(tester, 'Product Review');

      expect(find.text('Lamp 1'), findsOneWidget);
      expect(find.text('AI: Suspicious'), findsOneWidget);
      expect(find.text('PRICE: Looks too cheap'), findsOneWidget);
    });

    testWidgets('says when the AI was unavailable', (tester) async {
      fakes.review.queue = [queued('1', decision: null)];
      await pumpAdmin(tester, fakes);
      await openPage(tester, 'Product Review');

      expect(find.text('AI unavailable'), findsOneWidget);
    });

    testWidgets('approving takes it off the queue', (tester) async {
      fakes.review.queue = [queued('1')];
      await pumpAdmin(tester, fakes);
      await openPage(tester, 'Product Review');

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();

      expect(fakes.review.decisions, ['approve:1']);
      expect(find.text('Nothing is waiting for review'), findsOneWidget);
    });

    testWidgets('rejecting needs a reason for the seller', (tester) async {
      fakes.review.queue = [queued('1')];
      await pumpAdmin(tester, fakes);
      await openPage(tester, 'Product Review');

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Reject');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '  Fake brand ');
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(fakes.review.decisions, ['reject:1:Fake brand']);
    });

    testWidgets('a refusal from the server is shown', (tester) async {
      fakes.review
        ..queue = [queued('1')]
        ..failWith = const ServerFailure('Already decided.');
      await pumpAdmin(tester, fakes);
      await openPage(tester, 'Product Review');

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();

      expect(find.text('Already decided.'), findsOneWidget);
    });
  });

  testWidgets('Overview shows the counts and opens the queue', (tester) async {
    await pumpAdmin(tester, fakes);

    expect(find.text('৳14.50'), findsOneWidget);
    await tester.tap(find.text('Waiting for review'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing is waiting for review'), findsOneWidget);
  });

  group('Users', () {
    AdminUser user({bool suspended = false, bool admin = false}) => AdminUser(
      id: 'u1',
      name: 'Rahima',
      email: 'r@example.test',
      isSuspended: suspended,
      isAdmin: admin,
      shopName: 'Rahima Shop',
      commissionOwed: 0,
      joinedAt: DateTime(2026, 11),
    );

    testWidgets('suspending warns about the shop and needs a reason', (
      tester,
    ) async {
      fakes.users.users = [user()];
      await pumpAdmin(tester, fakes);
      await openPage(tester, 'Users');

      await tester.tap(find.text('Suspend'));
      await tester.pumpAndSettle();
      expect(find.textContaining('disappear from the marketplace'), findsOne);

      await tester.enterText(find.byType(TextField).last, 'Fake goods');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Suspend'));
      await tester.pumpAndSettle();

      expect(fakes.users.calls, ['u1:true:Fake goods']);
    });

    testWidgets('a suspension can be lifted', (tester) async {
      fakes.users.users = [user(suspended: true)];
      await pumpAdmin(tester, fakes);
      await openPage(tester, 'Users');

      await tester.tap(find.text('Lift suspension'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Lift suspension'));
      await tester.pumpAndSettle();

      expect(fakes.users.calls, ['u1:false:null']);
    });

    testWidgets('admins have no suspend button', (tester) async {
      fakes.users.users = [user(admin: true)];
      await pumpAdmin(tester, fakes);
      await openPage(tester, 'Users');

      expect(find.text('Suspend'), findsNothing);
    });

    testWidgets('searching waits for a pause in typing', (tester) async {
      await pumpAdmin(tester, fakes);
      await openPage(tester, 'Users');

      await tester.enterText(find.byType(TextField), 'rah');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(fakes.users.searches.last, 'rah');
    });
  });

  testWidgets('Products can be filtered and removed with a reason', (
    tester,
  ) async {
    fakes.products.products = const [
      AdminProduct(
        id: 'p1',
        title: 'Lamp',
        shopName: 'Shop',
        status: 'active',
        totalStock: 1,
        soldCount: 0,
        price: 100,
      ),
    ];
    await pumpAdmin(tester, fakes);
    await openPage(tester, 'Products');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Paused'));
    await tester.pumpAndSettle();
    expect(fakes.products.statuses.last, 'paused');

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Counterfeit');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(fakes.products.calls, ['p1:true:Counterfeit']);
  });

  testWidgets('Orders are listed for looking up', (tester) async {
    fakes.orders.orders = [
      AdminOrder(
        id: 'g1',
        orderNumber: 'BR-1',
        shopName: 'Shop',
        buyerName: 'Rahima',
        status: 'out_for_delivery',
        amount: 1060,
        commission: 10,
        createdAt: DateTime(2026, 11, 6),
      ),
    ];
    await pumpAdmin(tester, fakes);
    await openPage(tester, 'Orders');

    expect(find.text('BR-1'), findsOneWidget);
    expect(find.text('৳1,060'), findsOneWidget);
    expect(find.text('Out for delivery'), findsWidgets);
  });

  testWidgets('A category can be added', (tester) async {
    await pumpAdmin(tester, fakes);
    await openPage(tester, 'Categories');

    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Toys');
    await tester.enterText(find.widgetWithText(TextField, 'Web name'), 'toys');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(fakes.categories.saved.single.slug, 'toys');
    expect(fakes.categories.saved.single.parentId, isNull);
  });

  testWidgets('Settings load, and only save after confirming', (tester) async {
    await pumpAdmin(tester, fakes);
    await openPage(tester, 'Settings');

    await tester.enterText(
      find.widgetWithText(TextField, 'Commission rate (%)'),
      '2',
    );
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    expect(fakes.settings.updated, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(fakes.settings.updated!.commissionRate, 2);
    expect(fakes.settings.updated!.commissionBlockLimit, 5000);
    expect(find.text('Saved.'), findsOneWidget);
  });

  testWidgets('Settings refuse text that is not a number', (tester) async {
    await pumpAdmin(tester, fakes);
    await openPage(tester, 'Settings');

    await tester.enterText(
      find.widgetWithText(TextField, 'Commission rate (%)'),
      'abc',
    );
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter numbers only.'), findsOneWidget);
    expect(fakes.settings.updated, isNull);
  });

  group('Reports', () {
    AdminReport report(String type) => AdminReport(
      id: 'r1',
      targetType: type,
      targetId: 't1',
      reason: 'offensive',
      details: 'Very rude',
      reporterName: 'Karim',
      createdAt: DateTime(2026, 11, 6),
      isOpen: true,
      targetText: 'The reported words',
      targetUserId: 'u9',
    );

    testWidgets('shows what was reported and closes it', (tester) async {
      fakes.reports.reports = [report('message')];
      await pumpAdmin(tester, fakes);
      await openPage(tester, 'Reports');

      expect(find.text('The reported words'), findsOneWidget);
      expect(find.text('They said: Very rude'), findsOneWidget);
      expect(find.text('Remove listing'), findsNothing);

      await tester.tap(find.text('Uphold'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Warned them');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Uphold').last);
      await tester.pumpAndSettle();

      expect(fakes.reports.calls, contains('close:r1:true:Warned them'));
    });

    testWidgets('a product report offers to remove it', (tester) async {
      fakes.reports.reports = [report('product')];
      await pumpAdmin(tester, fakes);
      await openPage(tester, 'Reports');

      await tester.tap(find.text('Remove listing'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Fake');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(fakes.reports.calls, contains('removeProduct:t1:Fake'));
      expect(find.textContaining('Listing removed.'), findsOneWidget);
    });

    testWidgets('a review report offers to hide it', (tester) async {
      fakes.reports.reports = [report('review')];
      await pumpAdmin(tester, fakes);
      await openPage(tester, 'Reports');

      await tester.tap(find.text('Hide review'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Hide'));
      await tester.pumpAndSettle();

      expect(fakes.reports.calls, contains('hideReview:t1'));
      expect(find.textContaining('Review hidden.'), findsOneWidget);
    });
  });

  group('Settlements', () {
    const seller = SellerOwing(
      sellerId: 's1',
      shopName: 'Dhaka Shop',
      totalCharged: 100,
      totalPaid: 40,
      balance: 60,
    );

    testWidgets('a payment needs a reference and a valid amount', (
      tester,
    ) async {
      fakes.settlements.owing = [seller];
      await pumpAdmin(tester, fakes);
      await openPage(tester, 'Settlements');

      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Record payment').last;
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      final dialog = find.byType(AlertDialog);
      final fields = find.descendant(
        of: dialog,
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(1), 'TX123');
      await tester.pump();
      await tester.enterText(fields.at(0), '61');
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(find.text('Up to ৳60'), findsOneWidget);

      await tester.enterText(fields.at(0), '60');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(fakes.settlements.recorded, ['s1:60.0:bkash:TX123']);
      expect(find.text('Nobody owes any commission'), findsOneWidget);
    });
  });
}
