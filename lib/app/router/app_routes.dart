abstract final class AppRoutes {
  static const dashboard = '/dashboard';
  static const products = '/products';
  static const sales = '/sales';
  static const statistics = '/statistics';
  static const post = '/post';
  static const login = '/login';

  /// Screens guests cannot open.
  static const signedInOnly = {sales, statistics, post};
}
