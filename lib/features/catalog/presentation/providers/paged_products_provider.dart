import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/product.dart';

/// Loads a list of products one page at a time.
abstract class PagedProductsProvider extends ChangeNotifier {
  ViewState<List<ProductSummary>> _state = const ViewState.initial();
  ProductCursor? _next;
  bool _isLoadingMore = false;
  AppFailure? _loadMoreFailure;
  bool _isDisposed = false;

  /// Only the newest request may change the list, so a slow old search can't
  /// replace the results of a newer one.
  int _request = 0;

  ViewState<List<ProductSummary>> get state => _state;
  bool get hasMore => _next != null;
  bool get isLoadingMore => _isLoadingMore;
  AppFailure? get loadMoreFailure => _loadMoreFailure;

  @protected
  Future<ProductPage> fetchPage(ProductCursor? cursor);

  /// Loads the first page. A pull-to-refresh keeps the old list on screen, but
  /// a changed filter clears it, since the old list no longer matches.
  Future<void> reload({bool keepList = false}) async {
    final request = ++_request;
    _next = null;
    _isLoadingMore = false;
    _loadMoreFailure = null;
    final previous = keepList ? _state.data : null;
    _state = ViewState.loading(data: previous);
    notifyListeners();
    try {
      final page = await fetchPage(null);
      if (request != _request) return;
      _next = page.next;
      _state = page.items.isEmpty
          ? const ViewState.empty()
          : ViewState.success(page.items);
    } on AppFailure catch (failure) {
      if (request != _request) return;
      _state = ViewState.error(failure, data: previous);
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    final cursor = _next;
    final items = _state.data;
    if (cursor == null ||
        items == null ||
        _isLoadingMore ||
        _state.status != ViewStatus.success) {
      return;
    }
    final request = _request;
    _isLoadingMore = true;
    _loadMoreFailure = null;
    notifyListeners();
    try {
      final page = await fetchPage(cursor);
      if (request != _request) return;
      _next = page.next;
      _state = ViewState.success([...items, ...page.items]);
    } on AppFailure catch (failure) {
      if (request != _request) return;
      _loadMoreFailure = failure;
    }
    _isLoadingMore = false;
    notifyListeners();
  }

  /// Puts the list back to its starting state, and drops any request on its way.
  @protected
  void clear() {
    _request++;
    _next = null;
    _isLoadingMore = false;
    _loadMoreFailure = null;
    _state = const ViewState.initial();
    notifyListeners();
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
