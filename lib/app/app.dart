import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/cart/domain/repositories/cart_repository.dart';
import '../features/cart/presentation/providers/cart_provider.dart';
import '../features/catalog/domain/repositories/catalog_repository.dart';
import '../features/listings/domain/repositories/listing_repository.dart';
import '../features/orders/domain/repositories/order_repository.dart';
import '../features/profile/domain/repositories/address_repository.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import '../features/shop/domain/repositories/shop_repository.dart';
import '../features/wishlist/domain/repositories/wishlist_repository.dart';
import '../features/wishlist/presentation/providers/wishlist_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class BrowslyApp extends StatefulWidget {
  const BrowslyApp({
    required this.config,
    required this.authRepository,
    required this.profileRepository,
    required this.addressRepository,
    required this.catalogRepository,
    required this.wishlistRepository,
    required this.shopRepository,
    required this.listingRepository,
    required this.cartRepository,
    required this.orderRepository,
    this.theme,
    super.key,
  });

  final AppConfig config;
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final AddressRepository addressRepository;
  final CatalogRepository catalogRepository;
  final WishlistRepository wishlistRepository;
  final ShopRepository shopRepository;
  final ListingRepository listingRepository;
  final CartRepository cartRepository;
  final OrderRepository orderRepository;

  /// Lets tests supply a theme that doesn't download a font.
  final ThemeData? theme;

  @override
  State<BrowslyApp> createState() => _BrowslyAppState();
}

class _BrowslyAppState extends State<BrowslyApp> {
  late final AuthProvider _authProvider;
  late final ProfileProvider _profileProvider;
  late final WishlistProvider _wishlistProvider;
  late final CartProvider _cartProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider(widget.authRepository);
    _profileProvider = ProfileProvider(widget.profileRepository, _authProvider);
    _wishlistProvider = WishlistProvider(
      widget.wishlistRepository,
      _authProvider,
    );
    _cartProvider = CartProvider(widget.cartRepository, _authProvider);
    _router = createAppRouter(_authProvider);
  }

  @override
  void dispose() {
    _router.dispose();
    _cartProvider.dispose();
    _wishlistProvider.dispose();
    _profileProvider.dispose();
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: widget.config),
        Provider<AuthRepository>.value(value: widget.authRepository),
        Provider<AddressRepository>.value(value: widget.addressRepository),
        Provider<CatalogRepository>.value(value: widget.catalogRepository),
        Provider<WishlistRepository>.value(value: widget.wishlistRepository),
        Provider<ShopRepository>.value(value: widget.shopRepository),
        Provider<ListingRepository>.value(value: widget.listingRepository),
        Provider<CartRepository>.value(value: widget.cartRepository),
        Provider<OrderRepository>.value(value: widget.orderRepository),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<CartProvider>.value(value: _cartProvider),
        ChangeNotifierProvider<ProfileProvider>.value(value: _profileProvider),
        ChangeNotifierProvider<WishlistProvider>.value(
          value: _wishlistProvider,
        ),
      ],
      child: MaterialApp.router(
        title: 'Browsly',
        debugShowCheckedModeBanner: false,
        theme: widget.theme ?? AppTheme.light(),
        routerConfig: _router,
      ),
    );
  }
}
