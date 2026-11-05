import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../providers/reviews_provider.dart';
import '../widgets/review_tile.dart';

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReviewsProvider>();
    final state = provider.state;
    final reviews = state.data;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(fallback: AppRoutes.product(provider.productId)),
        title: const Text('Reviews'),
      ),
      body: switch (state.status) {
        ViewStatus.empty => const EmptyView(
          icon: Icons.star_border_rounded,
          title: 'No reviews yet',
        ),
        ViewStatus.error when reviews == null => ErrorView(
          message: state.failure!.message,
          onRetry: provider.load,
        ),
        _ when reviews == null => const LoadingView(),
        _ => ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: reviews.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == reviews.length - 1) provider.loadMore();
            return ReviewTile(review: reviews[index]);
          },
        ),
      },
    );
  }
}
