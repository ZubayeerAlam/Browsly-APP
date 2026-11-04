import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSignedIn = context.select<AuthProvider, bool>(
      (auth) => auth.isSignedIn,
    );
    final avatarUrl = context.select<ProfileProvider, String?>(
      (provider) => provider.profile?.avatarUrl,
    );
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Browsly', style: TextStyle(color: AppColors.primary)),
          ],
        ),
        actions: [
          if (isSignedIn)
            IconButton(
              tooltip: 'Settings',
              onPressed: () => context.go(AppRoutes.settings),
              icon: ProfileAvatar(url: avatarUrl, radius: 18),
            )
          else
            TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Sign in'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: const EmptyView(
        icon: Icons.home_outlined,
        title: 'Dashboard',
        message: 'Your summary is added in Step 6.',
      ),
    );
  }
}
