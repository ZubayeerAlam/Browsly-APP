import 'package:flutter/material.dart';

import '../../../../core/widgets/state_views.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: const EmptyView(
        icon: Icons.pie_chart_outline_rounded,
        title: 'No statistics yet',
        message: 'Real statistics are added in Step 6.',
      ),
    );
  }
}
