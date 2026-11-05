import '../entities/review.dart';

abstract interface class ReviewRepository {
  Future<ReviewPage> getReviews(
    String productId, {
    ReviewCursor? cursor,
    int limit = 20,
  });

  Future<void> submit(String orderItemId, int rating, {String? comment});
}
