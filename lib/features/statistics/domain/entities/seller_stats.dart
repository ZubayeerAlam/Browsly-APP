class DayStats {
  const DayStats({
    required this.day,
    required this.views,
    required this.clicks,
    required this.orders,
    required this.sales,
  });

  final DateTime day;
  final int views;
  final int clicks;
  final int orders;
  final double sales;
}

class TopProduct {
  const TopProduct({
    required this.id,
    required this.title,
    required this.views,
    required this.units,
    required this.sales,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String? imageUrl;
  final int views;
  final int units;
  final double sales;
}

class SellerStats {
  const SellerStats({
    required this.views,
    required this.clicks,
    required this.orders,
    required this.sales,
    required this.daily,
    required this.topProducts,
  });

  final int views;
  final int clicks;
  final int orders;
  final double sales;
  final List<DayStats> daily;
  final List<TopProduct> topProducts;

  /// Orders for every 100 product views. Null with no views to compare.
  double? get orderRate => views == 0 ? null : orders / views * 100;
}

/// The seller's card on the Dashboard.
class SellerDashboard {
  const SellerDashboard({
    required this.viewsToday,
    required this.clicksToday,
    required this.salesToday,
    required this.newOrders,
    required this.ratingAvg,
    required this.ratingCount,
    required this.lowStock,
    required this.amountOwed,
  });

  final int viewsToday;
  final int clicksToday;
  final double salesToday;
  final int newOrders;
  final double ratingAvg;
  final int ratingCount;
  final int lowStock;
  final double amountOwed;
}

enum AnalyticsEvent {
  view('view'),
  click('click'),
  cartAdd('cart_add');

  const AnalyticsEvent(this.dbName);

  final String dbName;
}
