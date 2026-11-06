import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/admin_auth.dart';
import 'router.dart';
import 'theme/app_colors.dart';

/// The side menu around every page.
class AdminShell extends StatelessWidget {
  const AdminShell({required this.location, required this.child, super.key});

  static const _items = [
    (AdminRoutes.overview, Icons.dashboard_outlined, 'Overview'),
    (AdminRoutes.review, Icons.fact_check_outlined, 'Product Review'),
    (AdminRoutes.users, Icons.people_outline_rounded, 'Users'),
    (AdminRoutes.products, Icons.inventory_2_outlined, 'Products'),
    (AdminRoutes.categories, Icons.category_outlined, 'Categories'),
    (AdminRoutes.orders, Icons.receipt_long_outlined, 'Orders'),
    (AdminRoutes.reports, Icons.flag_outlined, 'Reports'),
    (
      AdminRoutes.settlements,
      Icons.account_balance_wallet_outlined,
      'Settlements',
    ),
    (AdminRoutes.banners, Icons.view_carousel_outlined, 'Banners'),
    (AdminRoutes.settings, Icons.settings_outlined, 'Settings'),
  ];

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selected = _items.indexWhere((item) => location.startsWith(item.$1));
    final isWide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      body: Row(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: NavigationRail(
              extended: isWide,
              minExtendedWidth: 220,
              backgroundColor: AppColors.surface,
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: (index) => context.go(_items[index].$1),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shopping_bag_rounded,
                      color: AppColors.primary,
                    ),
                    if (isWide) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Browsly Admin',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: isWide
                        ? TextButton.icon(
                            onPressed: () =>
                                context.read<AdminAuthProvider>().signOut(),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Log out'),
                          )
                        : IconButton(
                            tooltip: 'Log out',
                            onPressed: () =>
                                context.read<AdminAuthProvider>().signOut(),
                            icon: const Icon(Icons.logout_rounded),
                          ),
                  ),
                ),
              ),
              destinations: [
                for (final item in _items)
                  NavigationRailDestination(
                    icon: Icon(item.$2),
                    label: Text(item.$3),
                  ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
