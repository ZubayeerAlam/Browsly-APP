import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._dataSource);

  final AuthRemoteDataSource _dataSource;

  static AuthUser? _toEntity(supabase.User? user) {
    if (user == null) return null;
    return AuthUser(
      id: user.id,
      // Supabase sends an empty string, not null, for a missing email or phone.
      email: _nullIfEmpty(user.email),
      phone: _nullIfEmpty(user.phone),
      isPhoneVerified: user.phoneConfirmedAt != null,
    );
  }

  static String? _nullIfEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;

  @override
  AuthUser? get currentUser => _toEntity(_dataSource.currentUser);

  @override
  Stream<AuthUser?> get userChanges => _dataSource.authStateChanges.map(
    (state) => _toEntity(state.session?.user),
  );

  @override
  Stream<void> get passwordRecoveryRequests => _dataSource.authStateChanges
      .where(
        (state) => state.event == supabase.AuthChangeEvent.passwordRecovery,
      )
      .map((_) {});

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    return guardFailures(() => _dataSource.signInWithPassword(email, password));
  }

  @override
  Future<bool> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) {
    return guardFailures(() async {
      final response = await _dataSource.signUp(name, email, password);
      return response.session == null;
    });
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return guardFailures(() => _dataSource.resetPasswordForEmail(email));
  }

  @override
  Future<void> updatePassword(String password) {
    return guardFailures(() => _dataSource.updatePassword(password));
  }

  @override
  Future<void> signInWithGoogle() {
    return guardFailures(_dataSource.signInWithGoogle);
  }

  @override
  Future<void> sendPhoneSignInCode(String phone) {
    return guardFailures(() => _dataSource.sendPhoneOtp(phone));
  }

  @override
  Future<void> verifyPhoneSignInCode({
    required String phone,
    required String code,
  }) {
    return guardFailures(() => _dataSource.verifyPhoneOtp(phone, code));
  }

  @override
  Future<void> sendPhoneLinkCode(String phone) {
    return guardFailures(() => _dataSource.sendPhoneChangeOtp(phone));
  }

  @override
  Future<void> verifyPhoneLinkCode({
    required String phone,
    required String code,
  }) {
    return guardFailures(() => _dataSource.verifyPhoneChangeOtp(phone, code));
  }

  @override
  Future<void> signOut() {
    return guardFailures(_dataSource.signOut);
  }

  @override
  Future<void> deleteAccount() {
    return guardFailures(() async {
      await _dataSource.deleteAccount();
      // The account is already gone, so only the local session is left to clear.
      await _dataSource.signOut(localOnly: true);
    });
  }
}
