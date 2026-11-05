abstract final class AppRoutes {
  static const dashboard = '/dashboard';
  static const products = '/products';
  static const sales = '/sales';
  static const statistics = '/statistics';
  static const post = '/post';

  static const search = '/search';
  static const wishlist = '/wishlist';
  static const myPosts = '/my-posts';
  static const editShop = '/my-posts/shop';

  /// The Post flow for an existing listing, returning to My Posts.
  static String editListing(String id) => Uri(
    path: post,
    queryParameters: {'edit': id, 'from': myPosts},
  ).toString();

  static String product(String id) => '/product/$id';
  static String shop(String id) => '/shop/$id';

  /// The Products tab, showing one category or all of them.
  static String productsIn(String? categoryId) => Uri(
    path: products,
    queryParameters: categoryId == null ? null : {'category': categoryId},
  ).toString();

  static const login = '/login';
  static const signUp = '/login/sign-up';
  static const forgotPassword = '/login/forgot-password';
  static const resetPassword = '/reset-password';
  static const phoneSignIn = '/login/phone';
  static const verifyPhone = '/verify-phone';

  static const settings = '/settings';
  static const editProfile = '/settings/profile';
  static const accountSecurity = '/settings/security';
  static const addresses = '/settings/addresses';
  static const addressForm = '/settings/addresses/form';

  /// Screens for guests. Signed-in users are sent onward.
  static const guestOnly = {login, signUp, forgotPassword, phoneSignIn};

  /// Screens that also need a verified phone, such as selling.
  static const phoneVerifiedOnly = {post};

  /// Screens guests cannot open.
  static bool requiresSignIn(String path) {
    return path == sales ||
        path == statistics ||
        path == post ||
        path == verifyPhone ||
        path == wishlist ||
        path == myPosts ||
        path.startsWith('$myPosts/') ||
        path == settings ||
        path.startsWith('$settings/');
  }

  /// Adds where the user was heading, so they can continue there afterwards.
  static String withFrom(String path, String? from) {
    return Uri(
      path: path,
      queryParameters: from == null ? null : {'from': from},
    ).toString();
  }
}
