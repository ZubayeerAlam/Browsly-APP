import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_models.dart';

class OrderRemoteDataSource {
  const OrderRemoteDataSource(this._client);

  final SupabaseClient _client;

  String productImageUrl(String path) =>
      _client.storage.from('product-images').getPublicUrl(path);

  Future<Map<String, dynamic>> placeOrder({
    required String addressId,
    required String idempotencyKey,
    required double expectedTotal,
    String? buyNowVariantId,
  }) {
    return _client.rpc<Map<String, dynamic>>(
      'place_order',
      params: {
        'p_address_id': addressId,
        'p_idempotency_key': idempotencyKey,
        'p_expected_total': expectedTotal,
        'p_buy_now_variant_id': buyNowVariantId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchPage(
    Map<String, dynamic> params,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_my_orders',
      params: params,
    );
    return rows.cast<Map<String, dynamic>>();
  }

  /// RLS limits this to the signed-in buyer's own orders.
  Future<Map<String, dynamic>?> fetchOrder(String id) {
    return _client
        .from('orders')
        .select(OrderModel.detailColumns)
        .eq('id', id)
        .maybeSingle();
  }

  Future<void> cancelGroup(String groupId) {
    return _client.rpc<void>(
      'cancel_order_group',
      params: {'p_group_id': groupId},
    );
  }
}
