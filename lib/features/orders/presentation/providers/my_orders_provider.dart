import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

class MyOrdersProvider extends ChangeNotifier {
  MyOrdersProvider(this._repository);

  final OrderRepository _repository;

  ViewState<List<OrderSummary>> _state = const ViewState.initial();
  OrderCursor? _next;
  bool _isLoadingMore = false;
  bool _isDisposed = false;

  /// Only the newest request may change the list.
  int _request = 0;

  ViewState<List<OrderSummary>> get state => _state;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> load() async {
    final request = ++_request;
    _next = null;
    _isLoadingMore = false;
    final previous = _state.data;
    _state = ViewState.loading(data: previous);
    _notify();
    try {
      final page = await _repository.getMyOrders();
      if (request != _request) return;
      _next = page.next;
      _state = page.items.isEmpty
          ? const ViewState.empty()
          : ViewState.success(page.items);
    } on AppFailure catch (failure) {
      if (request != _request) return;
      _state = ViewState.error(failure, data: previous);
    }
    _notify();
  }

  Future<void> loadMore() async {
    final cursor = _next;
    final items = _state.data;
    if (cursor == null || items == null || _isLoadingMore) return;
    final request = _request;
    _isLoadingMore = true;
    _notify();
    try {
      final page = await _repository.getMyOrders(cursor: cursor);
      if (request != _request) return;
      _next = page.next;
      _state = ViewState.success([...items, ...page.items]);
    } on AppFailure {
      // The row stays where it is, and scrolling again retries.
      if (request != _request) return;
    }
    _isLoadingMore = false;
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
