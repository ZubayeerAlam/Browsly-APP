import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/features/profile/domain/entities/address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

const _address = Address(
  id: 'address-1',
  recipientName: 'Test User',
  phone: '+8801700000000',
  regionId: 'gazipur',
  districtName: 'Gazipur',
  divisionId: 'dhaka',
  divisionName: 'Dhaka',
  line1: 'House 1',
  isDefault: false,
);

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('settings shows the profile and logs out', (tester) async {
    final auth = FakeAuthRepository(user: testUser);
    await pumpApp(tester, auth: auth);

    await openSettings(tester);
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('a@example.com'), findsOneWidget);

    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('signOut'));
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('editing the name saves and updates settings', (tester) async {
    final profile = FakeProfileRepository();
    await pumpApp(
      tester,
      auth: FakeAuthRepository(user: testUser),
      profile: profile,
    );

    await openSettings(tester);
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  New Name ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(profile.profile.fullName, 'New Name');
    expect(find.text('New Name'), findsOneWidget);
  });

  testWidgets('deleting an account needs confirmation', (tester) async {
    final auth = FakeAuthRepository(user: testUser);
    await pumpApp(tester, auth: auth);

    await openSettings(tester);
    await tester.tap(find.text('Account & Security'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.calls, isNot(contains('deleteAccount')));

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account').last);
    await tester.pumpAndSettle();
    expect(auth.calls, contains('deleteAccount'));
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('a failed delete explains the problem', (tester) async {
    final auth = FakeAuthRepository(user: testUser);
    await pumpApp(tester, auth: auth);

    await openSettings(tester);
    await tester.tap(find.text('Account & Security'));
    await tester.pumpAndSettle();
    auth.failWith = const NetworkFailure();

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('internet connection'), findsOneWidget);
    expect(find.text('Account & Security'), findsOneWidget);
  });

  group('addresses', () {
    Future<void> openAddresses(WidgetTester tester) async {
      await openSettings(tester);
      await tester.tap(find.text('Addresses'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the empty state', (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository(user: testUser));
      await openAddresses(tester);
      expect(find.text('No addresses yet'), findsOneWidget);
    });

    testWidgets('adds an address with a normalized phone', (tester) async {
      final repository = FakeAddressRepository();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(user: testUser),
        addresses: repository,
      );
      await openAddresses(tester);

      await tester.tap(find.text('Add address'));
      await tester.pumpAndSettle();

      // The form refuses to save until a district is chosen.
      await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
      await tester.enterText(find.byType(TextFormField).at(1), '01700000000');
      await tester.enterText(find.byType(TextFormField).at(2), 'House 1');
      await tester.ensureVisible(find.text('Save address'));
      await tester.tap(find.text('Save address'));
      await tester.pumpAndSettle();
      expect(find.text('Please choose District'), findsOneWidget);
      expect(repository.lastInput, isNull);

      // Choosing a division offers only its own districts.
      await tester.ensureVisible(find.text('Division'));
      await tester.tap(find.text('Division'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dhaka').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('District'));
      await tester.pumpAndSettle();
      expect(find.text('Sunamganj'), findsNothing);
      await tester.tap(find.text('Tangail').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save address'));
      await tester.tap(find.text('Save address'));
      await tester.pumpAndSettle();

      expect(repository.lastInput?.phone, '+8801700000000');
      expect(repository.lastInput?.regionId, 'tangail');
      expect(find.text('Addresses'), findsOneWidget);
    });

    testWidgets('edits, sets default and deletes', (tester) async {
      final repository = FakeAddressRepository()..addresses = [_address];
      await pumpApp(
        tester,
        auth: FakeAuthRepository(user: testUser),
        addresses: repository,
      );
      await openAddresses(tester);

      expect(find.text('House 1, Gazipur, Dhaka'), findsOneWidget);

      await tester.tap(find.text('Make default'));
      await tester.pumpAndSettle();
      expect(repository.lastDefaultId, 'address-1');

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(2), 'House 2');
      await tester.ensureVisible(find.text('Save address'));
      await tester.tap(find.text('Save address'));
      await tester.pumpAndSettle();
      expect(repository.lastUpdatedId, 'address-1');
      expect(repository.lastInput?.line1, 'House 2');
      expect(repository.lastInput?.regionId, 'gazipur');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(repository.lastDeletedId, 'address-1');
    });

    testWidgets('load failure offers a retry', (tester) async {
      final repository = FakeAddressRepository()
        ..failWith = const NetworkFailure();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(user: testUser),
        addresses: repository,
      );
      await openAddresses(tester);
      expect(find.text('Try again'), findsOneWidget);

      repository.failWith = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No addresses yet'), findsOneWidget);
    });
  });
}
