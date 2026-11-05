import 'package:browsly_app/app/router/app_router.dart';
import 'package:browsly_app/app/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

String? redirect({
  bool isSignedIn = false,
  bool isPhoneVerified = false,
  bool isRecoveringPassword = false,
  required String path,
  String? from,
}) {
  return resolveRedirect(
    isSignedIn: isSignedIn,
    isPhoneVerified: isPhoneVerified,
    isRecoveringPassword: isRecoveringPassword,
    path: path,
    from: from,
  );
}

void main() {
  group('guests', () {
    test('are sent to login and the destination is remembered', () {
      expect(redirect(path: AppRoutes.post), '/login?from=%2Fpost');
    });

    test('cannot open account screens', () {
      for (final path in [
        AppRoutes.settings,
        AppRoutes.editProfile,
        AppRoutes.addresses,
        AppRoutes.addressForm,
        AppRoutes.verifyPhone,
        AppRoutes.wishlist,
      ]) {
        expect(redirect(path: path), startsWith('/login'), reason: path);
      }
    });

    test('can browse public screens and sign-in screens', () {
      for (final path in [
        AppRoutes.dashboard,
        AppRoutes.products,
        AppRoutes.search,
        AppRoutes.product('some-id'),
        AppRoutes.shop('some-id'),
        AppRoutes.login,
        AppRoutes.signUp,
        AppRoutes.phoneSignIn,
      ]) {
        expect(redirect(path: path), isNull, reason: path);
      }
    });
  });

  group('signed-in users', () {
    test('return to their destination after signing in', () {
      expect(
        redirect(
          isSignedIn: true,
          path: AppRoutes.login,
          from: AppRoutes.sales,
        ),
        AppRoutes.sales,
      );
    });

    test('ignore destinations outside the app', () {
      for (final from in ['//example.com', 'https://example.com', null]) {
        expect(
          redirect(isSignedIn: true, path: AppRoutes.login, from: from),
          AppRoutes.dashboard,
        );
      }
    });

    test('leave every guest screen', () {
      for (final path in AppRoutes.guestOnly) {
        expect(
          redirect(isSignedIn: true, path: path),
          AppRoutes.dashboard,
          reason: path,
        );
      }
    });
  });

  group('phone gate', () {
    test('sends unverified users to verification', () {
      expect(
        redirect(isSignedIn: true, path: AppRoutes.post),
        '/verify-phone?from=%2Fpost',
      );
    });

    test('lets verified users through', () {
      expect(
        redirect(isSignedIn: true, isPhoneVerified: true, path: AppRoutes.post),
        isNull,
      );
    });

    test('continues to the destination once verified', () {
      expect(
        redirect(
          isSignedIn: true,
          isPhoneVerified: true,
          path: AppRoutes.verifyPhone,
          from: AppRoutes.post,
        ),
        AppRoutes.post,
      );
    });

    test('does not loop on the verification screen', () {
      expect(redirect(isSignedIn: true, path: AppRoutes.verifyPhone), isNull);
    });

    test('does not block other seller tabs', () {
      expect(redirect(isSignedIn: true, path: AppRoutes.sales), isNull);
    });
  });

  group('password recovery', () {
    test('forces the new password screen', () {
      expect(
        redirect(
          isSignedIn: true,
          isRecoveringPassword: true,
          path: AppRoutes.dashboard,
        ),
        AppRoutes.resetPassword,
      );
    });

    test('stays on the screen', () {
      expect(
        redirect(
          isSignedIn: true,
          isRecoveringPassword: true,
          path: AppRoutes.resetPassword,
        ),
        isNull,
      );
    });

    test('the screen cannot be opened otherwise', () {
      expect(redirect(path: AppRoutes.resetPassword), AppRoutes.dashboard);
    });
  });

  group('backFallback', () {
    String? back(String location) =>
        AppRoutes.backFallback(Uri.parse(location));

    test('the Dashboard leaves the app', () {
      expect(back('/dashboard'), isNull);
    });

    test('other tabs and top-level screens go to the Dashboard', () {
      for (final path in ['/products', '/sales', '/wishlist', '/my-posts']) {
        expect(back(path), '/dashboard', reason: path);
      }
    });

    test('Post returns to where it was opened from', () {
      expect(back('/post?from=/my-posts'), '/my-posts');
      expect(back('/post'), '/dashboard');
      expect(back('/post?from=//example.com'), '/dashboard');
    });

    test('login never returns to a screen that needs sign-in', () {
      expect(back('/login?from=/post'), '/dashboard');
      expect(back('/verify-phone?from=/checkout'), '/dashboard');
    });
  });
}
