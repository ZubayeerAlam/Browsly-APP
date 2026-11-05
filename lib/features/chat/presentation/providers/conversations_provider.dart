import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../../notifications/domain/entities/app_notification.dart';
import '../../domain/entities/chat.dart';
import '../../domain/repositories/chat_repository.dart';

class ConversationsProvider extends ChangeNotifier {
  ConversationsProvider(this._repository, {Stream<AppNotification>? updates}) {
    _updates = updates?.listen((notification) {
      if (notification.type == AppNotificationType.chatMessage) load();
    });
  }

  final ChatRepository _repository;
  StreamSubscription<AppNotification>? _updates;

  ViewState<List<Conversation>> _state = const ViewState.initial();
  ConversationCursor? _next;
  bool _isLoadingMore = false;
  bool _isDisposed = false;

  /// Only the newest request may change the list.
  int _request = 0;

  ViewState<List<Conversation>> get state => _state;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> load() async {
    final request = ++_request;
    final previous = _state.data;
    _next = null;
    _isLoadingMore = false;
    _state = ViewState.loading(data: previous);
    _notify();
    try {
      final page = await _repository.getConversations();
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
      final page = await _repository.getConversations(cursor: cursor);
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
    _updates?.cancel();
    super.dispose();
  }
}
