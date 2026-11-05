import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationListProvider extends ChangeNotifier {
  NotificationListProvider(
    this._repository, {
    Stream<AppNotification>? updates,
    this.onRead,
  }) {
    _updates = updates?.listen((notification) {
      if (notification.type != AppNotificationType.chatMessage) load();
    });
  }

  final NotificationRepository _repository;
  StreamSubscription<AppNotification>? _updates;

  /// Lets the badge update as soon as something is read.
  final Future<void> Function()? onRead;

  ViewState<List<AppNotification>> _state = const ViewState.initial();
  bool _hasMore = false;
  bool _isLoadingMore = false;
  bool _isDisposed = false;

  ViewState<List<AppNotification>> get state => _state;

  bool get hasUnread => _state.data?.any((item) => !item.isRead) ?? false;

  Future<void> load() async {
    final previous = _state.data;
    _state = ViewState.loading(data: previous);
    _notify();
    try {
      final page = await _repository.getPage();
      _hasMore = page.hasMore;
      _state = page.items.isEmpty
          ? const ViewState.empty()
          : ViewState.success(page.items);
    } on AppFailure catch (failure) {
      _state = ViewState.error(failure, data: previous);
    }
    _notify();
  }

  Future<void> loadMore() async {
    final items = _state.data;
    if (!_hasMore || items == null || items.isEmpty || _isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final page = await _repository.getPage(before: items.last.createdAt);
      _hasMore = page.hasMore;
      _state = ViewState.success([...items, ...page.items]);
    } on AppFailure {
      // Scrolling again retries.
    }
    _isLoadingMore = false;
    _notify();
  }

  /// Null marks them all as read.
  Future<void> markRead(String? id) async {
    try {
      await _repository.markRead(id);
    } on AppFailure {
      // They stay unread, and nothing else depends on it.
      return;
    }
    await load();
    await onRead?.call();
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
