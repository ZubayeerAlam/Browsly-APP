import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/buying_errors.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/chat.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRoomProvider extends ChangeNotifier {
  ChatRoomProvider(this._repository, this.conversationId, this.userId) {
    _lifecycle = AppLifecycleListener(onResume: _catchUp);
  }

  static const _pageSize = 30;

  final ChatRepository _repository;
  final String conversationId;
  final String? userId;
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<ChatMessage>? _incoming;

  ViewState<ChatHeader> _state = const ViewState.initial();

  /// Newest first, because the list is drawn from the bottom up.
  List<ChatMessage> _messages = const [];
  bool _hasMore = false;
  bool _isLoadingMore = false;
  bool _isSending = false;
  String? _sendFailure;
  bool _isDisposed = false;

  ViewState<ChatHeader> get state => _state;
  List<ChatMessage> get messages => _messages;
  bool get isSending => _isSending;
  bool get isLoadingMore => _isLoadingMore;
  String? get sendFailure => _sendFailure;

  bool isMine(ChatMessage message) => message.senderId == userId;

  Future<void> load() async {
    _state = ViewState.loading(data: _state.data);
    _notify();
    // Listen first, so nothing sent during the load is missed. Duplicates are
    // removed by ID.
    _incoming ??= _repository
        .watchMessages(conversationId)
        .listen(_onIncoming, onError: (Object _) {});
    try {
      final results = await Future.wait([
        _repository.getHeader(conversationId),
        _repository.getMessages(conversationId, limit: _pageSize),
      ]);
      final header = results[0] as ChatHeader?;
      if (header == null) {
        _state = const ViewState.empty();
        _notify();
        return;
      }
      final loaded = results[1] as List<ChatMessage>;
      _hasMore = loaded.length == _pageSize;
      _merge(loaded);
      _state = ViewState.success(header);
      _markRead();
    } on AppFailure catch (failure) {
      _state = ViewState.error(failure, data: _state.data);
    }
    _notify();
  }

  /// Messages sent while the app was in the background.
  Future<void> _catchUp() async {
    try {
      _merge(await _repository.getMessages(conversationId, limit: _pageSize));
      _markRead();
      _notify();
    } on AppFailure {
      // The next message or refresh brings them in.
    }
  }

  void _onIncoming(ChatMessage message) {
    _merge([message]);
    if (!isMine(message)) _markRead();
    _notify();
  }

  void _merge(List<ChatMessage> incoming) {
    final byId = {for (final message in _messages) message.id: message};
    for (final message in incoming) {
      byId[message.id] = message;
    }
    _messages = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _markRead() {
    unawaited(
      _repository.markRead(conversationId).catchError((Object _) {
        // It stays unread until the chat is next opened.
      }),
    );
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || _messages.isEmpty) return;
    _isLoadingMore = true;
    _notify();
    try {
      final older = await _repository.getMessages(
        conversationId,
        before: _messages.last.createdAt,
        limit: _pageSize,
      );
      _hasMore = older.length == _pageSize;
      _merge(older);
    } on AppFailure {
      // Scrolling again retries.
    }
    _isLoadingMore = false;
    _notify();
  }

  /// Returns true if it was sent, so the screen can clear the box.
  Future<bool> send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _isSending) return false;
    _isSending = true;
    _sendFailure = null;
    _notify();
    var sent = false;
    try {
      _merge([await _repository.send(conversationId, body)]);
      sent = true;
    } on AppFailure catch (failure) {
      _sendFailure = buyingFailureMessage(failure);
    }
    _isSending = false;
    _notify();
    return sent;
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _lifecycle.dispose();
    _incoming?.cancel();
    super.dispose();
  }
}
