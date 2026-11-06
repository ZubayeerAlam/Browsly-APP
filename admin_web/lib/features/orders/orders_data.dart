import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/paging.dart';
import '../../core/errors/error_mapper.dart';

/// One seller's part of an order.
class AdminOrder {
  const AdminOrder({
    required this.id,
    required this.orderNumber,
    required this.shopName,
    required this.buyerName,
    required this.status,
    required this.amount,
    required this.commission,
    required this.createdAt,
  });

  final String id;
  final String orderNumber;
  final String shopName;
  final String buyerName;

  /// The database status, such as `out_for_delivery`.
  final String status;
  final double amount;
  final double commission;
  final DateTime createdAt;
}

abstract interface class OrdersRepository {
  Future<ItemPage<AdminOrder>> getOrders({
    String? search,
    String? status,
    PageCursor? cursor,
    int limit = 30,
  });
}

class OrdersRepositoryImpl implements OrdersRepository {
  const OrdersRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<ItemPage<AdminOrder>> getOrders({
    String? search,
    String? status,
    PageCursor? cursor,
    int limit = 30,
  }) {
    return guardFailures(() async {
      final rows = await _client.rpc<List<dynamic>>(
        'admin_list_orders',
        params: {
          'p_search': search,
          'p_status': status,
          'p_cursor_key': cursor?.key,
          'p_cursor_id': cursor?.id,
          'p_limit': limit + 1,
        },
      );
      return pageFromRows(rows, limit, (row) {
        return AdminOrder(
          id: row['id'] as String,
          orderNumber: row['order_number'] as String,
          shopName: row['shop_name'] as String,
          buyerName: row['buyer_name'] as String,
          status: row['status'] as String,
          amount: parseMoney(row['amount']),
          commission: parseMoney(row['commission']),
          createdAt: parseTime(row['created_at']),
        );
      });
    });
  }
}
