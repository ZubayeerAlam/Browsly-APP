import 'dart:typed_data';

/// What the seller sees. Whether the AI or an admin is reviewing a listing is
/// not their concern, so both are simply "In review".
enum ListingStatus {
  draft('Draft'),
  inReview('In review'),
  active('Active'),
  rejected('Rejected'),
  paused('Paused'),
  removed('Removed');

  const ListingStatus(this.label);

  final String label;

  /// Only these can be sent to review. Others re-enter it when edited.
  bool get isSubmittable => this == draft || this == rejected;
}

/// The tabs on My Posts.
enum ListingTab {
  all('All'),
  active('Active'),
  inReview('In review'),
  draft('Draft'),
  rejected('Rejected');

  const ListingTab(this.label);

  final String label;
}

class ListingSummary {
  const ListingSummary({
    required this.id,
    required this.title,
    required this.status,
    this.imageUrl,
    this.price,
    this.totalStock = 0,
    this.rejectionReason,
  });

  final String id;
  final String title;
  final ListingStatus status;
  final String? imageUrl;
  final double? price;
  final int totalStock;
  final String? rejectionReason;
}

class ListingCursor {
  const ListingCursor({required this.key, required this.id});

  final String key;
  final String id;
}

class ListingPage {
  const ListingPage({required this.items, this.next});

  final List<ListingSummary> items;
  final ListingCursor? next;
}

class ListingVariant {
  const ListingVariant({
    required this.price,
    required this.stock,
    this.colour,
    this.size,
    this.compareAtPrice,
  });

  final String? colour;
  final String? size;
  final double price;
  final double? compareAtPrice;
  final int stock;
}

class ListingPhotoRef {
  const ListingPhotoRef({required this.path, required this.url});

  final String path;
  final String url;
}

/// A listing as loaded into the Post form.
class EditableListing {
  const EditableListing({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.isNew,
    required this.status,
    required this.photos,
    required this.variants,
  });

  final String id;
  final String title;
  final String description;
  final String categoryId;
  final bool isNew;
  final ListingStatus status;
  final List<ListingPhotoRef> photos;
  final List<ListingVariant> variants;
}

class ListingInput {
  const ListingInput({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.isNew,
    required this.photoPaths,
    required this.variants,
  });

  final String? id;
  final String title;
  final String description;
  final String categoryId;
  final bool isNew;
  final List<String> photoPaths;
  final List<ListingVariant> variants;
}

/// A photo in the form. New ones hold prepared bytes until they are uploaded.
class FormPhoto {
  FormPhoto.stored(ListingPhotoRef ref)
    : path = ref.path,
      url = ref.url,
      bytes = null;

  FormPhoto.prepared(Uint8List this.bytes) : path = null, url = null;

  String? path;
  final String? url;
  final Uint8List? bytes;
}
