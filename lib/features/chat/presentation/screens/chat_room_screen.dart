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
import '../../../reports/presentation/widgets/report_sheet.dart';
import '../../domain/entities/chat.dart';
import '../providers/chat_room_provider.dart';

class ChatRoomScreen extends StatelessWidget {
  const ChatRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatRoomProvider>();
    final state = provider.state;
    final header = state.data;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: AppRoutes.chats),
        title: Text(header?.otherName ?? 'Chat'),
      ),
      body: switch (state.status) {
        ViewStatus.empty => const EmptyView(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'We could not find this chat',
        ),
        ViewStatus.error when header == null => ErrorView(
          message: state.failure!.message,
          onRetry: provider.load,
        ),
        _ when header == null => const LoadingView(),
        _ => Column(
          children: [
            if (header.productTitle != null) _ProductBar(header: header),
            const Expanded(child: _MessageList()),
            const _Composer(),
          ],
        ),
      },
    );
  }
}

/// What the chat is about. The listing price is fixed, so it is shown here to
/// make clear that chat doesn't change it.
class _ProductBar extends StatelessWidget {
  const _ProductBar({required this.header});

  final ChatHeader header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productId = header.productId;
    final price = header.productPrice;
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: productId == null
            ? null
            : () => context.push(AppRoutes.product(productId)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 44,
                  child: AppNetworkImage(
                    url: header.productImageUrl,
                    displayWidth: 44,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      header.productTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      price == null
                          ? 'No longer on sale'
                          : '${formatTaka(price)} · Fixed price',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatRoomProvider>();
    final messages = provider.messages;
    if (messages.isEmpty) {
      return const EmptyView(
        icon: Icons.waving_hand_outlined,
        title: 'Say hello',
        message: 'Ask about the product. To buy, order at the listing price.',
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        if (index == messages.length - 1) provider.loadMore();
        return _Bubble(message: messages[index]);
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMine = context.read<ChatRoomProvider>().isMine(message);
    final foreground = isMine ? Colors.white : AppColors.textPrimary;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        // Only the other person's messages can be reported.
        onLongPress: isMine
            ? null
            : () => showReportSheet(
                context,
                targetType: ReportTarget.message,
                targetId: message.id,
                title: 'Report this message',
              ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMine ? AppColors.primary : AppColors.surface,
            border: isMine ? null : Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: Text(message.body, style: TextStyle(color: foreground)),
              ),
              const SizedBox(height: 2),
              Text(
                formatDateTime(message.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer();

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final sent = await context.read<ChatRoomProvider>().send(_text.text);
    if (sent) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatRoomProvider>();
    final failure = provider.sendFailure;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (failure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    failure,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      buildCounter: (
                        context, {
                        required currentLength,
                        required isFocused,
                        required maxLength,
                      }) => null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Write a message',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send',
                    icon: const Icon(
                      Icons.send_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: provider.isSending ? null : _send,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
