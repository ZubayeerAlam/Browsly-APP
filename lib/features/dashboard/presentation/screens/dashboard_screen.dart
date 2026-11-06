import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cart/presentation/widgets/cart_icon_button.dart';
import '../../../catalog/domain/entities/category.dart';
import '../../../catalog/domain/entities/home_banner.dart';
import '../../../catalog/domain/entities/product.dart';
import '../../../catalog/presentation/widgets/category_icon.dart';
import '../../../catalog/presentation/widgets/product_card.dart';
import '../../../notifications/presentation/widgets/top_bar_icons.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../statistics/presentation/providers/seller_dashboard_provider.dart';
import '../../../statistics/presentation/widgets/seller_summary_card.dart';
import '../providers/home_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSignedIn = context.select<AuthProvider, bool>(
      (auth) => auth.isSignedIn,
    );
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Browsly', style: TextStyle(color: AppColors.primary)),
          ],
        ),
        actions: [
          if (isSignedIn) ...[
            const ChatIconButton(),
            const NotificationIconButton(),
          ],
          const CartIconButton(),
          if (isSignedIn)
            const _AccountMenu()
          else
            TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Sign in'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: const _HomeBody(),
    );
  }
}

/// The profile picture. More items join this menu as their features arrive.
class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context) {
    final avatarUrl = context.select<ProfileProvider, String?>(
      (provider) => provider.profile?.avatarUrl,
    );
    return PopupMenuButton<String>(
      tooltip: 'Account',
      onSelected: context.go,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: AppRoutes.orders,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.receipt_long_outlined),
            title: Text('My Orders'),
          ),
        ),
        PopupMenuItem(
          value: AppRoutes.myPosts,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.inventory_2_outlined),
            title: Text('My Posts'),
          ),
        ),
        PopupMenuItem(
          value: AppRoutes.wishlist,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.favorite_border_rounded),
            title: Text('Wishlist'),
          ),
        ),
        PopupMenuItem(
          value: AppRoutes.settings,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ProfileAvatar(url: avatarUrl, radius: 18),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final state = provider.state;
    final content = state.data;
    if (content == null) {
      return state.status == ViewStatus.error
          ? ErrorView(message: state.failure!.message, onRetry: provider.load)
          : const LoadingView();
    }
    return RefreshIndicator(
      onRefresh: () async {
        final seller = context.read<SellerDashboardProvider>();
        await Future.wait([provider.load(), seller.load()]);
      },
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          const _SearchBar(),
          const SellerSummaryCard(),
          if (content.banners.isNotEmpty)
            _PromoBanners(banners: content.banners),
          const _Banner(),
          if (content.categories.isNotEmpty)
            _CategoryRow(categories: content.categories),
          _ProductSection(
            title: 'Popular right now',
            products: content.popular,
          ),
          _ProductSection(title: 'New arrivals', products: content.newest),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Semantics(
        button: true,
        label: 'Search products',
        child: ExcludeSemantics(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(AppRoutes.search),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Search products',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the admin panel has chosen to promote.
class _PromoBanners extends StatelessWidget {
  const _PromoBanners({required this.banners});

  final List<HomeBanner> banners;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AspectRatio(
        aspectRatio: 3,
        child: PageView(
          controller: PageController(viewportFraction: 0.92),
          children: [
            for (final banner in banners)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: banner.productId == null
                        ? null
                        : () => context.push(
                            AppRoutes.product(banner.productId!),
                          ),
                    child: AppNetworkImage(
                      url: banner.imageUrl,
                      semanticLabel: banner.title,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Guests are invited to join. Signed-in users are invited to sell.
class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSignedIn = context.select<AuthProvider, bool>(
      (auth) => auth.isSignedIn,
    );
    final name = context.select<ProfileProvider, String?>(
      (provider) => provider.profile?.fullName,
    );
    final greeting = name == null || name.isEmpty
        ? 'Welcome back!'
        : 'Welcome back, ${name.split(' ').first}!';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSignedIn ? greeting : 'Buy and sell on Browsly',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isSignedIn
                    ? 'Have something to sell? Start posting today.'
                    : 'Save your favourites and open your own shop.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                onPressed: () => context.go(
                  isSignedIn
                      ? AppRoutes.withFrom(AppRoutes.post, AppRoutes.dashboard)
                      : AppRoutes.login,
                ),
                child: Text(isSignedIn ? 'Start posting' : 'Get started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Categories'),
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(100),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              return SizedBox(
                width: 84,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.go(AppRoutes.productsIn(category.id)),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primarySoft,
                        child: Icon(
                          categoryIcon(category.icon),
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductSection extends StatelessWidget {
  const _ProductSection({required this.title, required this.products});

  static const _cardWidth = 164.0;

  final String title;
  final List<ProductSummary> products;

  @override
  Widget build(BuildContext context) {
    final textArea = MediaQuery.textScalerOf(context)
        .scale(ProductCard.textAreaHeight);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: title,
          action: TextButton(
            onPressed: () => context.go(AppRoutes.products),
            child: const Text('See all'),
          ),
        ),
        if (products.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Nothing here yet. Check back soon.'),
          )
        else
          SizedBox(
            height: _cardWidth + textArea,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: _cardWidth,
                child: ProductCard(
                  product: products[index],
                  imageWidth: _cardWidth,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
