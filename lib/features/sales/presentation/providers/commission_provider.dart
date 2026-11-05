import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sales_repository.dart';

class CommissionData {
  const CommissionData({required this.summary, required this.entries});

  final CommissionSummary summary;
  final List<CommissionEntry> entries;
}

class CommissionProvider extends ChangeNotifier {
  CommissionProvider(this._repository);

  final SalesRepository _repository;

  ViewState<CommissionData> _state = const ViewState.initial();
  PageCursor? _next;
  bool _isLoadingMore = false;
  bool _isDisposed = false;

  ViewState<CommissionData> get state => _state;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> load() async {
    final previous = _state.data;
    _next = null;
    _isLoadingMore = false;
    _state = ViewState.loading(data: previous);
    _notify();
    try {
      final results = await Future.wait([
        _repository.getCommissionSummary(),
        _repository.getCommissionEntries(),
      ]);
      final page = results[1] as CommissionPage;
      _next = page.next;
      _state = ViewState.success(
        CommissionData(
          summary: results[0] as CommissionSummary,
          entries: page.items,
        ),
      );
    } on AppFailure catch (failure) {
      _state = ViewState.error(failure, data: previous);
    }
    _notify();
  }

  Future<void> loadMore() async {
    final cursor = _next;
    final data = _state.data;
    if (cursor == null || data == null || _isLoadingMore) return;
    _isLoadingMore = true;
    _notify();
    try {
      final page = await _repository.getCommissionEntries(cursor: cursor);
      _next = page.next;
      _state = ViewState.success(
        CommissionData(
          summary: data.summary,
          entries: [...data.entries, ...page.items],
        ),
      );
    } on AppFailure {
      // The row stays where it is, and scrolling again retries.
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
