import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// Runs one sign-in screen's actions and exposes their busy and error state.
class AuthFormProvider extends ChangeNotifier {
  AuthFormProvider(this._repository);

  final AuthRepository _repository;
  bool _isBusy = false;
  bool _isDisposed = false;
  AppFailure? _failure;

  bool get isBusy => _isBusy;
  AppFailure? get failure => _failure;

  Future<bool> signIn(String email, String password) {
    return _run(
      () => _repository.signInWithEmail(email: email, password: password),
    );
  }

  /// Returns null on failure, otherwise whether email confirmation is needed.
  Future<bool?> signUp(String name, String email, String password) async {
    bool? needsConfirmation;
    await _run(() async {
      needsConfirmation = await _repository.signUpWithEmail(
        name: name,
        email: email,
        password: password,
      );
    });
    return needsConfirmation;
  }

  Future<bool> sendPasswordReset(String email) {
    return _run(() => _repository.sendPasswordReset(email));
  }

  Future<bool> updatePassword(String password) {
    return _run(() => _repository.updatePassword(password));
  }

  Future<bool> signInWithGoogle() => _run(_repository.signInWithGoogle);

  Future<bool> sendPhoneCode(String phone, {required bool linkToAccount}) {
    return _run(
      () => linkToAccount
          ? _repository.sendPhoneLinkCode(phone)
          : _repository.sendPhoneSignInCode(phone),
    );
  }

  Future<bool> verifyPhoneCode(
    String phone,
    String code, {
    required bool linkToAccount,
  }) {
    return _run(
      () => linkToAccount
          ? _repository.verifyPhoneLinkCode(phone: phone, code: code)
          : _repository.verifyPhoneSignInCode(phone: phone, code: code),
    );
  }

  Future<bool> signOut() => _run(_repository.signOut);

  Future<bool> deleteAccount() => _run(_repository.deleteAccount);

  Future<bool> _run(Future<void> Function() action) async {
    if (_isBusy) return false;
    _isBusy = true;
    _failure = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AppFailure catch (failure) {
      _failure = failure;
      return false;
    } catch (_) {
      _failure = const UnknownFailure();
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  // A successful sign-in can close the screen before the action finishes.
  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
