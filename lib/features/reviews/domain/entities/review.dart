class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.reviewerName,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final String comment;

  /// First name only.
  final String reviewerName;
  final DateTime createdAt;
}

/// Where the next page starts. Comes from the server, and is never built here.
class ReviewCursor {
  const ReviewCursor({required this.key, required this.id});

  final String key;
  final String id;
}

class ReviewPage {
  const ReviewPage({required this.items, this.next});

  final List<Review> items;

  /// Null when this is the last page.
  final ReviewCursor? next;
}
