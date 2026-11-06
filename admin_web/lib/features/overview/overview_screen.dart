import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../core/errors/app_failure.dart';
import '../../core/formatters.dart';
import '../../core/widgets/admin_page.dart';
import '../../core/widgets/state_views.dart';
import 'overview_data.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  Overview? _overview;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failure = null);
    try {
      final overview = await context.read<OverviewRepository>().getOverview();
      if (mounted) setState(() => _overview = overview);
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;
    final failure = _failure;
    return AdminPage(
      title: 'Overview',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: failure != null && overview == null
          ? ErrorView(message: failure.message, onRetry: _load)
          : overview == null
          ? const LoadingView()
          : SingleChildScrollView(
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _Tile(
                    label: 'Waiting for review',
                    value: '${overview.reviewQueue}',
                    route: AdminRoutes.review,
                    needsAttention: overview.reviewQueue > 0,
                  ),
                  _Tile(
                    label: 'Open reports',
                    value: '${overview.openReports}',
                    route: AdminRoutes.reports,
                    needsAttention: overview.openReports > 0,
                  ),
                  _Tile(
                    label: 'Commission owed',
                    value: formatTaka(overview.commissionOwed),
                    route: AdminRoutes.settlements,
                  ),
                  _Tile(
                    label: 'Orders today',
                    value: '${overview.ordersToday}',
                    route: AdminRoutes.orders,
                  ),
                  _Tile(
                    label: 'Open orders',
                    value: '${overview.openOrders}',
                    route: AdminRoutes.orders,
                  ),
                  _Tile(
                    label: 'Live products',
                    value: '${overview.liveProducts}',
                    route: AdminRoutes.products,
                  ),
                  _Tile(
                    label: 'Users',
                    value: '${overview.users}',
                    route: AdminRoutes.users,
                  ),
                  _Tile(
                    label: 'Sellers',
                    value: '${overview.sellers}',
                    route: AdminRoutes.users,
                  ),
                ],
              ),
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.route,
    this.needsAttention = false,
  });

  final String label;
  final String value;
  final String route;
  final bool needsAttention;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 240,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(route),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label, style: theme.textTheme.bodySmall),
                    ),
                    if (needsAttention)
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: AppColors.danger,
                        semanticLabel: 'Needs attention',
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
