import 'dart:typed_data';

import '../entities/listing.dart';

abstract interface class ListingRepository {
  Future<ListingPage> getMyListings(
    ListingTab tab, {
    ListingCursor? cursor,
    int limit = 20,
  });

  /// Null when the listing doesn't exist or isn't this seller's.
  Future<EditableListing?> getListing(String id);

  /// Uploads one photo into the shop's folder and returns its path.
  /// [jpegBytes] must come from `preparePhotoForUpload`.
  Future<String> uploadPhoto(String shopId, Uint8List jpegBytes);

  /// Saves the listing and returns its ID. On a live listing, the server sends
  /// changed content back to review.
  Future<String> save(ListingInput input);

  Future<void> submitForReview(String id);

  Future<void> setPaused(String id, {required bool paused});

  /// Hides the listing for good and removes its photos.
  Future<void> delete(String id);

  /// A leftover file is harmless, so failures here are ignored.
  Future<void> removePhotos(List<String> paths);
}
