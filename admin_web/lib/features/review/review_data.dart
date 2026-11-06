import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/paging.dart';
import '../../core/errors/error_mapper.dart';

class QueuedProduct {
  const QueuedProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.isNew,
    required this.shopName,
    required this.categoryName,
    required this.price,
    required this.totalStock,
    required this.imageUrls,
    required this.variantNames,
    required this.waitingSince,
    this.aiDecision,
    this.reasonCode,
    this.aiReason,
  });

  final String id;
  final String title;
  final String description;
  final bool isNew;
  final String shopName;
  final String categoryName;
  final double? price;
  final int totalStock;
  final List<String> imageUrls;
  final List<String> variantNames;
  final DateTime waitingSince;

  /// Null when the AI could not give an answer in time.
  final String? aiDecision;
  final String? reasonCode;
  final String? aiReason;
}

abstract interface class ReviewRepository {
  Future<ItemPage<QueuedProduct>> getQueue({
    PageCursor? cursor,
    int limit = 20,
  });

  Future<void> approve(String productId);

  /// [reason] is shown to the seller.
  Future<void> reject(String productId, String reason);
}

class ReviewRepositoryImpl implements ReviewRepository {
  const ReviewRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<ItemPage<QueuedProduct>> getQueue({
    PageCursor? cursor,
    int limit = 20,
  }) {
    return guardFailures(() async {
      final rows = await _client.rpc<List<dynamic>>(
        'admin_get_review_queue',
        params: {
          'p_cursor_key': cursor?.key,
          'p_cursor_id': cursor?.id,
          'p_limit': limit + 1,
        },
      );
      final images = _client.storage.from('product-images');
      return pageFromRows(rows, limit, (row) {
        return QueuedProduct(
          id: row['id'] as String,
          title: row['title'] as String,
          description: row['description'] as String,
          isNew: row['condition'] == 'new',
          shopName: row['shop_name'] as String,
          categoryName: row['category_name'] as String,
          price: (row['price'] as num?)?.toDouble(),
          totalStock: (row['total_stock'] as num).toInt(),
          imageUrls: (row['image_paths'] as List<dynamic>)
              .map((path) => images.getPublicUrl(path as String))
              .toList(),
          variantNames: (row['variant_names'] as List<dynamic>).cast<String>(),
          waitingSince: parseTime(row['waiting_since']),
          aiDecision: row['ai_decision'] as String?,
          reasonCode: row['reason_code'] as String?,
          aiReason: row['ai_reason'] as String?,
        );
      });
    });
  }

  Future<void> _decide(String id, String decision, String? reason) {
    return guardFailures(
      () => _client.rpc<void>(
        'admin_decide_product',
        params: {
          'p_product_id': id,
          'p_decision': decision,
          'p_reason': reason,
        },
      ),
    );
  }

  @override
  Future<void> approve(String productId) => _decide(productId, 'approve', null);

  @override
  Future<void> reject(String productId, String reason) {
    return _decide(productId, 'reject', reason);
  }
}
