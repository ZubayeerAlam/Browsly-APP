import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/buying_errors.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

class OrderDetailProvider extends ChangeNotifier {
  OrderDetailProvider(this._repository, this.orderId);

  final OrderRepository _repository;
  final String orderId;

  ViewState<OrderDetail> _state = const ViewState.initial();
  String? _cancellingGroupId;
  String? _actionFailure;
  bool _isDisposed = false;

  ViewState<OrderDetail> get state => _state;
  String? get cancellingGroupId => _cancellingGroupId;
  String? get actionFailure => _actionFailure;

  Future<void> load() async {
    _state = ViewState.loading(data: _state.data);
    _notify();
    try {
      final order = await _repository.getOrder(orderId);
      _state = order == null
          ? const ViewState.empty()
          : ViewState.success(order);
    } on AppFailure catch (failure) {
      _state = ViewState.error(failure, data: _state.data);
    }
    _notify();
  }

  Future<void> cancel(OrderGroup group) async {
    if (_cancellingGroupId != null) return;
    _cancellingGroupId = group.id;
    _actionFailure = null;
    _notify();
    try {
      await _repository.cancelGroup(group.id);
    } on AppFailure catch (failure) {
      _actionFailure = buyingFailureMessage(failure);
    }
    // Reload either way. A refusal usually means the status has moved on.
    await load();
    _cancellingGroupId = null;
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
