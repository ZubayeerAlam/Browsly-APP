import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

/// The two badges in the top bar, and live updates for screens to react to, so
/// nobody has to pull to refresh when an order arrives or a review finishes.
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider(this._repository, this._auth) {
    _lifecycle = AppLifecycleListener(onResume: refreshCounts);
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final NotificationRepository _repository;
  final AuthProvider _auth;
  late final AppLifecycleListener _lifecycle;
  final _incoming = StreamController<AppNotification>.broadcast();
  StreamSubscription<AppNotification>? _subscription;
  String? _loadedFor;
  UnreadCounts _counts = const UnreadCounts();

  UnreadCounts get counts => _counts;

  /// New notifications. Marking one as read doesn't count as new.
  Stream<AppNotification> get incoming => _incoming.stream;

  void _onAuthChanged() {
    final userId = _auth.user?.id;
    if (userId == _loadedFor) return;
    _loadedFor = userId;
    _counts = const UnreadCounts();
    _subscription?.cancel();
    _subscription = null;
    notifyListeners();
    if (userId == null) return;
    _subscription = _repository
        .watch(userId)
        .listen(_onChange, onError: (Object _) {});
    unawaited(refreshCounts());
  }

  void _onChange(AppNotification notification) {
    if (!notification.isRead) _incoming.add(notification);
    unawaited(refreshCounts());
  }

  /// A failed refresh keeps the old badge, and the next change corrects it.
  Future<void> refreshCounts() async {
    final userId = _auth.user?.id;
    if (userId == null) return;
    try {
      final counts = await _repository.getUnreadCounts();
      if (_auth.user?.id != userId) return;
      _counts = counts;
      notifyListeners();
    } on AppFailure {
      // See above.
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _auth.removeListener(_onAuthChanged);
    _subscription?.cancel();
    _incoming.close();
    super.dispose();
  }
}
