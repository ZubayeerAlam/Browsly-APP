import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/busy_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../cart/domain/entities/cart.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../cart/presentation/widgets/order_totals.dart';
import '../../../profile/domain/entities/address.dart';
import '../providers/checkout_provider.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  Future<void> _placeOrder(BuildContext context) async {
    final provider = context.read<CheckoutProvider>();
    final cartProvider = context.read<CartProvider>();
    final router = GoRouter.of(context);
    final order = await provider.placeOrder();
    if (order == null) return;
    if (provider.buyNowVariantId == null) await cartProvider.load();
    router.go(AppRoutes.placedOrder(order.id));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CheckoutProvider>();
    final state = provider.state;
    final cart = state.data;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: AppRoutes.cart),
        title: const Text('Checkout'),
      ),
      body: switch (state.status) {
        ViewStatus.empty => EmptyView(
          icon: Icons.shopping_cart_outlined,
          title: 'Nothing to check out',
          message: 'Your cart is empty.',
          action: FilledButton(
            onPressed: () => context.go(AppRoutes.products),
            child: const Text('Browse products'),
          ),
        ),
        ViewStatus.error when cart == null => ErrorView(
          message: state.failure!.message,
          onRetry: provider.load,
        ),
        _ when cart == null => const LoadingView(),
        _ => _CheckoutBody(cart: cart),
      },
      bottomNavigationBar: cart == null
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: BusyButton(
                    label: 'Place order · ${formatTaka(cart.grandTotal)}',
                    isBusy: provider.isPlacing,
                    onPressed: provider.canPlace
                        ? () => _placeOrder(context)
                        : null,
                  ),
                ),
              ),
            ),
    );
  }
}

class _CheckoutBody extends StatelessWidget {
  const _CheckoutBody({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CheckoutProvider>();
    final theme = Theme.of(context);
    final sectionStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final failure = provider.placeFailure ?? provider.state.failure?.message;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (failure != null) _FailureMessage(message: failure),
        Text('Deliver to', style: sectionStyle),
        const SizedBox(height: 8),
        const _AddressCard(),
        const SizedBox(height: 16),
        Text('Your items', style: sectionStyle),
        const SizedBox(height: 8),
        for (final shop in cart.shops) ...[
          _ShopSummary(shop: shop),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
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
          subtotal: cart.subtotal,
          delivery: cart.deliveryTotal,
          total: cart.grandTotal,
        ),
      ],
    );
  }
}

class _FailureMessage extends StatelessWidget {
  const _FailureMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message, style: const TextStyle(color: AppColors.danger)),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard();

  Future<void> _addAddress(BuildContext context) async {
    final provider = context.read<CheckoutProvider>();
    final saved = await context.push<bool>(AppRoutes.checkoutAddressForm);
    if (saved == true) await provider.reloadAddresses();
  }

  Future<void> _chooseAddress(BuildContext context) async {
    final provider = context.read<CheckoutProvider>();
    final choice = await showModalBottomSheet<_AddressChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final address in provider.addresses)
                ListTile(
                  leading: Icon(
                    address.id == provider.selectedAddress?.id
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(address.recipientName),
                  subtitle: Text(address.fullAddress),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_AddressChoice(address)),
                ),
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const Text('Add a new address'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(const _AddressChoice(null)),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final address = choice.address;
    if (address != null) {
      provider.selectAddress(address);
    } else {
      await _addAddress(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = context.select<CheckoutProvider, Address?>(
      (provider) => provider.selectedAddress,
    );
    if (address == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.add_location_alt_outlined),
          title: const Text('Add a delivery address'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _addAddress(context),
        ),
      );
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text(address.recipientName),
        subtitle: Text('${address.phone}\n${address.fullAddress}'),
        isThreeLine: true,
        trailing: TextButton(
          onPressed: () => _chooseAddress(context),
          child: const Text('Change'),
        ),
      ),
    );
  }
}

/// A null address means the buyer wants to add a new one.
class _AddressChoice {
  const _AddressChoice(this.address);

  final Address? address;
}

class _ShopSummary extends StatelessWidget {
  const _ShopSummary({required this.shop});

  final CartShop shop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shop.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final line in shop.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox.square(
                        dimension: 48,
                        child: AppNetworkImage(
                          url: line.imageUrl,
                          displayWidth: 48,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            [
                              ?line.variantLabel,
                              'Qty ${line.quantity}',
                            ].join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                          if (line.problem != null)
                            Text(
                              line.problemMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.danger,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(formatTaka(line.lineTotal)),
                  ],
                ),
              ),
            Text(
              'Delivery ${formatTaka(shop.deliveryFee)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
