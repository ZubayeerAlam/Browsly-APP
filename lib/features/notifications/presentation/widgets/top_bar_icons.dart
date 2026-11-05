import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../providers/notifications_provider.dart';

class ChatIconButton extends StatelessWidget {
  const ChatIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.select<NotificationsProvider, int>(
      (provider) => provider.counts.chat,
    );
    return IconButton(
      tooltip: count == 0 ? 'Chats' : 'Chats, $count unread',
      icon: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: const Icon(Icons.chat_bubble_outline_rounded),
      ),
      onPressed: () => context.push(AppRoutes.chats),
    );
  }
}

class NotificationIconButton extends StatelessWidget {
  const NotificationIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.select<NotificationsProvider, int>(
      (provider) => provider.counts.notifications,
    );
    return IconButton(
      tooltip: count == 0 ? 'Notifications' : 'Notifications, $count unread',
      icon: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: const Icon(Icons.notifications_none_rounded),
      ),
      onPressed: () => context.push(AppRoutes.notifications),
    );
  }
}
