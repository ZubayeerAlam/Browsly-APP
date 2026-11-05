import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/sale.dart';
import '../providers/commission_provider.dart';

class CommissionScreen extends StatelessWidget {
  const CommissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommissionProvider>();
    final state = provider.state;
    final data = state.data;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: AppRoutes.sales),
        title: const Text('Commission'),
      ),
      body: switch (state.status) {
        ViewStatus.error when data == null => ErrorView(
          message: state.failure!.message,
          onRetry: provider.load,
        ),
        _ when data == null => const LoadingView(),
        _ => RefreshIndicator(
          onRefresh: provider.load,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.entries.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _Header(data: data);
              if (index == data.entries.length) provider.loadMore();
              return _EntryCard(entry: data.entries[index - 1]);
            },
          ),
        ),
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final CommissionData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = data.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.isBlocked)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'You owe more than ${formatTaka(summary.blockLimit)}, so you '
              "can't post new listings until you pay. Your live listings "
              'stay on sale.',
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You owe',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                Text(
                  formatTaka(summary.balance),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Charged ${formatTaka(summary.totalCharged)} · '
                  'Paid ${formatTaka(summary.totalPaid)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Browsly charges ${_rateText(summary.commissionRate)} of the listing '
          "price on completed orders. Delivery fees aren't included. Pay by "
          'bKash or bank, and Browsly records your payment here.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Text(
          'History',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (data.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Nothing yet. Commission appears here when an order is complete.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }

  String _rateText(double rate) {
    final text = rate == rate.roundToDouble()
        ? rate.toStringAsFixed(0)
        : rate.toString();
    return '$text%';
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final CommissionEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPayment = entry.amount < 0;
    final title = switch (entry.type) {
      CommissionEntryType.charge =>
        'Commission on ${entry.orderNumber ?? 'an order'}',
      CommissionEntryType.settlement =>
        'Payment by ${entry.method ?? 'transfer'}',
      CommissionEntryType.adjustment => 'Adjustment',
    };
    final details = [
      formatDateTime(entry.createdAt),
      ?entry.reference,
      ?entry.note,
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: Icon(
          isPayment ? Icons.south_west_rounded : Icons.north_east_rounded,
          color: isPayment ? AppColors.success : AppColors.textSecondary,
        ),
        title: Text(title),
        subtitle: Text(details),
        trailing: Text(
          '${isPayment ? '−' : '+'}${formatTaka(entry.amount.abs())}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: isPayment ? AppColors.success : null,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
