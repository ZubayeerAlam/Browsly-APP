import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../cart/presentation/widgets/add_to_cart.dart';
import '../../../statistics/domain/entities/seller_stats.dart';
import '../../../statistics/domain/repositories/statistics_repository.dart';
import '../../../wishlist/presentation/widgets/wishlist_button.dart';
import '../../domain/entities/product.dart';
import 'rating_label.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({required this.product, this.imageWidth = 200, super.key});

  /// Space needed below the square photo, before scaling for large text.
  static const textAreaHeight = 112.0;

  final ProductSummary product;
  final double imageWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discount = product.discountPercent;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: () {
              context.read<StatisticsRepository>().track(
                AnalyticsEvent.click,
                product.id,
              );
              context.push(AppRoutes.product(product.id));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(
                        url: product.imageUrl,
                        displayWidth: imageWidth,
                        semanticLabel: product.title,
                      ),
                      if (!product.isInStock) const _SoldOutOverlay(),
                      if (discount != null)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: _DiscountBadge(percent: discount),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        // Leaves room for the cart button in the corner.
                        Padding(
                          padding: EdgeInsets.only(
                            right: product.isInStock ? 36 : 0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    formatTaka(product.price),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (discount != null)
                                    Text(
                                      formatTaka(product.compareAtPrice!),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              RatingLabel(
                                average: product.ratingAvg,
                                count: product.ratingCount,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: WishlistButton(productId: product.id, filled: true),
          ),
          if (product.isInStock)
            Positioned(
              right: 0,
              bottom: 0,
              child: CardCartButton(productId: product.id),
            ),
        ],
      ),
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          '-$percent%',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SoldOutOverlay extends StatelessWidget {
  const _SoldOutOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white70,
      child: Center(
        child: Text(
          'Sold out',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
