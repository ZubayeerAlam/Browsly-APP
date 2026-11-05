import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/cart.dart';
import '../../domain/repositories/cart_repository.dart';

/// The signed-in user's cart, shared by the badge and the cart screen.
class CartProvider extends ChangeNotifier {
  CartProvider(this._repository, this._auth) {
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final CartRepository _repository;
  final AuthProvider _auth;

  Cart? _cart;
  AppFailure? _loadFailure;
  String? _loadedFor;
  int _pendingAdds = 0;
  final Set<String> _busyVariants = {};

  /// Requests run one at a time, so a slow older reply can't overwrite a newer
  /// cart.
  Future<void> _queue = Future.value();

  /// Null until the first load finishes.
  Cart? get cart => _cart;
  AppFailure? get loadFailure => _loadFailure;

  /// Counts adds still on their way, so the badge changes at once.
  int get itemCount => (_cart?.itemCount ?? 0) + _pendingAdds;
  bool isBusy(String variantId) => _busyVariants.contains(variantId);

  void _onAuthChanged() {
    final userId = _auth.user?.id;
    if (userId == _loadedFor) return;
    _loadedFor = userId;
    _cart = null;
    _loadFailure = null;
    _pendingAdds = 0;
    _busyVariants.clear();
    notifyListeners();
    if (userId != null) unawaited(load());
  }

  Future<void> load() async {
    final failure = await _enqueue(_repository.getCart);
    _loadFailure = failure;
    notifyListeners();
  }

  /// Each of these returns the failure, or null if it worked.
  Future<AppFailure?> addVariant(String variantId) {
    return _add(() => _repository.addVariant(variantId));
  }

  Future<AppFailure?> addProduct(String productId) {
    return _add(() => _repository.addProduct(productId));
  }

  Future<AppFailure?> _add(Future<Cart> Function() action) async {
    final userId = _auth.user?.id;
    _pendingAdds++;
    notifyListeners();
    final failure = await _enqueue(action);
    if (_auth.user?.id == userId) _pendingAdds--;
    notifyListeners();
    return failure;
  }

  Future<AppFailure?> setQuantity(CartLine line, int quantity) async {
    if (!_busyVariants.add(line.variantId)) return null;
    notifyListeners();
    final failure = await _enqueue(
      () => _repository.setQuantity(line.variantId, quantity),
    );
    _busyVariants.remove(line.variantId);
    notifyListeners();
    return failure;
  }

  Future<AppFailure?> remove(CartLine line) => setQuantity(line, 0);

  Future<AppFailure?> _enqueue(Future<Cart> Function() action) {
    final userId = _auth.user?.id;
    final result = _queue.then((_) async {
      if (userId == null || _auth.user?.id != userId) return null;
      try {
        final cart = await action();
        // Ignore the reply if the user signed out while it was on its way.
        if (_auth.user?.id == userId) _cart = cart;
        return null;
      } on AppFailure catch (failure) {
        return failure;
      }
    });
    _queue = result.then((_) {});
    return result;
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
