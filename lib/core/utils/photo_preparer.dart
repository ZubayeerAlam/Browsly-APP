import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Turns a picked photo into the bytes that are safe to upload.
typedef PhotoPreparer = Future<Uint8List> Function(Uint8List original);

/// Re-encodes a photo as a JPG without its location and camera details.
///
/// Uploaded photos are public, and camera photos can contain the GPS location
/// where they were taken. Pickers do not reliably remove it, so every photo
/// must pass through here. Never upload the original bytes if this fails.
Future<Uint8List> preparePhotoForUpload(
  Uint8List original, {
  int maxSize = 800,
}) {
  return FlutterImageCompress.compressWithList(
    original,
    minWidth: maxSize,
    minHeight: maxSize,
    quality: 80,
    format: CompressFormat.jpeg,
    keepExif: false,
  );
}
