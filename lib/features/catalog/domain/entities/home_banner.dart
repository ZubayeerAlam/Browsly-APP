class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.imageUrl,
    this.title = '',
    this.productId,
  });

  final String id;
  final String imageUrl;
  final String title;

  /// The product it opens when tapped, if any.
  final String? productId;
}
