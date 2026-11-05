import '../../domain/entities/listing.dart';

typedef UrlBuilder = String Function(String path);

abstract final class ListingModels {
  static ListingStatus statusFromJson(String status) => switch (status) {
    'draft' => ListingStatus.draft,
    'pending_review' || 'admin_review' => ListingStatus.inReview,
    'active' => ListingStatus.active,
    'rejected' => ListingStatus.rejected,
    'paused' => ListingStatus.paused,
    _ => ListingStatus.removed,
  };

  /// The database statuses behind each My Posts tab. Null means every status.
  static List<String>? statusesForTab(ListingTab tab) => switch (tab) {
    ListingTab.all => null,
    ListingTab.active => const ['active', 'paused'],
    ListingTab.inReview => const ['pending_review', 'admin_review'],
    ListingTab.draft => const ['draft'],
    ListingTab.rejected => const ['rejected'],
  };

  /// Turns one more row than a page needs into a page and its next cursor.
  static ListingPage pageFromRows(
    List<Map<String, dynamic>> rows,
    int limit,
    UrlBuilder photoUrl,
  ) {
    final kept = rows.take(limit).toList();
    return ListingPage(
      items: kept.map((row) {
        final path = row['image_path'] as String?;
        return ListingSummary(
          id: row['id'] as String,
          title: row['title'] as String,
          status: statusFromJson(row['status'] as String),
          imageUrl: path == null ? null : photoUrl(path),
          price: (row['price'] as num?)?.toDouble(),
          totalStock: row['total_stock'] as int,
          rejectionReason: row['rejection_reason'] as String?,
        );
      }).toList(),
      next: rows.length > limit && kept.isNotEmpty
          ? ListingCursor(
              key: kept.last['cursor_key'] as String,
              id: kept.last['id'] as String,
            )
          : null,
    );
  }

  static EditableListing editableFromJson(
    Map<String, dynamic> json,
    UrlBuilder photoUrl,
  ) {
    final images =
        (json['product_images'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .toList()
          ..sort(
            (a, b) =>
                (a['sort_order'] as int).compareTo(b['sort_order'] as int),
          );
    return EditableListing(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      categoryId: json['category_id'] as String,
      isNew: json['condition'] == 'new',
      status: statusFromJson(json['status'] as String),
      photos: images.map((image) {
        final path = image['storage_path'] as String;
        return ListingPhotoRef(path: path, url: photoUrl(path));
      }).toList(),
      variants: (json['product_variants'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) {
            final options = row['options'] as Map<String, dynamic>;
            return ListingVariant(
              colour: options['colour'] as String?,
              size: options['size'] as String?,
              price: (row['price'] as num).toDouble(),
              compareAtPrice: (row['compare_at_price'] as num?)?.toDouble(),
              stock: row['stock'] as int,
            );
          })
          .toList(),
    );
  }

  static Map<String, dynamic> inputToParams(ListingInput input) => {
    'p_product_id': input.id,
    'p_title': input.title,
    'p_description': input.description,
    'p_category_id': input.categoryId,
    'p_condition': input.isNew ? 'new' : 'used',
    'p_image_paths': input.photoPaths,
    'p_variants': [
      for (final variant in input.variants)
        {
          'options': {
            if (variant.colour != null) 'colour': variant.colour,
            if (variant.size != null) 'size': variant.size,
          },
          'price': variant.price,
          'compare_at_price': variant.compareAtPrice,
          'stock': variant.stock,
        },
    ],
  };
}
