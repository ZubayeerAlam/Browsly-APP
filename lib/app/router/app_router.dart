import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/providers/auth_form_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/phone_auth_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/catalog/presentation/screens/products_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/listings/presentation/screens/post_screen.dart';
import '../../features/profile/domain/entities/address.dart';
import '../../features/profile/domain/repositories/address_repository.dart';
import '../../features/profile/presentation/providers/address_form_provider.dart';
import '../../features/profile/presentation/providers/addresses_provider.dart';
import '../../features/profile/presentation/screens/account_security_screen.dart';
import '../../features/profile/presentation/screens/address_form_screen.dart';
import '../../features/profile/presentation/screens/addresses_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/sales/presentation/screens/sales_screen.dart';
import '../../features/statistics/presentation/screens/statistics_screen.dart';
import '../shell/main_shell.dart';
import 'app_routes.dart';

/// Screens open with `go` and nested routes rather than `push`, because
/// GoRouter does not re-check redirects for pushed screens. That re-check is
/// what moves users on after signing in, signing out or verifying a phone.
GoRouter createAppRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: auth,
    redirect: (context, state) => resolveRedirect(
      isSignedIn: auth.isSignedIn,
      isPhoneVerified: auth.isPhoneVerified,
      isRecoveringPassword: auth.isRecoveringPassword,
      path: state.matchedLocation,
      from: state.uri.queryParameters['from'],
    ),
    // Sign-in links are handled by Supabase, so an unknown path just goes home.
    onException: (context, state, router) => router.go(AppRoutes.dashboard),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          _tab(AppRoutes.dashboard, const DashboardScreen()),
          _tab(AppRoutes.products, const ProductsScreen()),
          _tab(AppRoutes.sales, const SalesScreen()),
          _tab(AppRoutes.statistics, const StatisticsScreen()),
        ],
      ),
      GoRoute(
        path: AppRoutes.post,
        builder: (context, state) =>
            PostScreen(backTo: _safeFrom(state.uri.queryParameters['from'])),
      ),
      _authRoute(
        AppRoutes.login,
        (state) => LoginScreen(from: state.uri.queryParameters['from']),
        routes: [
          _authRoute('sign-up', (state) => const SignUpScreen()),
          _authRoute(
            'forgot-password',
            (state) => const ForgotPasswordScreen(),
          ),
          _authRoute(
            'phone',
            (state) => const PhoneAuthScreen(linkToAccount: false),
          ),
        ],
      ),
      _authRoute(
        AppRoutes.resetPassword,
        (state) => const ResetPasswordScreen(),
      ),
      _authRoute(
        AppRoutes.verifyPhone,
        (state) => PhoneAuthScreen(
          linkToAccount: true,
          backTo: _safeFrom(state.uri.queryParameters['from']),
        ),
      ),
      _authRoute(
        AppRoutes.settings,
        (state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => const EditProfileScreen(),
          ),
          _authRoute('security', (state) => const AccountSecurityScreen()),
          GoRoute(
            path: 'addresses',
            builder: (context, state) => ChangeNotifierProvider(
              create: (context) =>
                  AddressesProvider(context.read<AddressRepository>())..load(),
              child: const AddressesScreen(),
            ),
            routes: [
              GoRoute(
                path: 'form',
                builder: (context, state) {
                  final existing = state.extra as Address?;
                  return ChangeNotifierProvider(
                    create: (context) => AddressFormProvider(
                      context.read<AddressRepository>(),
                      existing: existing,
                    )..loadRegions(),
                    child: AddressFormScreen(existing: existing),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

StatefulShellBranch _tab(String path, Widget screen) {
  return StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => screen)],
  );
}

String? _safeFrom(String? from) => _isInternalPath(from) ? from : null;

/// A screen with its own busy and error state for sign-in actions.
GoRoute _authRoute(
  String path,
  Widget Function(GoRouterState) screen, {
  List<RouteBase> routes = const [],
}) {
  return GoRoute(
    path: path,
    routes: routes,
    builder: (context, state) => ChangeNotifierProvider(
      create: (context) => AuthFormProvider(context.read<AuthRepository>()),
      child: screen(state),
    ),
  );
}

/// Decides where a user may go. Page protection here is only for user
/// experience; RLS and server functions are the real security.
@visibleForTesting
String? resolveRedirect({
  required bool isSignedIn,
  required bool isPhoneVerified,
  required bool isRecoveringPassword,
  required String path,
  String? from,
}) {
  if (isRecoveringPassword) {
    return path == AppRoutes.resetPassword ? null : AppRoutes.resetPassword;
  }
  if (path == AppRoutes.resetPassword) return AppRoutes.dashboard;

  if (!isSignedIn) {
    return AppRoutes.requiresSignIn(path)
        ? AppRoutes.withFrom(AppRoutes.login, path)
        : null;
  }

  if (AppRoutes.guestOnly.contains(path)) {
    return _isInternalPath(from) ? from : AppRoutes.dashboard;
  }
  if (path == AppRoutes.verifyPhone && isPhoneVerified) {
    return _isInternalPath(from) ? from : AppRoutes.dashboard;
  }
  if (AppRoutes.phoneVerifiedOnly.contains(path) && !isPhoneVerified) {
    return AppRoutes.withFrom(AppRoutes.verifyPhone, path);
  }
  return null;
}

/// Rejects addresses such as `//example.com` that could leave the app.
bool _isInternalPath(String? path) {
  return path != null && path.startsWith('/') && !path.startsWith('//');
}
