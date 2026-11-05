import 'package:supabase_flutter/supabase_flutter.dart';

class CartRemoteDataSource {
  const CartRemoteDataSource(this._client);

  final SupabaseClient _client;

  String productImageUrl(String path) =>
      _client.storage.from('product-images').getPublicUrl(path);

  Future<Map<String, dynamic>> getCart() {
    return _client.rpc<Map<String, dynamic>>('get_cart');
  }

  Future<Map<String, dynamic>> getBuyNow(String variantId) {
    return _client.rpc<Map<String, dynamic>>(
      'get_buy_now',
      params: {'p_variant_id': variantId},
    );
  }

  Future<Map<String, dynamic>> addVariant(String variantId) {
    return _client.rpc<Map<String, dynamic>>(
      'add_to_cart',
      params: {'p_variant_id': variantId},
    );
  }

  Future<Map<String, dynamic>> addProduct(String productId) {
    return _client.rpc<Map<String, dynamic>>(
      'add_product_to_cart',
      params: {'p_product_id': productId},
    );
  }

  Future<Map<String, dynamic>> setQuantity(String variantId, int quantity) {
    return _client.rpc<Map<String, dynamic>>(
      'set_cart_quantity',
      params: {'p_variant_id': variantId, 'p_quantity': quantity},
    );
  }
}
