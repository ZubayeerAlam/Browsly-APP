import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../orders/presentation/widgets/order_status_chip.dart';
import '../../domain/entities/sale.dart';
import '../providers/sales_provider.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SalesProvider>();
    return DefaultTabController(
      length: SaleTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sales'),
          actions: [
            TextButton.icon(
              onPressed: () => context.push(AppRoutes.commission),
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Commission'),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (index) => provider.setTab(SaleTab.values[index]),
            tabs: [for (final tab in SaleTab.values) Tab(text: tab.label)],
          ),
        ),
        body: const _SalesList(),
      ),
    );
  }
}

class _SalesList extends StatelessWidget {
  const _SalesList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesProvider>();
    final state = provider.state;
    final sales = state.data;
    return switch (state.status) {
      ViewStatus.error when sales == null => ErrorView(
        message: state.failure!.message,
        onRetry: provider.load,
      ),
      ViewStatus.empty => RefreshIndicator(
        onRefresh: () => provider.load(),
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: const EmptyView(
                  icon: Icons.bar_chart_rounded,
                  title: 'No sales yet',
                  message: 'Orders from your shop will appear here.',
                ),
              ),
            ],
          ),
        ),
      ),
      _ when sales == null => const LoadingView(),
      _ => RefreshIndicator(
        onRefresh: () => provider.load(keepList: true),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sales.length + (provider.isLoadingMore ? 1 : 0),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index >= sales.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LoadingView(),
              );
            }
            if (index == sales.length - 1) provider.loadMore();
            return _SaleCard(sale: sales[index]);
          },
        ),
      ),
    };
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale});

  final SaleSummary sale;

  Future<void> _open(BuildContext context) async {
    final provider = context.read<SalesProvider>();
    await context.push(AppRoutes.sale(sale.id));
    // It may have moved to another tab while open.
    await provider.load(keepList: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extra = sale.itemCount - 1;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 64,
                  child: AppNetworkImage(
                    url: sale.firstImageUrl,
                    displayWidth: 64,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sale.orderNumber,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        OrderStatusChip(status: sale.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      extra > 0
                          ? '${sale.firstTitle} and $extra more'
                          : sale.firstTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${sale.recipientName} · ${formatDate(sale.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatTaka(sale.amountToCollect),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
