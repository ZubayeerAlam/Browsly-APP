import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/failure_banner.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/listing.dart';
import '../providers/my_listings_provider.dart';

class MyPostsScreen extends StatelessWidget {
  const MyPostsScreen({super.key});

  void _newPost(BuildContext context) {
    context.go(AppRoutes.withFrom(AppRoutes.post, AppRoutes.myPosts));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MyListingsProvider>();
    return DefaultTabController(
      length: ListingTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallback: AppRoutes.dashboard),
          title: const Text('My Posts'),
          actions: [
            IconButton(
              tooltip: 'Edit shop',
              icon: const Icon(Icons.storefront_outlined),
              onPressed: () => context.go(AppRoutes.editShop),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (index) => provider.setTab(ListingTab.values[index]),
            tabs: [for (final tab in ListingTab.values) Tab(text: tab.label)],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _newPost(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Post New Product'),
        ),
        body: _ListingsBody(provider: provider),
      ),
    );
  }
}

class _ListingsBody extends StatelessWidget {
  const _ListingsBody({required this.provider});

  final MyListingsProvider provider;

  @override
  Widget build(BuildContext context) {
    final state = provider.state;
    final items = state.data;
    if (items == null) {
      return switch (state.status) {
        ViewStatus.error => ErrorView(
          message: state.failure!.message,
          onRetry: provider.load,
        ),
        ViewStatus.empty => EmptyView(
          icon: Icons.inventory_2_outlined,
          title: 'Nothing here yet',
          message: provider.tab == ListingTab.all
              ? 'Post your first product to start selling.'
              : 'Listings with this status will appear here.',
        ),
        _ => const LoadingView(),
      };
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 300) provider.loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () => provider.load(keepList: true),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: items.length + 1,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              final failure = provider.actionFailure;
              return failure == null
                  ? const SizedBox.shrink()
                  : FailureBanner(failure: ValidationFailure(failure));
            }
            return _ListingCard(listing: items[index - 1], provider: provider);
          },
        ),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing, required this.provider});

  final ListingSummary listing;
  final MyListingsProvider provider;

  void _edit(BuildContext context) {
    context.go(AppRoutes.editListing(listing.id));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: Text('"${listing.title}" will be removed for good.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.delete(listing);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = listing.price;
    final reason = listing.rejectionReason;
    final status = listing.status;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => status == ListingStatus.active
            ? context.push(AppRoutes.product(listing.id))
            : _edit(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox.square(
                      dimension: 72,
                      child: AppNetworkImage(
                        url: listing.imageUrl,
                        displayWidth: 72,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          listing.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (price != null) formatTaka(price),
                            '${listing.totalStock} in stock',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        _StatusChip(status: status),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Listing actions',
                    onSelected: (action) => switch (action) {
                      'edit' => _edit(context),
                      'pause' => provider.setPaused(listing, paused: true),
                      'resume' => provider.setPaused(listing, paused: false),
                      _ => _confirmDelete(context),
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (status == ListingStatus.active)
                        const PopupMenuItem(
                          value: 'pause',
                          child: Text('Pause'),
                        ),
                      if (status == ListingStatus.paused)
                        const PopupMenuItem(
                          value: 'resume',
                          child: Text('Resume'),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
              if (status == ListingStatus.rejected && reason != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Why it was rejected: $reason',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Edit it and submit it again.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ListingStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      ListingStatus.active => (AppColors.successSoft, AppColors.success),
      ListingStatus.rejected ||
      ListingStatus.removed => (AppColors.dangerSoft, AppColors.danger),
      _ => (AppColors.primarySoft, AppColors.primary),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          status.label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
