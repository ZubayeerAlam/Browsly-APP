import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../catalog/presentation/widgets/paged_products_view.dart';
import '../providers/saved_products_provider.dart';
import '../providers/wishlist_provider.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavedProductsProvider>();
    // A heart turned off here removes the card straight away.
    final wishlist = context.watch<WishlistProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: AppRoutes.dashboard),
        title: const Text('Wishlist'),
      ),
      body: PagedProductsView(
        provider: provider,
        onRefresh: () => provider.reload(keepList: true),
        visibleWhen: (product) => wishlist.isSaved(product.id),
        emptyView: EmptyView(
          icon: Icons.favorite_border_rounded,
          title: 'Nothing saved yet',
          message: 'Tap the heart on a product to find it here later.',
          action: FilledButton(
            onPressed: () => context.go(AppRoutes.products),
            child: const Text('Browse products'),
          ),
        ),
      ),
    );
  }
}
