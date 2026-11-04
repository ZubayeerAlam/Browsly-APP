import 'dart:typed_data';

import '../entities/profile.dart';

abstract interface class ProfileRepository {
  Future<Profile> getProfile(String userId);

  Future<void> updateName(String userId, String fullName);

  /// Replaces the avatar photo. [jpegBytes] must come from `preparePhotoForUpload`.
  Future<void> updateAvatar(String userId, Uint8List jpegBytes);
}
