import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../cart/presentation/widgets/order_totals.dart';
import '../../../chat/presentation/widgets/open_chat.dart';
import '../../../reviews/presentation/widgets/review_tile.dart';
import '../../../reviews/presentation/widgets/write_review_sheet.dart';
import '../../domain/entities/order.dart';
import '../providers/order_detail_provider.dart';
import '../widgets/order_status_chip.dart';
import '../widgets/order_timeline.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({this.justPlaced = false, super.key});

  /// Shows the success message after checkout.
  final bool justPlaced;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderDetailProvider>();
    final state = provider.state;
    final order = state.data;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: AppRoutes.orders),
        title: const Text('Order details'),
      ),
      body: switch (state.status) {
        ViewStatus.empty => const EmptyView(
          icon: Icons.receipt_long_outlined,
          title: 'We could not find this order',
        ),
        ViewStatus.error when order == null => ErrorView(
          message: state.failure!.message,
          onRetry: provider.load,
        ),
        _ when order == null => const LoadingView(),
        _ => RefreshIndicator(
          onRefresh: provider.load,
          child: _OrderBody(order: order, justPlaced: justPlaced),
        ),
      },
    );
  }
}

class _OrderBody extends StatelessWidget {
  const _OrderBody({required this.order, required this.justPlaced});

  final OrderDetail order;
  final bool justPlaced;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionFailure = context.select<OrderDetailProvider, String?>(
      (provider) => provider.actionFailure,
    );
    final address = order.shippingAddress;
    final sectionStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (justPlaced) const _PlacedBanner(),
        Text(order.orderNumber, style: theme.textTheme.titleLarge),
        Text(
          'Placed on ${formatDate(order.createdAt)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (actionFailure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              actionFailure,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        for (final group in order.groups) ...[
          _GroupCard(group: group),
          const SizedBox(height: 12),
        ],
        if (address != null) ...[
          Text('Deliver to', style: sectionStyle),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(address.recipientName),
              subtitle: Text([?address.phone, address.fullAddress].join('\n')),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text('Payment', style: sectionStyle),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading: Icon(Icons.payments_outlined),
            title: Text('Cash on Delivery'),
            subtitle: Text('Pay each seller when your items arrive.'),
          ),
        ),
        const SizedBox(height: 16),
        OrderTotals(
          subtotal: order.subtotal,
          delivery: order.deliveryTotal,
          total: order.grandTotal,
        ),
        if (order.hasClosedParts)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('To pay after cancellations', style: sectionStyle),
                Text(formatTaka(order.amountToPay), style: sectionStyle),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlacedBanner extends StatelessWidget {
  const _PlacedBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your order is placed',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Sellers will start preparing your items.'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.products),
            child: const Text('Continue shopping'),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final OrderGroup group;

  Future<void> _confirmCancel(BuildContext context) async {
    final provider = context.read<OrderDetailProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancel your order from ${group.shopName}?'),
        content: const Text('Other sellers in this order are not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep order'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.cancel(group);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCancelling = context.select<OrderDetailProvider, bool>(
      (provider) => provider.cancellingGroupId == group.id,
    );
    final shopId = group.shopId;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.storefront_rounded),
            title: Text(
              group.shopName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: OrderStatusChip(status: group.status),
            onTap: shopId == null
                ? null
                : () => context.push(AppRoutes.shop(shopId)),
          ),
          const Divider(height: 1),
          for (final item in group.items)
            _ItemRow(
              item: item,
              canReview: group.status == OrderStatus.completed,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              'Delivery ${formatTaka(group.deliveryFee)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: OrderTimeline(status: group.status, history: group.history),
          ),
          if (shopId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: OutlinedButton.icon(
                onPressed: () =>
                    openChat(context, (chats) => chats.startForOrder(group.id)),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Chat with seller'),
              ),
            ),
          if (group.status.canCancel)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                onPressed: isCancelling ? null : () => _confirmCancel(context),
                child: Text(isCancelling ? 'Cancelling...' : 'Cancel order'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.canReview});

  final OrderItem item;

  /// Whether the order is complete. It also needs to be still reviewable.
  final bool canReview;

  Future<void> _review(BuildContext context) async {
    final provider = context.read<OrderDetailProvider>();
    final saved = await showWriteReviewSheet(
      context,
      orderItemId: item.id,
      productTitle: item.title,
    );
    if (saved) await provider.load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productId = item.productId;
    return InkWell(
      onTap: productId == null
          ? null
          : () => context.push(AppRoutes.product(productId)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.square(
                dimension: 56,
                child: AppNetworkImage(url: item.imageUrl, displayWidth: 56),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    [
                      ?item.variantLabel,
                      '${item.quantity} × ${formatTaka(item.unitPrice)}',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (item.myRating != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: StarRow(rating: item.myRating!),
                    )
                  else if (canReview && productId != null)
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => _review(context),
                      child: const Text('Write a review'),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(formatTaka(item.lineTotal)),
          ],
        ),
      ),
    );
  }
}
