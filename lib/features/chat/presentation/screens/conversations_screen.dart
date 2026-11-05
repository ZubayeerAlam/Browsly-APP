import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/chat.dart';
import '../providers/conversations_provider.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversationsProvider>();
    final state = provider.state;
    final items = state.data;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: AppRoutes.dashboard),
        title: const Text('Chats'),
      ),
      body: switch (state.status) {
        ViewStatus.empty => const EmptyView(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'No chats yet',
          message: 'Tap Chat with seller on a product to ask a question.',
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
              return _ConversationRow(conversation: items[index]);
            },
          ),
        ),
      },
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation});

  final Conversation conversation;

  Future<void> _open(BuildContext context) async {
    final provider = context.read<ConversationsProvider>();
    await context.push(AppRoutes.chat(conversation.id));
    // The unread count has changed, and there may be new messages.
    await provider.load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = conversation.unreadCount > 0;
    final subject = conversation.productTitle;
    return ListTile(
      onTap: () => _open(context),
      leading: ClipOval(
        child: SizedBox.square(
          dimension: 48,
          child: AppNetworkImage(
            url: conversation.otherImageUrl ?? conversation.productImageUrl,
            displayWidth: 48,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.otherName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            formatDate(conversation.lastMessageAt),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subject != null)
            Text(
              subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          Text(
            conversation.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
      trailing: isUnread ? Badge.count(count: conversation.unreadCount) : null,
    );
  }
}
