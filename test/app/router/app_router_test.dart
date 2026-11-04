import 'package:browsly_app/app/router/app_router.dart';
import 'package:browsly_app/app/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveRedirect', () {
    test('sends guests to login and remembers the destination', () {
      expect(
        resolveRedirect(isSignedIn: false, path: AppRoutes.post),
        '/login?from=%2Fpost',
      );
    });

    test('lets guests browse public screens', () {
      expect(
        resolveRedirect(isSignedIn: false, path: AppRoutes.products),
        isNull,
      );
    });

    test('returns signed-in users to their destination', () {
      expect(
        resolveRedirect(
          isSignedIn: true,
          path: AppRoutes.login,
          from: AppRoutes.sales,
        ),
        AppRoutes.sales,
      );
    });

    test('ignores destinations outside the app', () {
      for (final from in ['//example.com', 'https://example.com', null]) {
        expect(
          resolveRedirect(isSignedIn: true, path: AppRoutes.login, from: from),
          AppRoutes.dashboard,
        );
      }
    });
  });
}
