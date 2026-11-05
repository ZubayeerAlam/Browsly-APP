import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/busy_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../cart/presentation/widgets/order_totals.dart';
import '../../../chat/presentation/widgets/open_chat.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/widgets/order_status_chip.dart';
import '../../../orders/presentation/widgets/order_timeline.dart';
import '../../domain/entities/sale.dart';
import '../providers/sale_detail_provider.dart';

class SaleDetailScreen extends StatelessWidget {
  const SaleDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SaleDetailProvider>();
    final state = provider.state;
    final sale = state.data;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: AppRoutes.sales),
        title: const Text('Order details'),
      ),
      body: switch (state.status) {
        ViewStatus.empty => const EmptyView(
          icon: Icons.receipt_long_outlined,
          title: 'We could not find this order',
        ),
        ViewStatus.error when sale == null => ErrorView(
          message: state.failure!.message,
          onRetry: provider.load,
        ),
        _ when sale == null => const LoadingView(),
        _ => RefreshIndicator(
          onRefresh: provider.load,
          child: _SaleBody(sale: sale),
        ),
      },
      bottomNavigationBar: sale == null || !_hasActions(sale.status)
          ? null
          : _ActionBar(sale: sale),
    );
  }
}

bool _hasActions(OrderStatus status) {
  return status == OrderStatus.pending ||
      status == OrderStatus.packaging ||
      status == OrderStatus.outForDelivery;
}

class _SaleBody extends StatelessWidget {
  const _SaleBody({required this.sale});

  final SaleDetail sale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionFailure = context.select<SaleDetailProvider, String?>(
      (provider) => provider.actionFailure,
    );
    final sectionStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(sale.orderNumber, style: theme.textTheme.titleLarge),
            ),
            OrderStatusChip(status: sale.status),
          ],
        ),
        Text(
          'Placed on ${formatDate(sale.createdAt)}',
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
        Text('Buyer', style: sectionStyle),
        const SizedBox(height: 8),
        _BuyerCard(buyer: sale.buyer),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () =>
              openChat(context, (chats) => chats.startForOrder(sale.id)),
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: const Text('Chat with buyer'),
        ),
        const SizedBox(height: 16),
        Text('Items', style: sectionStyle),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [for (final item in sale.items) _ItemRow(item: item)],
          ),
        ),
        const SizedBox(height: 16),
        Text('Status', style: sectionStyle),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OrderTimeline(status: sale.status, history: sale.history),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OrderTotals(
          subtotal: sale.subtotal,
          delivery: sale.deliveryFee,
          total: sale.amountToCollect,
          totalLabel: 'Cash to collect',
        ),
        const SizedBox(height: 8),
        Text(
          _commissionText(sale),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _commissionText(SaleDetail sale) {
    final amount = formatTaka(sale.commissionTotal);
    return switch (sale.status) {
      OrderStatus.completed => 'Commission charged: $amount',
      OrderStatus.cancelled ||
      OrderStatus.deliveryFailed => 'No commission on this order',
      _ => 'Commission when complete: $amount, not counting delivery',
    };
  }
}

class _BuyerCard extends StatelessWidget {
  const _BuyerCard({required this.buyer});

  final ShippingAddress buyer;

  Future<void> _call(BuildContext context, String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    } on Exception {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open the phone app. Call $phone.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = buyer.phone;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text(buyer.recipientName),
        subtitle: SelectableText([?phone, buyer.fullAddress].join('\n')),
        trailing: phone == null
            ? null
            : IconButton(
                tooltip: 'Call buyer',
                icon: const Icon(Icons.call_rounded, color: AppColors.primary),
                onPressed: () => _call(context, phone),
              ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(formatTaka(item.lineTotal)),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.sale});

  final SaleDetail sale;

  Future<void> _confirmDelivered(BuildContext context) async {
    final provider = context.read<SaleDetailProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark as delivered?'),
        content: Text(
          'Confirm that you collected ${formatTaka(sale.amountToCollect)} in '
          'cash. ${formatTaka(sale.commissionTotal)} commission will be added '
          'to what you owe. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm delivered'),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.setStatus(OrderStatus.completed);
  }

  Future<void> _closeOrder(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function(String? reason) onConfirmed,
  }) async {
    final result = await showDialog<_ReasonResult>(
      context: context,
      builder: (dialogContext) => _ReasonDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
      ),
    );
    if (result != null) await onConfirmed(result.reason);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SaleDetailProvider>();
    final isUpdating = context.select<SaleDetailProvider, bool>(
      (provider) => provider.isUpdating,
    );
    final status = sale.status;
    final dangerStyle = OutlinedButton.styleFrom(
      foregroundColor: AppColors.danger,
      side: const BorderSide(color: AppColors.danger),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BusyButton(
                label: switch (status) {
                  OrderStatus.pending => 'Start packaging',
                  OrderStatus.packaging => 'Mark out for delivery',
                  _ => 'Delivered, cash collected',
                },
                isBusy: isUpdating,
                onPressed: () => switch (status) {
                  OrderStatus.pending => provider.setStatus(
                    OrderStatus.packaging,
                  ),
                  OrderStatus.packaging => provider.setStatus(
                    OrderStatus.outForDelivery,
                  ),
                  _ => _confirmDelivered(context),
                },
              ),
              const SizedBox(height: 8),
              if (status == OrderStatus.outForDelivery)
                OutlinedButton(
                  style: dangerStyle,
                  onPressed: isUpdating
                      ? null
                      : () => _closeOrder(
                          context,
                          title: 'Delivery failed?',
                          message:
                              'The items go back on sale, and no commission is '
                              'charged. The buyer will see your reason.',
                          confirmLabel: 'Delivery failed',
                          onConfirmed: (reason) => provider.setStatus(
                            OrderStatus.deliveryFailed,
                            note: reason,
                          ),
                        ),
                  child: const Text('Delivery failed'),
                )
              else
                OutlinedButton(
                  style: dangerStyle,
                  onPressed: isUpdating
                      ? null
                      : () => _closeOrder(
                          context,
                          title: 'Cancel this order?',
                          message:
                              'The items go back on sale, and no commission is '
                              'charged. The buyer will see your reason.',
                          confirmLabel: 'Cancel order',
                          onConfirmed: (reason) =>
                              provider.cancel(reason: reason),
                        ),
                  child: const Text('Cancel order'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the dialog returns when confirmed. Null means the seller backed out.
class _ReasonResult {
  const _ReasonResult(this.reason);

  final String? reason;
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.message),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLength: 300,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Keep order'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () {
            final reason = _reason.text.trim();
            Navigator.of(context)
                .pop(_ReasonResult(reason.isEmpty ? null : reason));
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
