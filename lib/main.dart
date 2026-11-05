import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'features/catalog/data/repositories/catalog_repository_impl.dart';
import 'features/listings/data/datasources/listing_remote_data_source.dart';
import 'features/listings/data/repositories/listing_repository_impl.dart';
import 'features/profile/data/datasources/address_remote_data_source.dart';
import 'features/profile/data/datasources/profile_remote_data_source.dart';
import 'features/profile/data/repositories/address_repository_impl.dart';
import 'features/profile/data/repositories/profile_repository_impl.dart';
import 'features/shop/data/datasources/shop_remote_data_source.dart';
import 'features/shop/data/repositories/shop_repository_impl.dart';
import 'features/wishlist/data/datasources/wishlist_remote_data_source.dart';
import 'features/wishlist/data/repositories/wishlist_repository_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  if (!config.isConfigured && !kDebugMode) {
    throw StateError(
      'Supabase settings are missing. Build with --dart-define-from-file=env.json.',
    );
  }
  // Debug builds without settings still open, and browse as a guest.
  await Supabase.initialize(
    url: config.isConfigured ? config.supabaseUrl : 'http://127.0.0.1:54321',
    publishableKey: config.isConfigured
        ? config.supabasePublishableKey
        : 'missing-local-key',
  );

  final client = Supabase.instance.client;
  final catalogRepository = CatalogRepositoryImpl(
    CatalogRemoteDataSource(client),
  );
  runApp(
    BrowslyApp(
      config: config,
      authRepository: AuthRepositoryImpl(AuthRemoteDataSource(client)),
      profileRepository: ProfileRepositoryImpl(ProfileRemoteDataSource(client)),
      addressRepository: AddressRepositoryImpl(AddressRemoteDataSource(client)),
      catalogRepository: catalogRepository,
      wishlistRepository: WishlistRepositoryImpl(
        WishlistRemoteDataSource(client),
      ),
      shopRepository: ShopRepositoryImpl(
        ShopRemoteDataSource(client),
        catalogRepository,
      ),
      listingRepository: ListingRepositoryImpl(ListingRemoteDataSource(client)),
    ),
  );
}
