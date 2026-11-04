import 'dart:typed_data';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';
import '../models/profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._dataSource);

  final ProfileRemoteDataSource _dataSource;

  @override
  Future<Profile> getProfile(String userId) {
    return guardFailures(() async {
      final json = await _dataSource.fetchProfile(userId);
      final path = json['avatar_path'] as String?;
      return ProfileModel.fromJson(
        json,
        avatarUrl: path == null ? null : _dataSource.avatarUrl(path),
      );
    });
  }

  @override
  Future<void> updateName(String userId, String fullName) {
    return guardFailures(() => _dataSource.updateName(userId, fullName));
  }

  @override
  Future<void> updateAvatar(String userId, Uint8List jpegBytes) {
    return guardFailures(() async {
      final current = await _dataSource.fetchProfile(userId);
      final oldPath = current['avatar_path'] as String?;
      // A new name each time means image caches never show the old photo.
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$userId/avatar-$timestamp.jpg';

      await _dataSource.uploadAvatar(path, jpegBytes, 'image/jpeg');
      await _dataSource.setAvatarPath(userId, path);

      if (oldPath != null) {
        // The new photo is already saved, so a leftover file is harmless.
        await _dataSource.removeAvatarFile(oldPath).catchError((Object _) {});
      }
    });
  }
}
