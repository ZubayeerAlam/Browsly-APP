import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/repositories/wishlist_repository.dart';

/// The signed-in user's saved product IDs, so every heart in the app agrees.
class WishlistProvider extends ChangeNotifier {
  WishlistProvider(this._repository, this._auth) {
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final WishlistRepository _repository;
  final AuthProvider _auth;
  Set<String> _savedIds = {};
  String? _loadedFor;

  /// Changes still on their way to the server, and whether each one saves.
  final Map<String, bool> _pending = {};

  bool isSaved(String productId) =>
      _pending[productId] ?? _savedIds.contains(productId);

  void _onAuthChanged() {
    final userId = _auth.user?.id;
    if (userId == _loadedFor) return;
    _loadedFor = userId;
    _savedIds = {};
    _pending.clear();
    notifyListeners();
    if (userId != null) load();
  }

  /// A failed load leaves hearts empty. Saving still works, so it isn't shown
  /// as an error, and the next load corrects them.
  Future<void> load() async {
    final userId = _auth.user?.id;
    if (userId == null) return;
    try {
      final ids = await _repository.getSavedIds();
      if (_auth.user?.id != userId) return;
      _savedIds = ids;
      notifyListeners();
    } on AppFailure {
      // Handled by the comment above.
    }
  }

  /// Updates the heart at once, and puts it back if the server refuses.
  /// Returns false only if the change failed.
  Future<bool> toggle(String productId) async {
    final userId = _auth.user?.id;
    if (userId == null || _pending.containsKey(productId)) return true;
    final shouldSave = !isSaved(productId);
    _pending[productId] = shouldSave;
    notifyListeners();
    var succeeded = true;
    try {
      if (shouldSave) {
        await _repository.add(productId);
      } else {
        await _repository.remove(productId);
      }
    } on AppFailure {
      succeeded = false;
    }
    // Ignore the result if the user signed out while it was on its way.
    if (_auth.user?.id != userId) return true;
    _pending.remove(productId);
    if (succeeded) {
      _savedIds = shouldSave
          ? {..._savedIds, productId}
          : ({..._savedIds}..remove(productId));
    }
    notifyListeners();
    return succeeded;
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
