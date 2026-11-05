import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/order.dart';
import '../providers/my_orders_provider.dart';
import '../widgets/order_status_chip.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MyOrdersProvider>();
    final state = provider.state;
    final orders = state.data;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: AppRoutes.dashboard),
        title: const Text('My Orders'),
      ),
      body: switch (state.status) {
        ViewStatus.empty => EmptyView(
          icon: Icons.receipt_long_outlined,
          title: 'No orders yet',
          message: 'Orders you place will appear here.',
          action: FilledButton(
            onPressed: () => context.go(AppRoutes.products),
            child: const Text('Browse products'),
          ),
        ),
        ViewStatus.error when orders == null => ErrorView(
          message: state.failure!.message,
          onRetry: provider.load,
        ),
        _ when orders == null => const LoadingView(),
        _ => RefreshIndicator(
          onRefresh: provider.load,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length + (provider.isLoadingMore ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index >= orders.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: LoadingView(),
                );
              }
              if (index == orders.length - 1) provider.loadMore();
              return _OrderCard(order: orders[index]);
            },
          ),
        ),
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderSummary order;

  Future<void> _open(BuildContext context) async {
    final provider = context.read<MyOrdersProvider>();
    await context.push(AppRoutes.order(order.id));
    // A part of the order may have been cancelled there.
    await provider.load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    formatTaka(order.grandTotal),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                formatDate(order.createdAt),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final group in order.groups)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _GroupRow(group: group),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group});

  final OrderGroupSummary group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extra = group.itemCount - 1;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(
            dimension: 48,
            child: AppNetworkImage(url: group.firstImageUrl, displayWidth: 48),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                extra > 0
                    ? '${group.firstTitle} and $extra more'
                    : group.firstTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(group.shopName, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OrderStatusChip(status: group.status),
      ],
    );
  }
}
