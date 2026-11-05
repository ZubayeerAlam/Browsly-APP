import '../entities/app_notification.dart';

abstract interface class NotificationRepository {
  /// Newest first, leaving out chat messages, which have their own screen.
  Future<NotificationPage> getPage({DateTime? before, int limit = 20});

  Future<UnreadCounts> getUnreadCounts();

  /// Null marks them all as read.
  Future<void> markRead(String? id);

  /// Every new or changed notification for this user, as it happens.
  Stream<AppNotification> watch(String userId);
}
