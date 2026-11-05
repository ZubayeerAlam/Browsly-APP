import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ListingRemoteDataSource {
  const ListingRemoteDataSource(this._client);

  static const _bucket = 'product-images';

  final SupabaseClient _client;

  String photoUrl(String path) =>
      _client.storage.from(_bucket).getPublicUrl(path);

  Future<List<Map<String, dynamic>>> fetchMyListings(
    Map<String, dynamic> params,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_my_listings',
      params: params,
    );
    return rows.cast<Map<String, dynamic>>();
  }

  /// RLS limits this to the seller's own non-public listings and live ones, so
  /// the caller also checks the shop.
  Future<Map<String, dynamic>?> fetchListing(String id, String shopId) {
    return _client
        .from('products')
        .select('''
          id, title, description, category_id, condition, status,
          product_images (storage_path, sort_order),
          product_variants (options, price, compare_at_price, stock, is_active)
        ''')
        .eq('id', id)
        .eq('shop_id', shopId)
        .eq('product_variants.is_active', true)
        .isFilter('deleted_at', null)
        .maybeSingle();
  }

  Future<String?> fetchMyShopId() {
    return _client.rpc<String?>('current_shop_id');
  }

  Future<void> uploadPhoto(String path, Uint8List bytes) {
    return _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
  }

  Future<void> removePhotos(List<String> paths) {
    return _client.storage.from(_bucket).remove(paths);
  }

  Future<String> save(Map<String, dynamic> params) {
    return _client.rpc<String>('save_product', params: params);
  }

  Future<void> submit(String id) {
    return _client.rpc<void>(
      'submit_product_for_review',
      params: {'p_product_id': id},
    );
  }

  Future<void> setPaused(String id, bool paused) {
    return _client.rpc<void>(
      'set_product_paused',
      params: {'p_product_id': id, 'p_paused': paused},
    );
  }

  Future<List<String>> delete(String id) async {
    final paths = await _client.rpc<List<dynamic>>(
      'delete_product',
      params: {'p_product_id': id},
    );
    return paths.cast<String>();
  }
}
