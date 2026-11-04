class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.phone,
  });

  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? phone;
}
