import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Goes back, or to [fallback] when this screen was opened directly, such as
/// straight after signing in.
class AppBackButton extends StatelessWidget {
  const AppBackButton({required this.fallback, super.key});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    return BackButton(
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallback);
        }
      },
    );
  }
}
