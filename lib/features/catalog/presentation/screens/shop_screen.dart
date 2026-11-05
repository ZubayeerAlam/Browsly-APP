import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../reports/presentation/widgets/report_sheet.dart';
import '../../domain/entities/shop.dart';
import '../providers/product_list_provider.dart';
import '../providers/shop_provider.dart';
import '../widgets/filter_button.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/paged_products_view.dart';
import '../widgets/rating_label.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();
    final products = context.watch<ProductListProvider>();
    final state = shopProvider.state;
    final shop = state.data;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: AppRoutes.products),
        title: Text(shop?.name ?? 'Shop'),
        actions: [
          if (shop != null)
            Builder(
              builder: (buttonContext) => IconButton(
                tooltip: 'Report this shop',
                icon: const Icon(Icons.flag_outlined),
                onPressed: () => showReportSheet(
                  buttonContext,
                  targetType: ReportTarget.shop,
                  targetId: shop.id,
                  title: 'Report this shop',
                ),
              ),
            ),
          if (shop != null)
            FilterButton(
              count: products.filters.refinementCount,
              onPressed: () async {
                final filters = await showFilterSheet(
                  context,
                  products.filters,
                );
                if (filters != null) await products.applyFilters(filters);
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: switch (state.status) {
        ViewStatus.empty => const EmptyView(
          icon: Icons.storefront_outlined,
          title: 'This shop is not available',
        ),
        ViewStatus.error when shop == null => ErrorView(
          message: state.failure!.message,
          onRetry: shopProvider.load,
        ),
        _ when shop == null => const LoadingView(),
        _ => PagedProductsView(
          provider: products,
          onRefresh: () => Future.wait([
            shopProvider.load(),
            products.reload(keepList: true),
          ]),
          headerSlivers: [SliverToBoxAdapter(child: _ShopHeader(shop: shop))],
          emptyView: const EmptyView(
            icon: Icons.inventory_2_outlined,
            title: 'No matching products',
          ),
        ),
      },
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (shop.bannerUrl != null)
              AspectRatio(
                aspectRatio: 3,
                child: AppNetworkImage(url: shop.bannerUrl),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipOval(
                        child: SizedBox.square(
                          dimension: 56,
                          child: shop.logoUrl == null
                              ? const ColoredBox(
                                  color: AppColors.primarySoft,
                                  child: Icon(
                                    Icons.storefront_rounded,
                                    color: AppColors.primary,
                                  ),
                                )
                              : AppNetworkImage(
                                  url: shop.logoUrl,
                                  displayWidth: 56,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(shop.name, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 2),
                            RatingLabel(
                              average: shop.ratingAvg,
                              count: shop.ratingCount,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (shop.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(shop.description),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      if (shop.regionName != null)
                        _Fact(
                          icon: Icons.location_on_outlined,
                          text: shop.regionName!,
                        ),
                      _Fact(
                        icon: Icons.local_shipping_outlined,
                        text: 'Delivery ${formatTaka(shop.deliveryFee)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
