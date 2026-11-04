import 'package:flutter/material.dart';

import '../../../../core/widgets/state_views.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: const EmptyView(
        icon: Icons.inventory_2_outlined,
        title: 'No products yet',
        message: 'The marketplace is added in Step 2.',
      ),
    );
  }
}
