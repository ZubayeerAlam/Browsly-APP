import 'package:supabase_flutter/supabase_flutter.dart';

class SalesRemoteDataSource {
  const SalesRemoteDataSource(this._client);

  final SupabaseClient _client;

  String productImageUrl(String path) =>
      _client.storage.from('product-images').getPublicUrl(path);

  Future<List<Map<String, dynamic>>> _rows(
    String function,
    Map<String, dynamic> params,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(function, params: params);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchSales(Map<String, dynamic> params) {
    return _rows('get_shop_orders', params);
  }

  /// Null if it isn't this seller's order.
  Future<Map<String, dynamic>?> fetchSale(String id) {
    return _client.rpc<Map<String, dynamic>?>(
      'get_shop_order',
      params: {'p_group_id': id},
    );
  }

  Future<void> setStatus(String id, String status, String? note) {
    return _client.rpc<void>(
      'update_group_status',
      params: {'p_group_id': id, 'p_status': status, 'p_note': note},
    );
  }

  Future<void> cancel(String id, String? reason) {
    return _client.rpc<void>(
      'cancel_order_group',
      params: {'p_group_id': id, 'p_reason': reason},
    );
  }

  Future<Map<String, dynamic>> fetchCommissionSummary() {
    return _client.rpc<Map<String, dynamic>>('get_commission_summary');
  }

  Future<List<Map<String, dynamic>>> fetchCommissionEntries(
    Map<String, dynamic> params,
  ) {
    return _rows('get_commission_entries', params);
  }
}
