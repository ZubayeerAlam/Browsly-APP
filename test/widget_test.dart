import 'dart:async';

import 'package:browsly_app/app/app.dart';
import 'package:browsly_app/app/theme/app_theme.dart';
import 'package:browsly_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({required this.isSignedIn});

  final _controller = StreamController<bool>.broadcast();

  @override
  bool isSignedIn;

  @override
  Stream<bool> get signedInChanges => _controller.stream;

  void emit(bool value) {
    isSignedIn = value;
    _controller.add(value);
  }

  @override
  Future<void> signOut() async => emit(false);
}

Future<void> pumpApp(WidgetTester tester, AuthRepository repository) async {
  await tester.pumpWidget(
    BrowslyApp(
      authRepository: repository,
      theme: AppTheme.light(baseTextTheme: ThemeData().textTheme),
    ),
  );
  await tester.pumpAndSettle();
}

Finder navItem(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('shows all five navigation items in order', (tester) async {
    await pumpApp(tester, FakeAuthRepository(isSignedIn: false));

    final labels = ['Dashboard', 'Products', 'Sales', 'Statistics', 'Post'];
    final positions = labels
        .map((label) => tester.getCenter(navItem(label)).dx)
        .toList();

    expect(positions, orderedEquals([...positions]..sort()));
    expect(find.byIcon(Icons.edit_square), findsOneWidget);
  });

  testWidgets('guests can open Products', (tester) async {
    await pumpApp(tester, FakeAuthRepository(isSignedIn: false));

    await tester.tap(navItem('Products'));
    await tester.pumpAndSettle();

    expect(find.text('No products yet'), findsOneWidget);
  });

  for (final tab in ['Sales', 'Statistics', 'Post']) {
    testWidgets('guests are sent to login from $tab', (tester) async {
      await pumpApp(tester, FakeAuthRepository(isSignedIn: false));

      await tester.tap(navItem(tab));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to continue'), findsOneWidget);
    });
  }

  testWidgets('signed-in users can open Sales', (tester) async {
    await pumpApp(tester, FakeAuthRepository(isSignedIn: true));

    await tester.tap(navItem('Sales'));
    await tester.pumpAndSettle();

    expect(find.text('No sales yet'), findsOneWidget);
  });

  testWidgets('Post opens full screen and back returns to the tab', (
    tester,
  ) async {
    await pumpApp(tester, FakeAuthRepository(isSignedIn: true));

    await tester.tap(navItem('Post'));
    await tester.pumpAndSettle();

    expect(find.text('Create Your Listing'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Your summary is added in Step 6.'), findsOneWidget);
  });

  testWidgets('signing in returns the user to the screen they wanted', (
    tester,
  ) async {
    final repository = FakeAuthRepository(isSignedIn: false);
    await pumpApp(tester, repository);

    await tester.tap(navItem('Sales'));
    await tester.pumpAndSettle();
    repository.emit(true);
    await tester.pumpAndSettle();

    expect(find.text('No sales yet'), findsOneWidget);
  });

  testWidgets('signing out leaves a protected screen', (tester) async {
    final repository = FakeAuthRepository(isSignedIn: true);
    await pumpApp(tester, repository);

    await tester.tap(navItem('Sales'));
    await tester.pumpAndSettle();
    repository.emit(false);
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
  });
}
