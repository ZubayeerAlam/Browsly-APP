import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/buying_errors.dart';
import '../../domain/repositories/chat_repository.dart';

/// Opens the chat that [start] finds or creates, or explains why it can't.
Future<void> openChat(
  BuildContext context,
  Future<String> Function(ChatRepository chats) start,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  try {
    final id = await start(context.read<ChatRepository>());
    await router.push(AppRoutes.chat(id));
  } on AppFailure catch (failure) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(buyingFailureMessage(failure))));
  }
}
