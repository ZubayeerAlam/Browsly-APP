import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/selling_errors.dart';
import '../../../../core/state/view_state.dart';
import '../../../notifications/domain/entities/app_notification.dart';
import '../../domain/entities/listing.dart';
import '../../domain/repositories/listing_repository.dart';

/// The seller's listings on My Posts, one tab at a time.
class MyListingsProvider extends ChangeNotifier {
  MyListingsProvider(this._repository, {Stream<AppNotification>? updates}) {
    _updates = updates?.listen((notification) {
      if (notification.type == AppNotificationType.listingLive ||
          notification.type == AppNotificationType.listingRejected) {
        load(keepList: true);
      }
    });
  }

  /// Reloads when a notification says this may have changed.
  StreamSubscription<AppNotification>? _updates;

  final ListingRepository _repository;

  ListingTab _tab = ListingTab.all;
  ViewState<List<ListingSummary>> _state = const ViewState.initial();
  ListingCursor? _next;
  bool _isLoadingMore = false;
  String? _actionFailure;
  bool _isDisposed = false;

  /// Only the newest request may change the list.
  int _request = 0;

  ListingTab get tab => _tab;
  ViewState<List<ListingSummary>> get state => _state;
  bool get isLoadingMore => _isLoadingMore;
  String? get actionFailure => _actionFailure;

  Future<void> setTab(ListingTab tab) {
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
      final page = await _repository.getMyListings(_tab);
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
      final page = await _repository.getMyListings(_tab, cursor: cursor);
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

  Future<void> setPaused(ListingSummary listing, {required bool paused}) {
    return _act(() => _repository.setPaused(listing.id, paused: paused));
  }

  Future<void> delete(ListingSummary listing) {
    return _act(() => _repository.delete(listing.id));
  }

  Future<void> _act(Future<void> Function() action) async {
    _actionFailure = null;
    _notify();
    try {
      await action();
    } on AppFailure catch (failure) {
      _actionFailure = sellingFailureMessage(failure);
    }
    await load(keepList: true);
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
