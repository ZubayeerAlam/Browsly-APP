import 'package:flutter/material.dart';

import '../../../../core/state/view_state.dart';
import '../../../../core/widgets/failure_banner.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/product.dart';
import '../providers/paged_products_provider.dart';
import 'product_card.dart';

/// A scrolling product grid with pull to refresh, automatic paging, and loading,
/// empty and error states.
class PagedProductsView extends StatelessWidget {
  const PagedProductsView({
    required this.provider,
    required this.emptyView,
    required this.onRefresh,
    this.headerSlivers = const [],
    this.idleView,
    this.visibleWhen,
    super.key,
  });

  /// How close to the end, in pixels, the next page starts to load.
  static const _loadMoreDistance = 400.0;

  final PagedProductsProvider provider;
  final Widget emptyView;
  final Future<void> Function() onRefresh;
  final List<Widget> headerSlivers;

  /// Shown before anything has been asked for, such as before typing a search.
  final Widget? idleView;

  /// Lets a screen hide rows, such as ones just removed from the wishlist.
  final bool Function(ProductSummary)? visibleWhen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.depth == 0 &&
                notification.metrics.extentAfter < _loadMoreDistance) {
              provider.loadMore();
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [...headerSlivers, ..._contentSlivers(context)],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _contentSlivers(BuildContext context) {
    final state = provider.state;
    final items = state.data;
    if (items == null) {
      return [
        SliverFillRemaining(
          child: switch (state.status) {
            ViewStatus.error => ErrorView(
              message: state.failure!.message,
              onRetry: provider.reload,
            ),
            ViewStatus.empty => emptyView,
            ViewStatus.initial when idleView != null => idleView!,
            _ => const LoadingView(),
          },
        ),
      ];
    }
    final visibleWhen = this.visibleWhen;
    final visible = visibleWhen == null
        ? items
        : items.where(visibleWhen).toList();
    if (visible.isEmpty && !provider.hasMore) {
      return [SliverFillRemaining(child: emptyView)];
    }
    if (visible.isEmpty) {
      // Everything on this page was hidden, so nothing can scroll to load more.
      WidgetsBinding.instance.addPostFrameCallback((_) => provider.loadMore());
    }
    return [
      if (state.status == ViewStatus.error)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverToBoxAdapter(
            child: FailureBanner(failure: state.failure),
          ),
        ),
      _ProductGrid(products: visible),
      SliverToBoxAdapter(child: _Footer(provider: provider)),
    ];
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});

  static const _padding = 16.0;
  static const _spacing = 12.0;
  static const _minCardWidth = 160.0;

  final List<ProductSummary> products;

  @override
  Widget build(BuildContext context) {
    final textArea = MediaQuery.textScalerOf(context)
        .scale(ProductCard.textAreaHeight);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(_padding, 8, _padding, 8),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final columns = (width / (_minCardWidth + _spacing)).floor().clamp(
            2,
            6,
          );
          final cardWidth = (width - _spacing * (columns - 1)) / columns;
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: _spacing,
              crossAxisSpacing: _spacing,
              mainAxisExtent: cardWidth + textArea,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) => ProductCard(
              key: ValueKey(products[index].id),
              product: products[index],
              imageWidth: cardWidth,
            ),
          );
        },
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.provider});

  final PagedProductsProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.loadMoreFailure != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: OutlinedButton(
            onPressed: provider.loadMore,
            child: const Text('Load more'),
          ),
        ),
      );
    }
    if (provider.isLoadingMore) {
      return const Padding(padding: EdgeInsets.all(24), child: LoadingView());
    }
    return const SizedBox(height: 16);
  }
}
