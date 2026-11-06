import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/state/paged_provider.dart';
import '../../core/widgets/admin_page.dart';
import 'orders_data.dart';

typedef _Provider = PagedProvider<AdminOrder, String>;

const _statusLabels = <String?, String>{
  null: 'All',
  'pending': 'Pending',
  'packaging': 'Packaging',
  'out_for_delivery': 'Out for delivery',
  'completed': 'Complete',
  'cancelled': 'Cancelled',
  'delivery_failed': 'Delivery failed',
};

/// For looking things up. Orders are moved along by their sellers, not admins.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final repository = context.read<OrdersRepository>();
        return _Provider(
          (search, status, next) => repository.getOrders(
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
            title: 'Orders',
            actions: [
              SearchBox(
                hint: 'Order number, shop or buyer',
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
                    emptyTitle: 'No orders found',
                    builder: (context, items) => AdminTable(
                      columns: const [
                        'Order',
                        'Shop',
                        'Buyer',
                        'Amount',
                        'Commission',
                        'Placed',
                        'Status',
                      ],
                      rows: [
                        for (final order in items)
                          DataRow(
                            cells: [
                              DataCell(Text(order.orderNumber)),
                              DataCell(Text(order.shopName)),
                              DataCell(Text(order.buyerName)),
                              DataCell(Text(formatTaka(order.amount))),
                              DataCell(Text(formatTaka(order.commission))),
                              DataCell(Text(formatDateTime(order.createdAt))),
                              DataCell(
                                StatusPill(
                                  label:
                                      _statusLabels[order.status] ??
                                      order.status,
                                  isBad:
                                      order.status == 'cancelled' ||
                                      order.status == 'delivery_failed',
                                ),
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
