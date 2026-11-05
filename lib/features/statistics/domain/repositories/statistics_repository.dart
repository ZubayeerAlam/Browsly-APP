import '../entities/seller_stats.dart';

abstract interface class StatisticsRepository {
  /// Null if the user has no shop.
  Future<SellerStats?> getStats(int days);

  /// Null if the user has no shop.
  Future<SellerDashboard?> getDashboard();

  /// Never fails: statistics must not get in the way of shopping.
  void track(AnalyticsEvent event, String productId);
}
