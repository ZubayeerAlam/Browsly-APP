import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogRemoteDataSource {
  const CatalogRemoteDataSource(this._client);

  static const _productBucket = 'product-images';
  static const _shopBucket = 'shop-assets';

  final SupabaseClient _client;

  String productImageUrl(String path) =>
      _client.storage.from(_productBucket).getPublicUrl(path);

  String shopAssetUrl(String path) =>
      _client.storage.from(_shopBucket).getPublicUrl(path);

  String bannerImageUrl(String path) =>
      _client.storage.from('banners').getPublicUrl(path);

  /// RLS limits this to banners showing now.
  Future<List<Map<String, dynamic>>> fetchBanners() {
    return _client
        .from('home_banners')
        .select('id, image_path, title, product_id')
        .order('sort_order', ascending: true)
        .limit(10);
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final rows = await _client.rpc<List<dynamic>>('get_categories_with_counts');
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> searchProducts(
    Map<String, dynamic> params,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'search_products',
      params: params,
    );
    return rows.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> fetchProduct(String id) {
    return _client
        .from('products')
        .select('''
          id, title, description, condition, rating_avg, rating_count, sold_count,
          shops!inner (id, name, logo_path, delivery_fee, rating_avg, rating_count),
          categories (name),
          product_images (storage_path, sort_order),
          product_variants (id, options, price, compare_at_price, stock)
        ''')
        .eq('id', id)
        // A seller's own product also has variants they have turned off.
        .eq('product_variants.is_active', true)
        .isFilter('deleted_at', null)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> fetchShop(String id) {
    return _client
        .from('shops')
        .select('''
          id, name, description, logo_path, banner_path, delivery_fee,
          rating_avg, rating_count, region_id, regions (name)
        ''')
        .eq('id', id)
        .maybeSingle();
  }
}
