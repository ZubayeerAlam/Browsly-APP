import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/state_views.dart';

class PostScreen extends StatelessWidget {
  const PostScreen({this.backTo, super.key});

  /// The tab to return to.
  final String? backTo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        centerTitle: true,
        leading: BackButton(
          onPressed: () => context.go(backTo ?? AppRoutes.dashboard),
        ),
      ),
      body: const EmptyView(
        icon: Icons.edit_square,
        title: 'Create Your Listing',
        message: 'The listing form is added in Step 3.',
      ),
    );
  }
}
