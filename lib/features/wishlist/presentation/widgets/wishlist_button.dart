import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/wishlist_provider.dart';

/// The heart on products. Guests go to sign in, and then come back here.
class WishlistButton extends StatelessWidget {
  const WishlistButton({
    required this.productId,
    this.filled = false,
    super.key,
  });

  final String productId;

  /// Adds a white circle, so it stays visible on top of a photo.
  final bool filled;

  Future<void> _onPressed(BuildContext context) async {
    if (!context.read<AuthProvider>().isSignedIn) {
      final here = GoRouterState.of(context).uri.toString();
      context.go(AppRoutes.withFrom(AppRoutes.login, here));
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final succeeded = await context.read<WishlistProvider>().toggle(productId);
    if (!succeeded) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('We could not update your wishlist. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = context.select<WishlistProvider, bool>(
      (wishlist) => wishlist.isSaved(productId),
    );
    return IconButton(
      tooltip: isSaved ? 'Remove from wishlist' : 'Save to wishlist',
      style: filled
          ? IconButton.styleFrom(backgroundColor: Colors.white)
          : null,
      onPressed: () => _onPressed(context),
      icon: Icon(
        isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isSaved ? AppColors.danger : AppColors.textSecondary,
      ),
    );
  }
}
