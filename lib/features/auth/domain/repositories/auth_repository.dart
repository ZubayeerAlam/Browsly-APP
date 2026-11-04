/// What the app needs to know about sign-in. Step 1 adds the sign-in methods.
abstract interface class AuthRepository {
  bool get isSignedIn;

  /// Emits the signed-in state whenever it changes.
  Stream<bool> get signedInChanges;

  Future<void> signOut();
}
