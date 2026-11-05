import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ShopRemoteDataSource {
  const ShopRemoteDataSource(this._client);

  static const _bucket = 'shop-assets';

  final SupabaseClient _client;

  Future<String?> fetchMyShopId() {
    return _client.rpc<String?>('current_shop_id');
  }

  Future<String> createShop(Map<String, dynamic> params) {
    return _client.rpc<String>('become_seller', params: params);
  }

  Future<void> updateShop(String shopId, Map<String, dynamic> values) {
    return _client.from('shops').update(values).eq('id', shopId);
  }

  Future<String?> fetchLogoPath(String shopId) async {
    final row = await _client
        .from('shops')
        .select('logo_path')
        .eq('id', shopId)
        .single();
    return row['logo_path'] as String?;
  }

  Future<void> uploadLogo(String path, Uint8List bytes) {
    return _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
  }

  Future<void> removeLogo(String path) {
    return _client.storage.from(_bucket).remove([path]);
  }
}
