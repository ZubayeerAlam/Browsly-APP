import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BrowslyApp(authRepository: await _createAuthRepository()));
}

Future<AuthRepository> _createAuthRepository() async {
  final config = AppConfig.fromEnvironment();
  if (!config.isConfigured) {
    if (kDebugMode) return const GuestAuthRepository();
    throw StateError(
      'Supabase settings are missing. Build with --dart-define-from-file=env.json.',
    );
  }
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
  );
  return AuthRepositoryImpl(AuthRemoteDataSource(Supabase.instance.client));
}
