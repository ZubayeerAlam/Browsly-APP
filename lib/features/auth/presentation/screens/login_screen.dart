import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/state_views.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: EmptyView(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in to continue',
        message: 'Sign-in screens are added in Step 1.',
        action: OutlinedButton(
          onPressed: () => context.go(AppRoutes.dashboard),
          child: const Text('Keep browsing'),
        ),
      ),
    );
  }
}
