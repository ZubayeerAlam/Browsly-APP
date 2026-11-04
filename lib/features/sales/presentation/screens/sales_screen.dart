import 'package:flutter/material.dart';

import '../../../../core/widgets/state_views.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: const EmptyView(
        icon: Icons.bar_chart_rounded,
        title: 'No sales yet',
        message: 'Order management is added in Step 5.',
      ),
    );
  }
}
