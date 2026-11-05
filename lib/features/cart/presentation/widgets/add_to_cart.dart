import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/buying_errors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/cart_provider.dart';

/// Sends a guest to sign in, and back here afterwards. Returns true if it did.
bool sendGuestToSignIn(BuildContext context) {
  if (context.read<AuthProvider>().isSignedIn) return false;
  final here = GoRouterState.of(context).uri.toString();
  context.go(AppRoutes.withFrom(AppRoutes.login, here));
  return true;
}

/// Tells the buyer how adding to the cart went.
void showCartResult(BuildContext context, AppFailure? failure) {
  final router = GoRouter.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      failure == null
          ? SnackBar(
              content: const Text('Added to cart'),
              // A bar with an action otherwise stays until it is dismissed,
              // and this one would sit on top of the product cards.
              persist: false,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'View cart',
                onPressed: () => router.push(AppRoutes.cart),
              ),
            )
          : SnackBar(content: Text(buyingFailureMessage(failure))),
    );
}

/// The cart button on product cards. A product with choices opens its page,
/// because the buyer has to pick one there.
class CardCartButton extends StatelessWidget {
  const CardCartButton({required this.productId, super.key});

  final String productId;

  Future<void> _onPressed(BuildContext context) async {
    if (sendGuestToSignIn(context)) return;
    final failure = await context.read<CartProvider>().addProduct(productId);
    if (!context.mounted) return;
    if (failure is ServerFailure && failure.code == 'VARIANT_REQUIRED') {
      await context.push(AppRoutes.product(productId));
      return;
    }
    showCartResult(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Add to cart',
      icon: const Icon(
        Icons.add_shopping_cart_rounded,
        color: AppColors.primary,
      ),
      onPressed: () => _onPressed(context),
    );
  }
}
