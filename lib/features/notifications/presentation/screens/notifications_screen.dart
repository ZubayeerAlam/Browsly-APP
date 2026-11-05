import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_list_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationListProvider>();
    final state = provider.state;
    final items = state.data;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: AppRoutes.dashboard),
        title: const Text('Notifications'),
        actions: [
          if (provider.hasUnread)
            TextButton(
              onPressed: () => provider.markRead(null),
              child: const Text('Mark all read'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: switch (state.status) {
        ViewStatus.empty => const EmptyView(
          icon: Icons.notifications_none_rounded,
          title: 'No notifications yet',
          message: 'Order updates and listing results will appear here.',
        ),
        ViewStatus.error when items == null => ErrorView(
          message: state.failure!.message,
          onRetry: provider.load,
        ),
        _ when items == null => const LoadingView(),
        _ => RefreshIndicator(
          onRefresh: provider.load,
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == items.length - 1) provider.loadMore();
              return _NotificationRow(notification: items[index]);
            },
          ),
        ),
      },
    );
  }
}

/// Where tapping a notification leads. Null if there is nowhere useful to go.
String? notificationRoute(AppNotification notification) {
  final groupId = notification.groupId;
  final orderId = notification.orderId;
  final conversationId = notification.conversationId;
  if (conversationId != null) return AppRoutes.chat(conversationId);
  if (groupId != null) return AppRoutes.sale(groupId);
  if (orderId != null) return AppRoutes.order(orderId);
  return switch (notification.type) {
    AppNotificationType.listingLive ||
    AppNotificationType.listingRejected => AppRoutes.myPosts,
    AppNotificationType.commissionPayment => AppRoutes.commission,
    _ => null,
  };
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification});

  final AppNotification notification;

  IconData get _icon => switch (notification.type) {
    AppNotificationType.newOrder => Icons.shopping_bag_outlined,
    AppNotificationType.orderUpdate => Icons.local_shipping_outlined,
    AppNotificationType.orderCancelled => Icons.cancel_outlined,
    AppNotificationType.chatMessage => Icons.chat_bubble_outline_rounded,
    AppNotificationType.listingLive => Icons.check_circle_outline_rounded,
    AppNotificationType.listingRejected => Icons.report_gmailerrorred_rounded,
    AppNotificationType.commissionPayment =>
      Icons.account_balance_wallet_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.read<NotificationListProvider>();
    final isUnread = !notification.isRead;
    return ListTile(
      tileColor: isUnread ? AppColors.primarySoft : null,
      leading: Icon(_icon, color: AppColors.primary),
      title: Text(
        notification.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '${notification.body}\n${formatDateTime(notification.createdAt)}',
      ),
      isThreeLine: true,
      onTap: () {
        if (isUnread) provider.markRead(notification.id);
        final route = notificationRoute(notification);
        if (route != null) context.push(route);
      },
    );
  }
}
