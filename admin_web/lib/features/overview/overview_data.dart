import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/paging.dart';
import '../../core/errors/error_mapper.dart';

class Overview {
  const Overview({
    required this.reviewQueue,
    required this.openReports,
    required this.users,
    required this.sellers,
    required this.liveProducts,
    required this.openOrders,
    required this.ordersToday,
    required this.commissionOwed,
  });

  final int reviewQueue;
  final int openReports;
  final int users;
  final int sellers;
  final int liveProducts;
  final int openOrders;
  final int ordersToday;
  final double commissionOwed;
}

abstract interface class OverviewRepository {
  Future<Overview> getOverview();
}

class OverviewRepositoryImpl implements OverviewRepository {
  const OverviewRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Overview> getOverview() {
    return guardFailures(() async {
      final json = await _client.rpc<Map<String, dynamic>>(
        'admin_get_overview',
      );
      int count(String key) => (json[key] as num).toInt();
      return Overview(
        reviewQueue: count('review_queue'),
        openReports: count('open_reports'),
        users: count('users'),
        sellers: count('sellers'),
        liveProducts: count('live_products'),
        openOrders: count('open_orders'),
        ordersToday: count('orders_today'),
        commissionOwed: parseMoney(json['commission_owed']),
      );
    });
  }
}
