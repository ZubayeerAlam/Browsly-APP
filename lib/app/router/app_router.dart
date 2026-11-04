import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/catalog/presentation/screens/products_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/listings/presentation/screens/post_screen.dart';
import '../../features/sales/presentation/screens/sales_screen.dart';
import '../../features/statistics/presentation/screens/statistics_screen.dart';
import '../shell/main_shell.dart';
import 'app_routes.dart';

GoRouter createAppRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: auth,
    redirect: (context, state) => resolveRedirect(
      isSignedIn: auth.isSignedIn,
      path: state.matchedLocation,
      from: state.uri.queryParameters['from'],
    ),
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
        builder: (context, state) => const PostScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );
}

StatefulShellBranch _tab(String path, Widget screen) {
  return StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => screen)],
  );
}

/// Sends guests to login, and signed-in users back to where they were going.
/// Page protection here is only for user experience; RLS is the real security.
@visibleForTesting
String? resolveRedirect({
  required bool isSignedIn,
  required String path,
  String? from,
}) {
  if (!isSignedIn && AppRoutes.signedInOnly.contains(path)) {
    return Uri(
      path: AppRoutes.login,
      queryParameters: {'from': path},
    ).toString();
  }
  if (isSignedIn && path == AppRoutes.login) {
    return _isInternalPath(from) ? from : AppRoutes.dashboard;
  }
  return null;
}

/// Rejects addresses such as `//example.com` that could leave the app.
bool _isInternalPath(String? path) {
  return path != null && path.startsWith('/') && !path.startsWith('//');
}
