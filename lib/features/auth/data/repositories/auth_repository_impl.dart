import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._dataSource);

  final AuthRemoteDataSource _dataSource;

  @override
  bool get isSignedIn => _dataSource.hasSession;

  @override
  Stream<bool> get signedInChanges => _dataSource.sessionChanges;

  @override
  Future<void> signOut() => _dataSource.signOut();
}

/// Used only in debug builds without Supabase settings, so the app can still
/// be opened and browsed as a guest during development.
class GuestAuthRepository implements AuthRepository {
  const GuestAuthRepository();

  @override
  bool get isSignedIn => false;

  @override
  Stream<bool> get signedInChanges => const Stream.empty();

  @override
  Future<void> signOut() async {}
}
