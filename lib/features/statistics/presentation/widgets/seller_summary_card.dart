import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/seller_dashboard_provider.dart';

/// Today's numbers for someone with a shop. Hidden for everyone else.
class SellerSummaryCard extends StatelessWidget {
  const SellerSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<SellerDashboardProvider>().dashboard;
    if (summary == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final alerts = [
      if (summary.newOrders > 0)
        '${summary.newOrders} new ${summary.newOrders == 1 ? 'order' : 'orders'}',
      if (summary.lowStock > 0) '${summary.lowStock} low on stock',
      if (summary.amountOwed > 0) '${formatTaka(summary.amountOwed)} owed',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your shop today',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Figure(
                    label: 'Clicks',
                    value: formatCompactCount(summary.clicksToday),
                  ),
                  _Figure(
                    label: 'Sales',
                    value: formatTaka(summary.salesToday),
                  ),
                  _Figure(
                    label: 'Views',
                    value: formatCompactCount(summary.viewsToday),
                  ),
                  _Figure(
                    label: 'Rating',
                    value: summary.ratingCount == 0
                        ? '–'
                        : summary.ratingAvg.toStringAsFixed(1),
                  ),
                ],
              ),
              if (alerts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  alerts.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.statistics),
                  child: const Text('View Insights'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
