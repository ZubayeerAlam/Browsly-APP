import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
      ),
      body: const EmptyView(
        icon: Icons.home_outlined,
        title: 'Dashboard',
        message: 'Your summary is added in Step 6.',
      ),
    );
  }
}
