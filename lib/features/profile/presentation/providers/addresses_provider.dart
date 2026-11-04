import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/address.dart';
import '../../domain/repositories/address_repository.dart';

/// Holds the address list and its actions.
class AddressesProvider extends ChangeNotifier {
  AddressesProvider(this._repository);

  final AddressRepository _repository;
  ViewState<List<Address>> _state = const ViewState.initial();
  AppFailure? _actionFailure;
  bool _isDisposed = false;

  ViewState<List<Address>> get state => _state;
  AppFailure? get actionFailure => _actionFailure;

  Future<void> load() async {
    _state = ViewState.loading(data: _state.data);
    notifyListeners();
    try {
      final addresses = await _repository.getAddresses();
      _state = addresses.isEmpty
          ? const ViewState.empty()
          : ViewState.success(addresses);
    } on AppFailure catch (failure) {
      _state = ViewState.error(failure, data: _state.data);
    }
    notifyListeners();
  }

  Future<void> setDefault(String id) {
    return _act(() => _repository.setDefaultAddress(id));
  }

  Future<void> delete(String id) {
    return _act(() => _repository.deleteAddress(id));
  }

  Future<void> _act(Future<void> Function() action) async {
    _actionFailure = null;
    notifyListeners();
    try {
      await action();
    } on AppFailure catch (failure) {
      _actionFailure = failure;
    }
    await load();
  }

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
