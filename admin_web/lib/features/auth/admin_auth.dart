import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_failure.dart';
import '../../core/errors/error_mapper.dart';

abstract interface class AdminAuthRepository {
  bool get isSignedIn;
  Stream<bool> get signedInChanges;

  Future<void> signIn(String email, String password);
  Future<void> signOut();

  /// The server decides. The panel never decides this for itself.
  Future<bool> isAdmin();
}

class AdminAuthRepositoryImpl implements AdminAuthRepository {
  AdminAuthRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Stream<bool> get signedInChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session != null);

  @override
  Future<void> signIn(String email, String password) {
    return guardFailures(
      () => _client.auth.signInWithPassword(email: email, password: password),
    );
  }

  @override
  Future<void> signOut() => guardFailures(_client.auth.signOut);

  @override
  Future<bool> isAdmin() {
    return guardFailures(() => _client.rpc<bool>('is_admin'));
  }
}

enum AdminAccess { checking, signedOut, granted }

/// Who may see the panel. Someone signed in who isn't an admin is signed straight
/// back out, with a message saying why.
class AdminAuthProvider extends ChangeNotifier {
  AdminAuthProvider(this._repository) {
    _changes = _repository.signedInChanges.listen((signedIn) {
      if (!signedIn) _setAccess(AdminAccess.signedOut);
    });
    unawaited(_check());
  }

  final AdminAuthRepository _repository;
  late final StreamSubscription<bool> _changes;

  AdminAccess _access = AdminAccess.checking;
  bool _isBusy = false;
  String? _failure;

  AdminAccess get access => _access;
  bool get isBusy => _isBusy;
  String? get failure => _failure;

  void _setAccess(AdminAccess access) {
    _access = access;
    notifyListeners();
  }

  Future<void> _check() async {
    if (!_repository.isSignedIn) {
      _setAccess(AdminAccess.signedOut);
      return;
    }
    await _confirmAdmin();
  }

  Future<void> _confirmAdmin() async {
    try {
      if (await _repository.isAdmin()) {
        _setAccess(AdminAccess.granted);
        return;
      }
      _failure = 'This account is not an admin.';
      await _repository.signOut();
    } on AppFailure catch (failure) {
      _failure = failure.message;
    }
    _setAccess(AdminAccess.signedOut);
  }

  Future<void> signIn(String email, String password) async {
    if (_isBusy) return;
    _isBusy = true;
    _failure = null;
    notifyListeners();
    try {
      await _repository.signIn(email.trim(), password);
      await _confirmAdmin();
    } on AppFailure catch (failure) {
      _failure = failure.message;
    }
    _isBusy = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _repository.signOut();
    } on AppFailure {
      // The session ends on this browser either way.
    }
    _setAccess(AdminAccess.signedOut);
  }

  @override
  void dispose() {
    _changes.cancel();
    super.dispose();
  }
}
