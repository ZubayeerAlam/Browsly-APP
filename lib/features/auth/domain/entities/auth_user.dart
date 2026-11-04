/// The signed-in account, as far as sign-in is concerned.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.isPhoneVerified,
    this.email,
    this.phone,
  });

  final String id;
  final String? email;
  final String? phone;
  final bool isPhoneVerified;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.phone == phone &&
      other.isPhoneVerified == isPhoneVerified;

  @override
  int get hashCode => Object.hash(id, email, phone, isPhoneVerified);
}
