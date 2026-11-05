import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/cart/data/datasources/cart_remote_data_source.dart';
import 'features/cart/data/repositories/cart_repository_impl.dart';
import 'features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'features/catalog/data/repositories/catalog_repository_impl.dart';
import 'features/chat/data/datasources/chat_remote_data_source.dart';
import 'features/chat/data/repositories/chat_repository_impl.dart';
import 'features/listings/data/datasources/listing_remote_data_source.dart';
import 'features/listings/data/repositories/listing_repository_impl.dart';
import 'features/notifications/data/repositories/notification_repository_impl.dart';
import 'features/orders/data/datasources/order_remote_data_source.dart';
import 'features/orders/data/repositories/order_repository_impl.dart';
import 'features/profile/data/datasources/address_remote_data_source.dart';
import 'features/profile/data/datasources/profile_remote_data_source.dart';
import 'features/profile/data/repositories/address_repository_impl.dart';
import 'features/profile/data/repositories/profile_repository_impl.dart';
import 'features/reports/data/repositories/report_repository_impl.dart';
import 'features/reviews/data/repositories/review_repository_impl.dart';
import 'features/sales/data/datasources/sales_remote_data_source.dart';
import 'features/sales/data/repositories/sales_repository_impl.dart';
import 'features/shop/data/datasources/shop_remote_data_source.dart';
import 'features/statistics/data/repositories/statistics_repository_impl.dart';
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
      cartRepository: CartRepositoryImpl(CartRemoteDataSource(client)),
      orderRepository: OrderRepositoryImpl(OrderRemoteDataSource(client)),
      salesRepository: SalesRepositoryImpl(SalesRemoteDataSource(client)),
      chatRepository: ChatRepositoryImpl(ChatRemoteDataSource(client)),
      notificationRepository: NotificationRepositoryImpl(client),
      reviewRepository: ReviewRepositoryImpl(client),
      reportRepository: ReportRepositoryImpl(client),
      statisticsRepository: StatisticsRepositoryImpl(client),
    ),
  );
}
