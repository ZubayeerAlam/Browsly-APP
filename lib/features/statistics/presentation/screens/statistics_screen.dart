import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/pill_chip.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/seller_stats.dart';
import '../providers/statistics_provider.dart';
import '../widgets/daily_bar_chart.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StatisticsProvider>();
    final state = provider.state;
    final stats = state.data;
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: switch (state.status) {
        ViewStatus.empty => EmptyView(
          icon: Icons.pie_chart_outline_rounded,
          title: 'No statistics yet',
          message: 'Open a shop and post a listing to see how it does.',
          action: FilledButton(
            onPressed: () => context.go(
              AppRoutes.withFrom(AppRoutes.post, AppRoutes.statistics),
            ),
            child: const Text('Start posting'),
          ),
        ),
        ViewStatus.error when stats == null => ErrorView(
          message: state.failure!.message,
          onRetry: provider.load,
        ),
        _ when stats == null => const LoadingView(),
        _ => RefreshIndicator(
          onRefresh: provider.load,
          child: _StatsBody(stats: stats),
        ),
      },
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});

  final SellerStats stats;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<StatisticsProvider>();
    final days = context.select<StatisticsProvider, int>((p) => p.days);
    final measure = context.select<StatisticsProvider, StatsMeasure>(
      (p) => p.measure,
    );
    final theme = Theme.of(context);
    final sectionStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final orderRate = stats.orderRate;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final option in const [7, 30])
              PillChip(
                label: 'Last $option days',
                selected: days == option,
                onSelected: () => provider.setDays(option),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Views',
                value: formatCompactCount(stats.views),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Clicks',
                value: formatCompactCount(stats.clicks),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Orders',
                value: formatCompactCount(stats.orders),
                note: orderRate == null
                    ? null
                    : '${orderRate.toStringAsFixed(1)} per 100 views',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Sales',
                value: formatTaka(stats.sales),
                note: 'Without delivery',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Trend', style: sectionStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final option in StatsMeasure.values)
              PillChip(
                label: option.label,
                selected: measure == option,
                onSelected: () => provider.setMeasure(option),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DailyBarChart(
          label: measure.label,
          points: [
            for (final day in stats.daily)
              ChartPoint(day: day.day, value: _valueOf(day, measure)),
          ],
          formatValue: measure == StatsMeasure.sales
              ? formatTaka
              : (value) => value.toStringAsFixed(0),
        ),
        const SizedBox(height: 20),
        Text('Top products', style: sectionStyle),
        const SizedBox(height: 8),
        if (stats.topProducts.isEmpty)
          const Text('No activity in this period yet.')
        else
          for (final product in stats.topProducts)
            _TopProductRow(product: product),
      ],
    );
  }

  double _valueOf(DayStats day, StatsMeasure measure) {
    return switch (measure) {
      StatsMeasure.views => day.views.toDouble(),
      StatsMeasure.clicks => day.clicks.toDouble(),
      StatsMeasure.orders => day.orders.toDouble(),
      StatsMeasure.sales => day.sales,
    };
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = this.note;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (note != null)
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({required this.product});

  final TopProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push(AppRoutes.product(product.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.square(
                dimension: 48,
                child: AppNetworkImage(url: product.imageUrl, displayWidth: 48),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${product.views} views · ${product.units} sold',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatTaka(product.sales),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
