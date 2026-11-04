import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/photo_preparer.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// Holds the signed-in user's profile, following sign-in and sign-out.
class ProfileProvider extends ChangeNotifier {
  ProfileProvider(
    this._repository,
    this._auth, {
    this._preparePhoto = preparePhotoForUpload,
  }) {
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final ProfileRepository _repository;
  final AuthProvider _auth;
  final PhotoPreparer _preparePhoto;
  ViewState<Profile> _state = const ViewState.initial();
  AuthUser? _loadedFor;
  bool _isSaving = false;
  AppFailure? _saveFailure;

  ViewState<Profile> get state => _state;
  Profile? get profile => _state.data;
  bool get isSaving => _isSaving;
  AppFailure? get saveFailure => _saveFailure;

  void _onAuthChanged() {
    final user = _auth.user;
    if (user == _loadedFor) return;
    _loadedFor = user;
    if (user == null) {
      _state = const ViewState.initial();
      notifyListeners();
    } else {
      load();
    }
  }

  Future<void> load() async {
    final user = _auth.user;
    if (user == null) return;
    _state = ViewState.loading(data: _state.data);
    notifyListeners();
    try {
      final profile = await _repository.getProfile(user.id);
      // Ignore the result if the user changed while it was loading.
      if (_auth.user?.id != user.id) return;
      _state = ViewState.success(profile);
    } on AppFailure catch (failure) {
      if (_auth.user?.id != user.id) return;
      _state = ViewState.error(failure, data: _state.data);
    }
    notifyListeners();
  }

  Future<bool> updateName(String fullName) {
    return _save((userId) => _repository.updateName(userId, fullName));
  }

  /// Only the prepared photo is uploaded, so if preparing it fails, nothing is.
  Future<bool> updateAvatar(Uint8List original) {
    return _save((userId) async {
      await _repository.updateAvatar(userId, await _preparePhoto(original));
    });
  }

  Future<bool> _save(Future<void> Function(String userId) action) async {
    final user = _auth.user;
    if (user == null || _isSaving) return false;
    _isSaving = true;
    _saveFailure = null;
    notifyListeners();
    try {
      await action(user.id);
      await load();
      return true;
    } on AppFailure catch (failure) {
      _saveFailure = failure;
      return false;
    } catch (_) {
      _saveFailure = const UnknownFailure();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
