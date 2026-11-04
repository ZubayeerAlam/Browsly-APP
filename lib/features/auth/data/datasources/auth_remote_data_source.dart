import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._client);

  final SupabaseClient _client;

  bool get hasSession => _client.auth.currentSession != null;

  Stream<bool> get sessionChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session != null);

  Future<void> signOut() => _client.auth.signOut();
}
