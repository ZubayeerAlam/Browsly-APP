import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Holds who is signed in. GoRouter listens to it to redirect screens.
class AuthProvider extends ChangeNotifier {
  AuthProvider(AuthRepository repository) : _user = repository.currentUser {
    _subscriptions = [
      repository.userChanges.listen(_onUserChanged),
      repository.passwordRecoveryRequests.listen((_) {
        _isRecoveringPassword = true;
        notifyListeners();
      }),
    ];
  }

  late final List<StreamSubscription<void>> _subscriptions;
  AuthUser? _user;
  bool _isRecoveringPassword = false;

  AuthUser? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isPhoneVerified => _user?.isPhoneVerified ?? false;

  /// True after a reset link opens the app, until a new password is saved.
  bool get isRecoveringPassword => _isRecoveringPassword;

  void finishPasswordRecovery() {
    if (!_isRecoveringPassword) return;
    _isRecoveringPassword = false;
    notifyListeners();
  }

  void _onUserChanged(AuthUser? user) {
    if (user == _user) return;
    _user = user;
    if (user == null) _isRecoveringPassword = false;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
