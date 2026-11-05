import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../providers/product_list_provider.dart';
import '../widgets/filter_button.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/paged_products_view.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openFilters(ProductListProvider provider) async {
    final filters = await showFilterSheet(context, provider.filters);
    if (filters != null) await provider.applySearchFilters(filters);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductListProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: AppRoutes.products),
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 100,
          textInputAction: TextInputAction.search,
          onChanged: provider.setQuery,
          decoration: InputDecoration(
            hintText: 'Search products',
            counterText: '',
            isDense: true,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _controller.clear();
                      provider.setQuery('');
                    },
                  ),
          ),
        ),
        actions: [
          FilterButton(
            count: provider.filters.refinementCount,
            onPressed: () => _openFilters(provider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PagedProductsView(
        provider: provider,
        onRefresh: provider.filters.hasQuery
            ? () => provider.reload(keepList: true)
            : () async {},
        idleView: const EmptyView(
          icon: Icons.search_rounded,
          title: 'What are you looking for?',
          message: 'Search by product name or description.',
        ),
        emptyView: const EmptyView(
          icon: Icons.search_off_rounded,
          title: 'No matching products',
          message: 'Check the spelling, or try fewer filters.',
        ),
      ),
    );
  }
}
