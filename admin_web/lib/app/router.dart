import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/widgets/state_views.dart';
import '../features/auth/admin_auth.dart';
import '../features/auth/login_screen.dart';
import '../features/banners/banners_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/overview/overview_screen.dart';
import '../features/products/products_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/review/review_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settlements/settlements_screen.dart';
import '../features/users/users_screen.dart';
import 'admin_shell.dart';

abstract final class AdminRoutes {
  static const login = '/login';
  static const overview = '/overview';
  static const review = '/review';
  static const users = '/users';
  static const products = '/products';
  static const categories = '/categories';
  static const orders = '/orders';
  static const reports = '/reports';
  static const settlements = '/settlements';
  static const banners = '/banners';
  static const settings = '/settings';
}

/// The redirect only tidies the experience. Every function checks is_admin() on
/// the server, so reaching a page without being an admin shows nothing.
GoRouter createAdminRouter(AdminAuthProvider auth) {
  return GoRouter(
    initialLocation: AdminRoutes.overview,
    refreshListenable: auth,
    redirect: (context, state) {
      final atLogin = state.matchedLocation == AdminRoutes.login;
      return switch (auth.access) {
        AdminAccess.checking => null,
        AdminAccess.signedOut => atLogin ? null : AdminRoutes.login,
        AdminAccess.granted => atLogin ? AdminRoutes.overview : null,
      };
    },
    onException: (context, state, router) => router.go(AdminRoutes.overview),
    routes: [
      GoRoute(
        path: AdminRoutes.login,
        builder: (context, state) => const _AccessGate(child: LoginScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => _AccessGate(
          child: AdminShell(location: state.matchedLocation, child: child),
        ),
        routes: [
          _page(AdminRoutes.overview, const OverviewScreen()),
          _page(AdminRoutes.review, const ReviewScreen()),
          _page(AdminRoutes.users, const UsersScreen()),
          _page(AdminRoutes.products, const ProductsScreen()),
          _page(AdminRoutes.categories, const CategoriesScreen()),
          _page(AdminRoutes.orders, const OrdersScreen()),
          _page(AdminRoutes.reports, const ReportsScreen()),
          _page(AdminRoutes.settlements, const SettlementsScreen()),
          _page(AdminRoutes.banners, const BannersScreen()),
          _page(AdminRoutes.settings, const SettingsScreen()),
        ],
      ),
    ],
  );
}

/// Shows a spinner until the server has said whether this account is an admin.
class _AccessGate extends StatelessWidget {
  const _AccessGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isChecking = context.select<AdminAuthProvider, bool>(
      (auth) => auth.access == AdminAccess.checking,
    );
    return isChecking ? const Scaffold(body: LoadingView()) : child;
  }
}

GoRoute _page(String path, Widget screen) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => NoTransitionPage(child: screen),
  );
}
