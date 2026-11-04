import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

Finder navItem(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('shows all five navigation items in order', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository());

    final labels = ['Dashboard', 'Products', 'Sales', 'Statistics', 'Post'];
    final positions = labels
        .map((label) => tester.getCenter(navItem(label)).dx)
        .toList();

    expect(positions, orderedEquals([...positions]..sort()));
    expect(find.byIcon(Icons.edit_square), findsOneWidget);
  });

  testWidgets('guests can open Products', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository());

    await tester.tap(navItem('Products'));
    await tester.pumpAndSettle();

    expect(find.text('No products yet'), findsOneWidget);
  });

  for (final tab in ['Sales', 'Statistics', 'Post']) {
    testWidgets('guests are sent to login from $tab', (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository());

      await tester.tap(navItem(tab));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
    });
  }

  testWidgets('signed-in users can open Sales', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository(user: testUser));

    await tester.tap(navItem('Sales'));
    await tester.pumpAndSettle();

    expect(find.text('No sales yet'), findsOneWidget);
  });

  testWidgets('Post opens full screen for a verified user', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository(user: verifiedUser));

    await tester.tap(navItem('Post'));
    await tester.pumpAndSettle();

    expect(find.text('Create Your Listing'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Post asks an unverified user to verify, then continues', (
    tester,
  ) async {
    final auth = FakeAuthRepository(user: testUser);
    await pumpApp(tester, auth: auth);

    await tester.tap(navItem('Post'));
    await tester.pumpAndSettle();
    expect(find.text('Verify your phone'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '01700000000');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(auth.calls, contains('phoneLinkCode:+8801700000000'));
    expect(find.text('Enter your code'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(auth.calls, contains('phoneLink:+8801700000000:123456'));
    expect(find.text('Create Your Listing'), findsOneWidget);
  });

  testWidgets('signing in returns the user to the screen they wanted', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpApp(tester, auth: auth);

    await tester.tap(navItem('Sales'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('signIn:a@example.com'));
    expect(find.text('No sales yet'), findsOneWidget);
  });

  testWidgets('signing out leaves a protected screen', (tester) async {
    final auth = FakeAuthRepository(user: testUser);
    await pumpApp(tester, auth: auth);

    await tester.tap(navItem('Sales'));
    await tester.pumpAndSettle();
    auth.emitUser(null);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('a password reset link opens the new password screen', (
    tester,
  ) async {
    final auth = FakeAuthRepository(user: testUser);
    await pumpApp(tester, auth: auth);

    auth.emitPasswordRecovery();
    await tester.pumpAndSettle();
    expect(find.text('Choose a new password'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'newpassword1');
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('updatePassword'));
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Choose a new password'), findsNothing);
  });

  testWidgets('the Google button stays hidden until it is set up', (
    tester,
  ) async {
    await pumpApp(tester, auth: FakeAuthRepository());

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with phone'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('login checks the form before calling the server', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpApp(tester, auth: auth);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('sign-up shows the check-your-email screen', (tester) async {
    final auth = FakeAuthRepository();
    await pumpApp(tester, auth: auth);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('New to Browsly? Create an account'));
    await tester.tap(find.text('New to Browsly? Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'New User');
    await tester.enterText(find.byType(TextFormField).at(1), 'new@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('signUp:New User:new@example.com'));
    expect(find.text('Check your email'), findsOneWidget);
  });
}
