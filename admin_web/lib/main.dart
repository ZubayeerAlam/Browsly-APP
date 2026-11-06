import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'features/auth/admin_auth.dart';
import 'features/banners/banners_data.dart';
import 'features/categories/categories_data.dart';
import 'features/orders/orders_data.dart';
import 'features/overview/overview_data.dart';
import 'features/products/products_data.dart';
import 'features/reports/reports_data.dart';
import 'features/review/review_data.dart';
import 'features/settings/settings_data.dart';
import 'features/settlements/settlements_data.dart';
import 'features/users/users_data.dart';

/// Only the public URL and key are ever given to this app. Admin rights come from
/// the signed-in account, and are checked by the server on every request.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty || key.isEmpty) {
    throw StateError(
      'Supabase settings are missing. Build with '
      '--dart-define-from-file=../env.json.',
    );
  }
  await Supabase.initialize(url: url, publishableKey: key);
  final client = Supabase.instance.client;
  runApp(
    AdminApp(
      repositories: AdminRepositories(
        auth: AdminAuthRepositoryImpl(client),
        overview: OverviewRepositoryImpl(client),
        review: ReviewRepositoryImpl(client),
        users: UsersRepositoryImpl(client),
        products: ProductsRepositoryImpl(client),
        orders: OrdersRepositoryImpl(client),
        categories: CategoriesRepositoryImpl(client),
        settings: SettingsRepositoryImpl(client),
        banners: BannersRepositoryImpl(client),
        reports: ReportsRepositoryImpl(client),
        settlements: SettlementsRepositoryImpl(client),
      ),
    ),
  );
}
