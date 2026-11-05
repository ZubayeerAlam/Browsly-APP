import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import 'shop_form_view.dart';

class EditShopScreen extends StatelessWidget {
  const EditShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your shop'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.myPosts)),
      ),
      body: ShopFormView(onSaved: (_) => context.go(AppRoutes.myPosts)),
    );
  }
}
