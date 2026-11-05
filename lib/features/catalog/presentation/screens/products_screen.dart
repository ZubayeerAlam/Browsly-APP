import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/state_views.dart';
import '../providers/product_list_provider.dart';
import '../widgets/category_chips.dart';
import '../widgets/filter_button.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/paged_products_view.dart';

/// The Products tab. The chosen category lives in the address, so a category
/// tapped on the Dashboard selects the same chip.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({this.categoryId, super.key});

  final String? categoryId;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  @override
  void didUpdateWidget(ProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      // Reloading notifies listeners, which isn't allowed during a build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ProductListProvider>().setCategory(widget.categoryId);
        }
      });
    }
  }

  Future<void> _openFilters(ProductListProvider provider) async {
    final filters = await showFilterSheet(context, provider.filters);
    if (filters != null) await provider.applyFilters(filters);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductListProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => context.push(AppRoutes.search),
            icon: const Icon(Icons.search_rounded),
          ),
          FilterButton(
            count: provider.filters.refinementCount,
            onPressed: () => _openFilters(provider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PagedProductsView(
        provider: provider,
        onRefresh: provider.refresh,
        headerSlivers: [
          if (provider.categories.isNotEmpty)
            SliverToBoxAdapter(
              child: CategoryChips(
                categories: provider.categories,
                totalCount: provider.totalProductCount,
                selectedId: provider.filters.categoryId,
                onSelected: (id) => context.go(AppRoutes.productsIn(id)),
              ),
            ),
        ],
        emptyView: const EmptyView(
          icon: Icons.inventory_2_outlined,
          title: 'No products yet',
          message: 'Try another category or fewer filters.',
        ),
      ),
    );
  }
}
