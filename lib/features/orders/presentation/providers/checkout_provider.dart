import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/buying_errors.dart';
import '../../../../core/state/view_state.dart';
import '../../../cart/domain/entities/cart.dart';
import '../../../cart/domain/repositories/cart_repository.dart';
import '../../../profile/domain/entities/address.dart';
import '../../../profile/domain/repositories/address_repository.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

/// Checks out the cart, or one item when [buyNowVariantId] is given.
class CheckoutProvider extends ChangeNotifier {
  CheckoutProvider(
    this._carts,
    this._orders,
    this._addresses, {
    this.buyNowVariantId,
  });

  final CartRepository _carts;
  final OrderRepository _orders;
  final AddressRepository _addresses;
  final String? buyNowVariantId;

  ViewState<Cart> _state = const ViewState.initial();
  List<Address> _addressList = const [];
  Address? _selected;
  bool _isPlacing = false;
  String? _placeFailure;
  bool _isDisposed = false;

  /// Stays the same when a request may have reached the server without a reply,
  /// so trying again can't create a second order.
  String? _idempotencyKey;

  ViewState<Cart> get state => _state;
  List<Address> get addresses => _addressList;
  Address? get selectedAddress => _selected;
  bool get isPlacing => _isPlacing;
  String? get placeFailure => _placeFailure;

  bool get canPlace {
    final cart = _state.data;
    return cart != null && cart.canCheckout && _selected != null && !_isPlacing;
  }

  Future<void> load() async {
    _state = ViewState.loading(data: _state.data);
    _notify();
    try {
      final results = await Future.wait([
        _fetchCart(),
        _addresses.getAddresses(),
      ]);
      final cart = results[0] as Cart;
      _setAddresses(results[1] as List<Address>);
      _state = cart.isEmpty ? const ViewState.empty() : ViewState.success(cart);
    } on AppFailure catch (failure) {
      _state = ViewState.error(failure, data: _state.data);
    }
    _notify();
  }

  Future<Cart> _fetchCart() {
    final variantId = buyNowVariantId;
    return variantId == null ? _carts.getCart() : _carts.getBuyNow(variantId);
  }

  void _setAddresses(List<Address> addresses, {bool selectNew = false}) {
    final known = _addressList.map((address) => address.id).toSet();
    _addressList = addresses;
    final added = addresses.where((address) => !known.contains(address.id));
    if (selectNew && added.isNotEmpty) {
      _selected = added.first;
      return;
    }
    final selectedId = _selected?.id;
    _selected =
        addresses.where((address) => address.id == selectedId).firstOrNull ??
        addresses.where((address) => address.isDefault).firstOrNull ??
        addresses.firstOrNull;
  }

  void selectAddress(Address address) {
    _selected = address;
    _notify();
  }

  /// After adding an address, which then becomes the chosen one.
  Future<void> reloadAddresses() async {
    try {
      _setAddresses(await _addresses.getAddresses(), selectNew: true);
      _notify();
    } on AppFailure catch (failure) {
      _placeFailure = failure.message;
      _notify();
    }
  }

  /// Returns the order, or null if it was refused.
  Future<PlacedOrder?> placeOrder() async {
    final cart = _state.data;
    final address = _selected;
    if (cart == null || address == null || !canPlace) return null;
    _isPlacing = true;
    _placeFailure = null;
    _notify();
    final key = _idempotencyKey ??= _newKey();
    try {
      return await _orders.placeOrder(
        addressId: address.id,
        idempotencyKey: key,
        expectedTotal: cart.grandTotal,
        buyNowVariantId: buyNowVariantId,
      );
    } on ServerFailure catch (failure) {
      // A clear refusal: nothing was created. Show the buyer what changed.
      _idempotencyKey = null;
      _placeFailure = buyingFailureMessage(failure);
      await load();
      return null;
    } on AppFailure catch (failure) {
      _placeFailure = failure.message;
      return null;
    } finally {
      _isPlacing = false;
      _notify();
    }
  }

  static String _newKey() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
