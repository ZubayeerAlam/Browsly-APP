import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/providers/auth_form_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/phone_auth_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/cart/domain/repositories/cart_repository.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/catalog/domain/entities/product_filters.dart';
import '../../features/catalog/domain/repositories/catalog_repository.dart';
import '../../features/catalog/presentation/providers/product_detail_provider.dart';
import '../../features/catalog/presentation/providers/product_list_provider.dart';
import '../../features/catalog/presentation/providers/shop_provider.dart';
import '../../features/catalog/presentation/screens/product_detail_screen.dart';
import '../../features/catalog/presentation/screens/products_screen.dart';
import '../../features/catalog/presentation/screens/search_screen.dart';
import '../../features/catalog/presentation/screens/shop_screen.dart';
import '../../features/dashboard/presentation/providers/home_provider.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/listings/domain/repositories/listing_repository.dart';
import '../../features/listings/presentation/providers/my_listings_provider.dart';
import '../../features/listings/presentation/providers/product_form_provider.dart';
import '../../features/listings/presentation/screens/my_posts_screen.dart';
import '../../features/listings/presentation/screens/post_screen.dart';
import '../../features/orders/domain/repositories/order_repository.dart';
import '../../features/orders/presentation/providers/checkout_provider.dart';
import '../../features/orders/presentation/providers/my_orders_provider.dart';
import '../../features/orders/presentation/providers/order_detail_provider.dart';
import '../../features/orders/presentation/screens/checkout_screen.dart';
import '../../features/orders/presentation/screens/my_orders_screen.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/profile/domain/entities/address.dart';
import '../../features/profile/domain/repositories/address_repository.dart';
import '../../features/profile/presentation/providers/address_form_provider.dart';
import '../../features/profile/presentation/providers/addresses_provider.dart';
import '../../features/profile/presentation/screens/account_security_screen.dart';
import '../../features/profile/presentation/screens/address_form_screen.dart';
import '../../features/profile/presentation/screens/addresses_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/sales/presentation/screens/sales_screen.dart';
import '../../features/shop/domain/repositories/shop_repository.dart';
import '../../features/shop/presentation/providers/shop_form_provider.dart';
import '../../features/shop/presentation/screens/edit_shop_screen.dart';
import '../../features/statistics/presentation/screens/statistics_screen.dart';
import '../../features/wishlist/domain/repositories/wishlist_repository.dart';
import '../../features/wishlist/presentation/providers/saved_products_provider.dart';
import '../../features/wishlist/presentation/screens/wishlist_screen.dart';
import '../shell/main_shell.dart';
import 'app_routes.dart';

/// Screens open with `go` and nested routes rather than `push`, because
/// GoRouter does not re-check redirects for pushed screens. That re-check is
/// what moves users on after signing in, signing out or verifying a phone.
///
/// Public browsing screens (search, product and shop) are the exception. They
/// open from many places and from each other, so they are pushed to keep the
/// way back, and they need no sign-in to stay open.
GoRouter createAppRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: auth,
    redirect: (context, state) => resolveRedirect(
      isSignedIn: auth.isSignedIn,
      isPhoneVerified: auth.isPhoneVerified,
      isRecoveringPassword: auth.isRecoveringPassword,
      path: state.matchedLocation,
      from: state.uri.queryParameters['from'],
    ),
    // Sign-in links are handled by Supabase, so an unknown path just goes home.
    onException: (context, state, router) => router.go(AppRoutes.dashboard),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => ChangeNotifierProvider(
                  create: (context) =>
                      HomeProvider(context.read<CatalogRepository>())..load(),
                  child: const DashboardScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.products,
                builder: (context, state) {
                  final categoryId = state.uri.queryParameters['category'];
                  return ChangeNotifierProvider(
                    create: (context) =>
                        ProductListProvider(
                            context.read<CatalogRepository>(),
                            filters: ProductFilters(categoryId: categoryId),
                          )
                          ..reload()
                          ..loadCategories(),
                    child: ProductsScreen(categoryId: categoryId),
                  );
                },
              ),
            ],
          ),
          _tab(AppRoutes.sales, const SalesScreen()),
          _tab(AppRoutes.statistics, const StatisticsScreen()),
        ],
      ),
      GoRoute(
        path: AppRoutes.post,
        builder: (context, state) {
          final editId = state.uri.queryParameters['edit'];
          return ChangeNotifierProvider(
            key: ValueKey(editId),
            create: (context) => ProductFormProvider(
              context.read<ListingRepository>(),
              context.read<CatalogRepository>(),
              context.read<ShopRepository>(),
              editId: editId,
            )..load(),
            child: PostScreen(
              backTo: _safeFrom(state.uri.queryParameters['from']),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.myPosts,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) =>
              MyListingsProvider(context.read<ListingRepository>())..load(),
          child: const MyPostsScreen(),
        ),
        routes: [
          GoRoute(
            path: 'shop',
            builder: (context, state) => ChangeNotifierProvider(
              create: (context) => ShopFormProvider(
                context.read<ShopRepository>(),
                context.read<AddressRepository>(),
              )..load(),
              child: const EditShopScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) =>
              ProductListProvider(context.read<CatalogRepository>()),
          child: const SearchScreen(),
        ),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ChangeNotifierProvider(
            key: ValueKey(id),
            create: (context) =>
                ProductDetailProvider(context.read<CatalogRepository>(), id)
                  ..load(),
            child: const ProductDetailScreen(),
          );
        },
      ),
      GoRoute(
        path: '/shop/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MultiProvider(
            key: ValueKey(id),
            providers: [
              ChangeNotifierProvider(
                create: (context) =>
                    ShopProvider(context.read<CatalogRepository>(), id)..load(),
              ),
              ChangeNotifierProvider(
                create: (context) => ProductListProvider(
                  context.read<CatalogRepository>(),
                  filters: ProductFilters(shopId: id),
                )..reload(),
              ),
            ],
            child: const ShopScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.wishlist,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) =>
              SavedProductsProvider(context.read<WishlistRepository>())
                ..reload(),
          child: const WishlistScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) => _checkout(null),
      ),
      // Not nested under checkout: going back from Buy Now must not open a
      // checkout for the whole cart.
      GoRoute(
        path: '${AppRoutes.checkout}/:variantId',
        builder: (context, state) =>
            _checkout(state.pathParameters['variantId']),
      ),
      GoRoute(
        path: AppRoutes.checkoutAddressForm,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) =>
              AddressFormProvider(context.read<AddressRepository>())
                ..loadRegions(),
          child: const AddressFormScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.orders,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) =>
              MyOrdersProvider(context.read<OrderRepository>())..load(),
          child: const MyOrdersScreen(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.orders}/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ChangeNotifierProvider(
            key: ValueKey(id),
            create: (context) =>
                OrderDetailProvider(context.read<OrderRepository>(), id)
                  ..load(),
            child: OrderDetailScreen(
              justPlaced: state.uri.queryParameters['placed'] == '1',
            ),
          );
        },
      ),
      _authRoute(
        AppRoutes.login,
        (state) => LoginScreen(from: state.uri.queryParameters['from']),
        routes: [
          _authRoute('sign-up', (state) => const SignUpScreen()),
          _authRoute(
            'forgot-password',
            (state) => const ForgotPasswordScreen(),
          ),
          _authRoute(
            'phone',
            (state) => const PhoneAuthScreen(linkToAccount: false),
          ),
        ],
      ),
      _authRoute(
        AppRoutes.resetPassword,
        (state) => const ResetPasswordScreen(),
      ),
      _authRoute(
        AppRoutes.verifyPhone,
        (state) => PhoneAuthScreen(
          linkToAccount: true,
          backTo: _safeFrom(state.uri.queryParameters['from']),
        ),
      ),
      _authRoute(
        AppRoutes.settings,
        (state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => const EditProfileScreen(),
          ),
          _authRoute('security', (state) => const AccountSecurityScreen()),
          GoRoute(
            path: 'addresses',
            builder: (context, state) => ChangeNotifierProvider(
              create: (context) =>
                  AddressesProvider(context.read<AddressRepository>())..load(),
              child: const AddressesScreen(),
            ),
            routes: [
              GoRoute(
                path: 'form',
                builder: (context, state) {
                  final existing = state.extra as Address?;
                  return ChangeNotifierProvider(
                    create: (context) => AddressFormProvider(
                      context.read<AddressRepository>(),
                      existing: existing,
                    )..loadRegions(),
                    child: AddressFormScreen(existing: existing),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

StatefulShellBranch _tab(String path, Widget screen) {
  return StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => screen)],
  );
}

Widget _checkout(String? buyNowVariantId) {
  return ChangeNotifierProvider(
    key: ValueKey(buyNowVariantId),
    create: (context) => CheckoutProvider(
      context.read<CartRepository>(),
      context.read<OrderRepository>(),
      context.read<AddressRepository>(),
      buyNowVariantId: buyNowVariantId,
    )..load(),
    child: const CheckoutScreen(),
  );
}

String? _safeFrom(String? from) => _isInternalPath(from) ? from : null;

/// A screen with its own busy and error state for sign-in actions.
GoRoute _authRoute(
  String path,
  Widget Function(GoRouterState) screen, {
  List<RouteBase> routes = const [],
}) {
  return GoRoute(
    path: path,
    routes: routes,
    builder: (context, state) => ChangeNotifierProvider(
      create: (context) => AuthFormProvider(context.read<AuthRepository>()),
      child: screen(state),
    ),
  );
}

/// Decides where a user may go. Page protection here is only for user
/// experience; RLS and server functions are the real security.
@visibleForTesting
String? resolveRedirect({
  required bool isSignedIn,
  required bool isPhoneVerified,
  required bool isRecoveringPassword,
  required String path,
  String? from,
}) {
  if (isRecoveringPassword) {
    return path == AppRoutes.resetPassword ? null : AppRoutes.resetPassword;
  }
  if (path == AppRoutes.resetPassword) return AppRoutes.dashboard;

  if (!isSignedIn) {
    return AppRoutes.requiresSignIn(path)
        ? AppRoutes.withFrom(AppRoutes.login, path)
        : null;
  }

  if (AppRoutes.guestOnly.contains(path)) {
    return _isInternalPath(from) ? from : AppRoutes.dashboard;
  }
  if (path == AppRoutes.verifyPhone && isPhoneVerified) {
    return _isInternalPath(from) ? from : AppRoutes.dashboard;
  }
  if (AppRoutes.requiresVerifiedPhone(path) && !isPhoneVerified) {
    return AppRoutes.withFrom(AppRoutes.verifyPhone, path);
  }
  return null;
}

/// Rejects addresses such as `//example.com` that could leave the app.
bool _isInternalPath(String? path) {
  return path != null && path.startsWith('/') && !path.startsWith('//');
}
