import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/pill_chip.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../wishlist/presentation/widgets/wishlist_button.dart';
import '../../domain/entities/product.dart';
import '../providers/product_detail_provider.dart';
import '../widgets/rating_label.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductDetailProvider>();
    final state = provider.state;
    final product = state.data;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: AppRoutes.products),
        actions: [
          if (product != null) ...[
            Builder(
              builder: (buttonContext) => IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () => _share(buttonContext, product, provider),
              ),
            ),
            WishlistButton(productId: product.id),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: switch (state.status) {
        ViewStatus.empty => const EmptyView(
          icon: Icons.inventory_2_outlined,
          title: 'This product is not available',
          message: 'The seller may have removed it.',
        ),
        ViewStatus.error when product == null => ErrorView(
          message: state.failure!.message,
          onRetry: provider.load,
        ),
        _ when product == null => const LoadingView(),
        _ => RefreshIndicator(
          onRefresh: provider.load,
          child: _ProductBody(product: product, provider: provider),
        ),
      },
      bottomNavigationBar: product == null
          ? null
          : _BuyBar(isInStock: provider.selected?.isInStock ?? false),
    );
  }

  /// iPads anchor the share popover to the button, and crash without it.
  void _share(
    BuildContext context,
    ProductDetail product,
    ProductDetailProvider provider,
  ) {
    final box = context.findRenderObject() as RenderBox?;
    final price = provider.selected?.price;
    SharePlus.instance.share(
      ShareParams(
        text: price == null
            ? '${product.title} on Browsly'
            : '${product.title} for ${formatTaka(price)} on Browsly',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}

class _ProductBody extends StatelessWidget {
  const _ProductBody({required this.product, required this.provider});

  final ProductDetail product;
  final ProductDetailProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = provider.selected;
    final colours = provider.colours;
    final sizes = provider.sizes;
    final sectionStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Gallery(urls: product.imageUrls, title: product.title),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RatingLabel(
                    average: product.ratingAvg,
                    count: product.ratingCount,
                  ),
                  if (product.soldCount > 0)
                    Text(
                      '${formatCompactCount(product.soldCount)} sold',
                      style: theme.textTheme.bodySmall,
                    ),
                  Text(
                    product.isNew ? 'New' : 'Used',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (product.categoryName != null)
                    Text(
                      product.categoryName!,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (selected != null) _Price(variant: selected),
              if (selected != null) ...[
                const SizedBox(height: 4),
                _StockLabel(stock: selected.stock),
              ],
              if (colours.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Colour', style: sectionStyle),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final colour in colours)
                      PillChip(
                        label: colour,
                        selected: selected?.colour == colour,
                        onSelected: () => provider.selectColour(colour),
                      ),
                  ],
                ),
              ],
              if (sizes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Size', style: sectionStyle),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final size in sizes)
                      PillChip(
                        label: size,
                        selected: selected?.size == size,
                        onSelected: provider.isSizeOffered(size)
                            ? () => provider.selectSize(size)
                            : null,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _ShopCard(shop: product.shop),
              if (product.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Description', style: sectionStyle),
                const SizedBox(height: 4),
                Text(product.description),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.urls, required this.title});

  final List<String> urls;
  final String title;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    return AspectRatio(
      aspectRatio: 1,
      child: urls.isEmpty
          ? const AppNetworkImage(url: null)
          : Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  itemCount: urls.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) => AppNetworkImage(
                    url: urls[index],
                    semanticLabel: '${widget.title}, photo ${index + 1}',
                  ),
                ),
                if (urls.length > 1)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          '${_page + 1} / ${urls.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.variant});

  final ProductVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discount = variant.discountPercent;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          formatTaka(variant.price),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (discount != null) ...[
          Text(
            formatTaka(variant.compareAtPrice!),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          Text(
            '$discount% off',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _StockLabel extends StatelessWidget {
  const _StockLabel({required this.stock});

  /// Below this, buyers are told exactly how few are left.
  static const _lowStock = 5;

  final int stock;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (stock) {
      0 => ('Out of stock', AppColors.danger),
      < _lowStock + 1 => ('Only $stock left', AppColors.rating),
      _ => ('In stock', AppColors.success),
    };
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: color == AppColors.rating ? AppColors.textPrimary : color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop});

  final ProductShop shop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => context.push(AppRoutes.shop(shop.id)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox.square(
                      dimension: 44,
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
                              displayWidth: 44,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shop.name, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        RatingLabel(
                          average: shop.ratingAvg,
                          count: shop.ratingCount,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Delivery ${formatTaka(shop.deliveryFee)} · Cash on Delivery',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showComingSoon(context, 'Chat with seller'),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Chat with seller'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyBar extends StatelessWidget {
  const _BuyBar({required this.isInStock});

  final bool isInStock;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isInStock
                      ? () => _showComingSoon(context, 'The cart')
                      : null,
                  child: const Text('Add to Cart'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: isInStock
                      ? () => _showComingSoon(context, 'Buy Now')
                      : null,
                  child: const Text('Buy Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
}
