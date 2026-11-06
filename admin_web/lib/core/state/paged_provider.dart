import 'package:flutter/foundation.dart';

import '../data/paging.dart';
import '../errors/app_failure.dart';
import 'view_state.dart';

/// A searchable, filterable list that loads a page at a time. Every table in the
/// panel uses it, with [F] as its filter, such as a status.
class PagedProvider<T, F> extends ChangeNotifier {
  PagedProvider(this._fetch, {F? filter}) {
    _filter = filter;
  }

  final Future<ItemPage<T>> Function(
    String? search,
    F? filter,
    PageCursor? next,
  )
  _fetch;

  ViewState<List<T>> _state = const ViewState.initial();
  String? _search;
  F? _filter;
  PageCursor? _next;
  bool _isLoadingMore = false;
  String? _actionFailure;
  bool _isDisposed = false;

  /// Only the newest request may change the list.
  int _request = 0;

  ViewState<List<T>> get state => _state;
  F? get filter => _filter;
  bool get hasMore => _next != null;
  bool get isLoadingMore => _isLoadingMore;
  String? get actionFailure => _actionFailure;

  void setSearch(String text) {
    final search = text.trim().isEmpty ? null : text.trim();
    if (search == _search) return;
    _search = search;
    load();
  }

  void setFilter(F? filter) {
    if (filter == _filter) return;
    _filter = filter;
    load();
  }

  Future<void> load() async {
    final request = ++_request;
    final previous = _state.data;
    _next = null;
    _isLoadingMore = false;
    _state = ViewState.loading(data: previous);
    _notify();
    try {
      final page = await _fetch(_search, _filter, null);
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
      final page = await _fetch(_search, _filter, cursor);
      if (request != _request) return;
      _next = page.next;
      _state = ViewState.success([...items, ...page.items]);
    } on AppFailure catch (failure) {
      if (request != _request) return;
      _actionFailure = failure.message;
    }
    _isLoadingMore = false;
    _notify();
  }

  /// Runs a change, then reloads, because the list has usually changed too.
  /// Returns true if it worked.
  Future<bool> act(Future<void> Function() action) async {
    _actionFailure = null;
    _notify();
    var succeeded = true;
    try {
      await action();
    } on AppFailure catch (failure) {
      _actionFailure = failure.message;
      succeeded = false;
    }
    await load();
    return succeeded;
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
