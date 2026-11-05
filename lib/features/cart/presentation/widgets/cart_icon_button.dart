import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/cart_provider.dart';

/// The cart in a top bar, with the number of items. Guests go to sign in first.
class CartIconButton extends StatelessWidget {
  const CartIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.select<CartProvider, int>((cart) => cart.itemCount);
    return IconButton(
      tooltip: switch (count) {
        0 => 'Cart',
        1 => 'Cart, 1 item',
        _ => 'Cart, $count items',
      },
      icon: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: const Icon(Icons.shopping_cart_outlined),
      ),
      onPressed: () {
        if (context.read<AuthProvider>().isSignedIn) {
          context.push(AppRoutes.cart);
        } else {
          context.go(AppRoutes.withFrom(AppRoutes.login, AppRoutes.cart));
        }
      },
    );
  }
}
