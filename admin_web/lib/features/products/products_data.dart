import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/paging.dart';
import '../../core/errors/error_mapper.dart';

class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.title,
    required this.shopName,
    required this.status,
    required this.totalStock,
    required this.soldCount,
    this.price,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String shopName;

  /// The database status, such as `active`.
  final String status;
  final double? price;
  final int totalStock;
  final int soldCount;
  final String? imageUrl;

  bool get isRemoved => status == 'removed';
}

abstract interface class ProductsRepository {
  Future<ItemPage<AdminProduct>> getProducts({
    String? search,
    String? status,
    PageCursor? cursor,
    int limit = 30,
  });

  /// [reason] is shown to the seller, and is required when removing.
  Future<void> setRemoved(String productId, bool removed, {String? reason});
}

class ProductsRepositoryImpl implements ProductsRepository {
  const ProductsRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<ItemPage<AdminProduct>> getProducts({
    String? search,
    String? status,
    PageCursor? cursor,
    int limit = 30,
  }) {
    return guardFailures(() async {
      final rows = await _client.rpc<List<dynamic>>(
        'admin_list_products',
        params: {
          'p_search': search,
          'p_status': status,
          'p_cursor_key': cursor?.key,
          'p_cursor_id': cursor?.id,
          'p_limit': limit + 1,
        },
      );
      final images = _client.storage.from('product-images');
      return pageFromRows(rows, limit, (row) {
        final path = row['image_path'] as String?;
        return AdminProduct(
          id: row['id'] as String,
          title: row['title'] as String,
          shopName: row['shop_name'] as String,
          status: row['status'] as String,
          price: (row['price'] as num?)?.toDouble(),
          totalStock: (row['total_stock'] as num).toInt(),
          soldCount: (row['sold_count'] as num).toInt(),
          imageUrl: path == null ? null : images.getPublicUrl(path),
        );
      });
    });
  }

  @override
  Future<void> setRemoved(String productId, bool removed, {String? reason}) {
    return guardFailures(
      () => _client.rpc<void>(
        'admin_set_product_removed',
        params: {
          'p_product_id': productId,
          'p_removed': removed,
          'p_reason': reason,
        },
      ),
    );
  }
}
