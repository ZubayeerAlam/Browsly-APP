import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sales_repository.dart';

/// The seller's orders on the Sales tab, one status at a time.
class SalesProvider extends ChangeNotifier {
  SalesProvider(this._repository);

  final SalesRepository _repository;

  SaleTab _tab = SaleTab.pending;
  ViewState<List<SaleSummary>> _state = const ViewState.initial();
  PageCursor? _next;
  bool _isLoadingMore = false;
  bool _isDisposed = false;

  /// Only the newest request may change the list.
  int _request = 0;

  SaleTab get tab => _tab;
  ViewState<List<SaleSummary>> get state => _state;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> setTab(SaleTab tab) {
    if (tab == _tab) return Future.value();
    _tab = tab;
    return load();
  }

  Future<void> load({bool keepList = false}) async {
    final request = ++_request;
    _next = null;
    _isLoadingMore = false;
    final previous = keepList ? _state.data : null;
    _state = ViewState.loading(data: previous);
    _notify();
    try {
      final page = await _repository.getSales(_tab);
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
      final page = await _repository.getSales(_tab, cursor: cursor);
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
