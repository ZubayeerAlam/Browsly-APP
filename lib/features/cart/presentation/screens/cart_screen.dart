import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/buying_errors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/cart.dart';
import '../providers/cart_provider.dart';
import '../widgets/order_totals.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // Prices and stock may have changed since the cart was last read.
    context.read<CartProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CartProvider>();
    final cart = provider.cart;
    final failure = provider.loadFailure;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: AppRoutes.dashboard),
        title: const Text('Cart'),
      ),
      body: switch (cart) {
        null when failure != null => ErrorView(
          message: failure.message,
          onRetry: provider.load,
        ),
        null => const LoadingView(),
        Cart(isEmpty: true) => EmptyView(
          icon: Icons.shopping_cart_outlined,
          title: 'Your cart is empty',
          message: 'Products you add will appear here.',
          action: FilledButton(
            onPressed: () => context.go(AppRoutes.products),
            child: const Text('Browse products'),
          ),
        ),
        _ => RefreshIndicator(
          onRefresh: provider.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final shop in cart.shops) ...[
                _ShopCard(shop: shop),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      },
      bottomNavigationBar: cart == null || cart.isEmpty
          ? null
          : _CheckoutBar(cart: cart),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop});

  final CartShop shop;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.storefront_rounded),
            title: Text(
              shop.name,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('Delivery ${formatTaka(shop.deliveryFee)}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.shop(shop.id)),
          ),
          const Divider(height: 1),
          for (final line in shop.lines) _CartLineRow(line: line),
        ],
      ),
    );
  }
}

class _CartLineRow extends StatelessWidget {
  const _CartLineRow({required this.line});

  final CartLine line;

  Future<void> _apply(
    BuildContext context,
    Future<AppFailure?> Function(CartProvider cart) action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failure = await action(context.read<CartProvider>());
    if (failure != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(buyingFailureMessage(failure))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = context.select<CartProvider, bool>(
      (cart) => cart.isBusy(line.variantId),
    );
    final problem = line.problemMessage;
    final canStep = !isBusy && line.problem != CartProblem.unavailable;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push(AppRoutes.product(line.productId)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.square(
                dimension: 72,
                child: AppNetworkImage(url: line.imageUrl, displayWidth: 72),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (line.variantLabel != null)
                  Text(line.variantLabel!, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  formatTaka(line.unitPrice),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (problem != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      problem,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'One less',
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      onPressed: canStep && line.quantity > 1
                          ? () => _apply(
                              context,
                              (cart) =>
                                  cart.setQuantity(line, line.quantity - 1),
                            )
                          : null,
                    ),
                    Text(
                      '${line.quantity}',
                      semanticsLabel: 'Quantity ${line.quantity}',
                      style: theme.textTheme.titleSmall,
                    ),
                    IconButton(
                      tooltip: 'One more',
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      onPressed: canStep && line.canRaiseQuantity
                          ? () => _apply(
                              context,
                              (cart) =>
                                  cart.setQuantity(line, line.quantity + 1),
                            )
                          : null,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Remove from cart',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: isBusy
                          ? null
                          : () => _apply(context, (cart) => cart.remove(line)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
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
              OrderTotals(
                subtotal: cart.subtotal,
                delivery: cart.deliveryTotal,
                total: cart.grandTotal,
              ),
              const SizedBox(height: 12),
              if (!cart.canCheckout)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Please fix or remove the marked items to continue.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              FilledButton(
                onPressed: cart.canCheckout
                    ? () => context.go(AppRoutes.checkout)
                    : null,
                child: const Text('Checkout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
