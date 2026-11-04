import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRemoteDataSource {
  const ProfileRemoteDataSource(this._client);

  static const _bucket = 'avatars';

  final SupabaseClient _client;

  Future<Map<String, dynamic>> fetchProfile(String userId) {
    return _client.from('profiles').select().eq('id', userId).single();
  }

  String avatarUrl(String path) {
    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  Future<void> updateName(String userId, String fullName) {
    return _client
        .from('profiles')
        .update({'full_name': fullName})
        .eq('id', userId);
  }

  Future<void> uploadAvatar(String path, Uint8List bytes, String contentType) {
    return _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
  }

  Future<void> setAvatarPath(String userId, String path) {
    return _client
        .from('profiles')
        .update({'avatar_path': path})
        .eq('id', userId);
  }

  Future<void> removeAvatarFile(String path) {
    return _client.storage.from(_bucket).remove([path]);
  }
}
