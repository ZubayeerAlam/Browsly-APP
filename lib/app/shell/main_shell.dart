import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';
import '../theme/app_colors.dart';

/// The bottom navigation bar. The first four items are tabs. Post opens as a
/// full-screen flow on top of them.
class MainShell extends StatelessWidget {
  const MainShell({required this.shell, super.key});

  static const _postIndex = 4;
  static const _tabPaths = [
    AppRoutes.dashboard,
    AppRoutes.products,
    AppRoutes.sales,
    AppRoutes.statistics,
  ];

  final StatefulNavigationShell shell;

  void _onSelected(BuildContext context, int index) {
    if (index == _postIndex) {
      // Back returns to whichever tab the user came from.
      context.go(
        AppRoutes.withFrom(AppRoutes.post, _tabPaths[shell.currentIndex]),
      );
      return;
    }
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (index) => _onSelected(context, index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Products',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Sales',
            ),
            NavigationDestination(
              icon: Icon(Icons.pie_chart_outline_rounded),
              selectedIcon: Icon(Icons.pie_chart_rounded),
              label: 'Statistics',
            ),
            NavigationDestination(icon: Icon(Icons.edit_square), label: 'Post'),
          ],
        ),
      ),
    );
  }
}
