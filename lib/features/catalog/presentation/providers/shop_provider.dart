import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/shop.dart';
import '../../domain/repositories/catalog_repository.dart';

class ShopProvider extends ChangeNotifier {
  ShopProvider(this._repository, this.shopId);

  final CatalogRepository _repository;
  final String shopId;

  ViewState<Shop> _state = const ViewState.initial();
  bool _isDisposed = false;

  ViewState<Shop> get state => _state;

  Future<void> load() async {
    _state = ViewState.loading(data: _state.data);
    _notify();
    try {
      final shop = await _repository.getShop(shopId);
      _state = shop == null ? const ViewState.empty() : ViewState.success(shop);
    } on AppFailure catch (failure) {
      _state = ViewState.error(failure, data: _state.data);
    }
    _notify();
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
