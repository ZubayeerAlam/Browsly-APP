import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this._client);

  final SupabaseClient _client;

  static AppNotification _fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return AppNotification(
      id: json['id'] as String,
      type: switch (json['type'] as String) {
        'new_order' => AppNotificationType.newOrder,
        'order_cancelled' => AppNotificationType.orderCancelled,
        'chat_message' => AppNotificationType.chatMessage,
        'listing_live' => AppNotificationType.listingLive,
        'listing_rejected' => AppNotificationType.listingRejected,
        'commission_payment' => AppNotificationType.commissionPayment,
        'report_update' => AppNotificationType.reportUpdate,
        _ => AppNotificationType.orderUpdate,
      },
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      isRead: json['read_at'] != null,
      groupId: data['group_id'] as String?,
      orderId: data['order_id'] as String?,
      productId: data['product_id'] as String?,
      conversationId: data['conversation_id'] as String?,
    );
  }

  @override
  Future<NotificationPage> getPage({DateTime? before, int limit = 20}) {
    return guardFailures(() async {
      var query = _client
          .from('notifications')
          .select('id, type, title, body, data, read_at, created_at')
          .neq('type', 'chat_message');
      if (before != null) {
        query = query.lt('created_at', before.toUtc().toIso8601String());
      }
      // One extra row shows whether another page exists.
      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit + 1);
      final hasMore = rows.length > limit;
      return NotificationPage(
        items: (hasMore ? rows.sublist(0, limit) : rows)
            .map(_fromJson)
            .toList(),
        hasMore: hasMore,
      );
    });
  }

  @override
  Future<UnreadCounts> getUnreadCounts() {
    return guardFailures(() async {
      final json = await _client.rpc<Map<String, dynamic>>('get_unread_counts');
      return UnreadCounts(
        notifications: (json['notifications'] as num).toInt(),
        chat: (json['chat'] as num).toInt(),
      );
    });
  }

  @override
  Future<void> markRead(String? id) {
    return guardFailures(
      () => _client.rpc<void>('mark_notifications_read', params: {'p_id': id}),
    );
  }

  @override
  Stream<AppNotification> watch(String userId) {
    late final RealtimeChannel channel;
    late final StreamController<AppNotification> controller;
    controller = StreamController<AppNotification>(
      onListen: () {
        channel = _client
            .channel('notifications:$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (payload) {
                if (payload.newRecord.isNotEmpty) {
                  controller.add(_fromJson(payload.newRecord));
                }
              },
            )
            .subscribe();
      },
      onCancel: () => _client.removeChannel(channel),
    );
    return controller.stream;
  }
}
