import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  const ReviewRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<ReviewPage> getReviews(
    String productId, {
    ReviewCursor? cursor,
    int limit = 20,
  }) {
    return guardFailures(() async {
      // One extra row shows whether another page exists.
      final result = await _client.rpc<List<dynamic>>(
        'get_product_reviews',
        params: {
          'p_product_id': productId,
          'p_cursor_key': cursor?.key,
          'p_cursor_id': cursor?.id,
          'p_limit': limit + 1,
        },
      );
      final rows = result.cast<Map<String, dynamic>>();
      final hasMore = rows.length > limit;
      final pageRows = hasMore ? rows.sublist(0, limit) : rows;
      return ReviewPage(
        items: pageRows
            .map(
              (row) => Review(
                id: row['id'] as String,
                rating: (row['rating'] as num).toInt(),
                comment: row['comment'] as String,
                reviewerName: row['reviewer_name'] as String,
                createdAt: DateTime.parse(row['created_at'] as String)
                    .toLocal(),
              ),
            )
            .toList(),
        next: hasMore
            ? ReviewCursor(
                key: pageRows.last['cursor_key'] as String,
                id: pageRows.last['id'] as String,
              )
            : null,
      );
    });
  }

  @override
  Future<void> submit(String orderItemId, int rating, {String? comment}) {
    return guardFailures(
      () => _client.rpc<String>(
        'submit_review',
        params: {
          'p_order_item_id': orderItemId,
          'p_rating': rating,
          'p_comment': comment,
        },
      ),
    );
  }
}
