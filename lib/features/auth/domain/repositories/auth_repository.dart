import '../entities/auth_user.dart';

/// Sign-in operations. Every method reports problems as an `AppFailure`.
abstract interface class AuthRepository {
  AuthUser? get currentUser;

  /// Emits the current user whenever it changes, or null after signing out.
  Stream<AuthUser?> get userChanges;

  /// Emits when the user returns from a password reset email.
  Stream<void> get passwordRecoveryRequests;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  /// Returns true when the user must confirm their email before signing in.
  Future<bool> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset(String email);

  Future<void> updatePassword(String password);

  /// Opens Google sign-in. The result arrives through [userChanges].
  Future<void> signInWithGoogle();

  Future<void> sendPhoneSignInCode(String phone);

  Future<void> verifyPhoneSignInCode({
    required String phone,
    required String code,
  });

  /// Sends a code to add a phone to the signed-in account.
  Future<void> sendPhoneLinkCode(String phone);

  Future<void> verifyPhoneLinkCode({
    required String phone,
    required String code,
  });

  Future<void> signOut();

  /// Permanently deletes the signed-in account, then signs out.
  Future<void> deleteAccount();
}
