import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/repositories/auth_repository.dart';

/// Holds the signed-in state. GoRouter listens to it to redirect screens.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository) : _isSignedIn = _repository.isSignedIn {
    _subscription = _repository.signedInChanges.listen(_onChanged);
  }

  final AuthRepository _repository;
  late final StreamSubscription<bool> _subscription;
  bool _isSignedIn;

  bool get isSignedIn => _isSignedIn;

  void _onChanged(bool isSignedIn) {
    if (isSignedIn == _isSignedIn) return;
    _isSignedIn = isSignedIn;
    notifyListeners();
  }

  Future<void> signOut() => _repository.signOut();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
