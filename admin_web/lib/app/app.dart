import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/admin_auth.dart';
import '../features/banners/banners_data.dart';
import '../features/categories/categories_data.dart';
import '../features/orders/orders_data.dart';
import '../features/overview/overview_data.dart';
import '../features/products/products_data.dart';
import '../features/reports/reports_data.dart';
import '../features/review/review_data.dart';
import '../features/settings/settings_data.dart';
import '../features/settlements/settlements_data.dart';
import '../features/users/users_data.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Everything the panel talks to, so tests can supply fakes.
class AdminRepositories {
  const AdminRepositories({
    required this.auth,
    required this.overview,
    required this.review,
    required this.users,
    required this.products,
    required this.orders,
    required this.categories,
    required this.settings,
    required this.banners,
    required this.reports,
    required this.settlements,
  });

  final AdminAuthRepository auth;
  final OverviewRepository overview;
  final ReviewRepository review;
  final UsersRepository users;
  final ProductsRepository products;
  final OrdersRepository orders;
  final CategoriesRepository categories;
  final SettingsRepository settings;
  final BannersRepository banners;
  final ReportsRepository reports;
  final SettlementsRepository settlements;
}

class AdminApp extends StatefulWidget {
  const AdminApp({required this.repositories, this.theme, super.key});

  final AdminRepositories repositories;

  /// Lets tests supply a theme that doesn't download a font.
  final ThemeData? theme;

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final AdminAuthProvider _auth;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _auth = AdminAuthProvider(widget.repositories.auth);
    _router = createAdminRouter(_auth);
  }

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repositories = widget.repositories;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        Provider.value(value: repositories.overview),
        Provider.value(value: repositories.review),
        Provider.value(value: repositories.users),
        Provider.value(value: repositories.products),
        Provider.value(value: repositories.orders),
        Provider.value(value: repositories.categories),
        Provider.value(value: repositories.settings),
        Provider.value(value: repositories.banners),
        Provider.value(value: repositories.reports),
        Provider.value(value: repositories.settlements),
      ],
      child: MaterialApp.router(
        title: 'Browsly Admin',
        debugShowCheckedModeBanner: false,
        theme: widget.theme ?? AppTheme.light(),
        routerConfig: _router,
      ),
    );
  }
}
