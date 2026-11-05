import 'package:supabase_flutter/supabase_flutter.dart';

class WishlistRemoteDataSource {
  const WishlistRemoteDataSource(this._client);

  final SupabaseClient _client;

  String productImageUrl(String path) =>
      _client.storage.from('product-images').getPublicUrl(path);

  Future<List<Map<String, dynamic>>> fetchSavedIds() {
    return _client.from('wishlist_items').select('product_id');
  }

  /// Saving something twice, such as from a second device, is not an error.
  Future<void> add(String productId) {
    return _client.from('wishlist_items').upsert({
      'product_id': productId,
    }, ignoreDuplicates: true);
  }

  /// RLS limits this to the signed-in user's own rows.
  Future<void> remove(String productId) {
    return _client.from('wishlist_items').delete().eq('product_id', productId);
  }

  Future<List<Map<String, dynamic>>> fetchPage(
    Map<String, dynamic> params,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_wishlist',
      params: params,
    );
    return rows.cast<Map<String, dynamic>>();
  }
}
