import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/buying_errors.dart';
import '../../../../core/state/view_state.dart';
import '../../../notifications/domain/entities/app_notification.dart';
import '../../../orders/domain/entities/order.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sales_repository.dart';

class SaleDetailProvider extends ChangeNotifier {
  SaleDetailProvider(
    this._repository,
    this.saleId, {
    Stream<AppNotification>? updates,
  }) {
    _updates = updates?.listen((notification) {
      if (notification.groupId == saleId) load();
    });
  }

  /// Reloads when a notification says this may have changed.
  StreamSubscription<AppNotification>? _updates;

  final SalesRepository _repository;
  final String saleId;

  ViewState<SaleDetail> _state = const ViewState.initial();
  bool _isUpdating = false;
  String? _actionFailure;
  bool _isDisposed = false;

  ViewState<SaleDetail> get state => _state;
  bool get isUpdating => _isUpdating;
  String? get actionFailure => _actionFailure;

  Future<void> load() async {
    _state = ViewState.loading(data: _state.data);
    _notify();
    try {
      final sale = await _repository.getSale(saleId);
      _state = sale == null ? const ViewState.empty() : ViewState.success(sale);
    } on AppFailure catch (failure) {
      _state = ViewState.error(failure, data: _state.data);
    }
    _notify();
  }

  Future<void> setStatus(OrderStatus status, {String? note}) {
    return _act(() => _repository.setStatus(saleId, status, note: note));
  }

  Future<void> cancel({String? reason}) {
    return _act(() => _repository.cancel(saleId, reason: reason));
  }

  /// Reloads either way, because a refusal usually means the status has moved.
  Future<void> _act(Future<void> Function() action) async {
    if (_isUpdating) return;
    _isUpdating = true;
    _actionFailure = null;
    _notify();
    try {
      await action();
    } on AppFailure catch (failure) {
      _actionFailure = buyingFailureMessage(failure);
    }
    await load();
    _isUpdating = false;
    _notify();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _updates?.cancel();
    super.dispose();
  }
}
