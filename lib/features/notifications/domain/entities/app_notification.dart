enum AppNotificationType {
  newOrder,
  orderUpdate,
  orderCancelled,
  chatMessage,
  listingLive,
  listingRejected,
  commissionPayment,
  reportUpdate,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.groupId,
    this.orderId,
    this.productId,
    this.conversationId,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? groupId;
  final String? orderId;
  final String? productId;
  final String? conversationId;
}

/// Where the next page starts.
class NotificationPage {
  const NotificationPage({required this.items, this.hasMore = false});

  final List<AppNotification> items;
  final bool hasMore;
}

class UnreadCounts {
  const UnreadCounts({this.notifications = 0, this.chat = 0});

  final int notifications;
  final int chat;
}
