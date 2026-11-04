import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._client);

  /// Must match the app's deep link settings and Supabase's redirect list.
  static const redirectUrl = 'com.browsly.app://login-callback';

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signInWithPassword(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(String name, String email, String password) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
      emailRedirectTo: redirectUrl,
    );
  }

  Future<void> resetPasswordForEmail(String email) {
    return _client.auth.resetPasswordForEmail(email, redirectTo: redirectUrl);
  }

  Future<void> updatePassword(String password) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectUrl,
    );
  }

  Future<void> sendPhoneOtp(String phone) {
    return _client.auth.signInWithOtp(phone: phone);
  }

  Future<void> verifyPhoneOtp(String phone, String code) {
    return _client.auth.verifyOTP(phone: phone, token: code, type: OtpType.sms);
  }

  Future<void> sendPhoneChangeOtp(String phone) {
    return _client.auth.updateUser(UserAttributes(phone: phone));
  }

  Future<void> verifyPhoneChangeOtp(String phone, String code) {
    return _client.auth.verifyOTP(
      phone: phone,
      token: code,
      type: OtpType.phoneChange,
    );
  }

  Future<void> signOut({bool localOnly = false}) {
    return _client.auth.signOut(
      scope: localOnly ? SignOutScope.local : SignOutScope.global,
    );
  }

  Future<void> deleteAccount() {
    return _client.functions.invoke('delete-account');
  }
}
