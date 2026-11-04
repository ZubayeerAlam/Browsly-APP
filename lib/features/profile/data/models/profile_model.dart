import '../../domain/entities/profile.dart';

abstract final class ProfileModel {
  static Profile fromJson(
    Map<String, dynamic> json, {
    required String? avatarUrl,
  }) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      avatarUrl: avatarUrl,
    );
  }
}
