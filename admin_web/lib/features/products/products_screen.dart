import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/state/paged_provider.dart';
import '../../core/widgets/admin_page.dart';
import 'products_data.dart';

typedef _Provider = PagedProvider<AdminProduct, String>;

const _statusLabels = <String?, String>{
  null: 'All',
  'active': 'Live',
  'pending_review': 'With the AI',
  'admin_review': 'Admin review',
  'rejected': 'Rejected',
  'paused': 'Paused',
  'draft': 'Draft',
  'removed': 'Removed',
};

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  Future<void> _toggle(BuildContext context, AdminProduct product) async {
    final provider = context.read<_Provider>();
    final repository = context.read<ProductsRepository>();
    if (product.isRemoved) {
      final answer = await askToConfirm(
        context,
        title: 'Put this listing back on sale?',
        message: 'It goes live straight away, and the seller is told.',
        confirmLabel: 'Restore',
      );
      if (answer != null) {
        await provider.act(() => repository.setRemoved(product.id, false));
      }
      return;
    }
    final reason = await askToConfirm(
      context,
      title: 'Remove this listing?',
      message:
          'It leaves the marketplace straight away. The seller sees your '
          'reason, and cannot bring it back themselves.',
      reasonLabel: 'Reason for the seller',
      reasonRequired: true,
      confirmLabel: 'Remove',
      isDanger: true,
    );
    if (reason != null) {
      await provider.act(
        () => repository.setRemoved(product.id, true, reason: reason),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final repository = context.read<ProductsRepository>();
        return _Provider(
          (search, status, next) => repository.getProducts(
            search: search,
            status: status,
            cursor: next,
          ),
        )..load();
      },
      child: Builder(
        builder: (context) {
          final provider = context.watch<_Provider>();
          return AdminPage(
            title: 'Products',
            actions: [
              SearchBox(
                hint: 'Title or shop',
                onChanged: context.read<_Provider>().setSearch,
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilterChips<String>(
                  selected: provider.filter,
                  options: _statusLabels,
                  onSelected: provider.setFilter,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PagedBody(
                    provider: provider,
                    emptyTitle: 'No products found',
                    builder: (context, items) => AdminTable(
                      columns: const [
                        '',
                        'Title',
                        'Shop',
                        'Price',
                        'Stock',
                        'Sold',
                        'Status',
                        '',
                      ],
                      rows: [
                        for (final product in items)
                          DataRow(
                            cells: [
                              DataCell(PhotoThumb(url: product.imageUrl)),
                              DataCell(
                                SizedBox(
                                  width: 260,
                                  child: Text(
                                    product.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(product.shopName)),
                              DataCell(
                                Text(
                                  product.price == null
                                      ? '–'
                                      : formatTaka(product.price!),
                                ),
                              ),
                              DataCell(Text('${product.totalStock}')),
                              DataCell(Text('${product.soldCount}')),
                              DataCell(
                                StatusPill(
                                  label:
                                      _statusLabels[product.status] ??
                                      product.status,
                                  isBad: product.isRemoved,
                                ),
                              ),
                              DataCell(
                                product.isRemoved ||
                                        product.status == 'active' ||
                                        product.status == 'paused'
                                    ? TextButton(
                                        onPressed: () =>
                                            _toggle(context, product),
                                        child: Text(
                                          product.isRemoved
                                              ? 'Restore'
                                              : 'Remove',
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
