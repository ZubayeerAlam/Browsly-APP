import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/seller_stats.dart';
import '../../domain/repositories/statistics_repository.dart';

class StatisticsRepositoryImpl implements StatisticsRepository {
  StatisticsRepositoryImpl(this._client);

  final SupabaseClient _client;

  /// A new ID each time the app starts, with no link to who is using it.
  final String _sessionId = _newSessionId();

  static String _newSessionId() {
    final random = Random.secure();
    final hex = List.generate(32, (_) => random.nextInt(16).toRadixString(16));
    final text = hex.join();
    return '${text.substring(0, 8)}-${text.substring(8, 12)}-4'
        '${text.substring(13, 16)}-a${text.substring(17, 20)}-'
        '${text.substring(20)}';
  }

  static int _int(Object? value) => (value as num? ?? 0).toInt();
  static double _double(Object? value) => (value as num? ?? 0).toDouble();

  @override
  Future<SellerStats?> getStats(int days) {
    return guardFailures(() async {
      final json = await _client.rpc<Map<String, dynamic>?>(
        'get_seller_stats',
        params: {'p_days': days},
      );
      if (json == null) return null;
      final images = _client.storage.from('product-images');
      return SellerStats(
        views: _int(json['views']),
        clicks: _int(json['clicks']),
        orders: _int(json['orders']),
        sales: _double(json['sales']),
        daily: (json['daily'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(
              (row) => DayStats(
                day: DateTime.parse(row['day'] as String),
                views: _int(row['views']),
                clicks: _int(row['clicks']),
                orders: _int(row['orders']),
                sales: _double(row['sales']),
              ),
            )
            .toList(),
        topProducts: (json['top_products'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((row) {
              final path = row['image_path'] as String?;
              return TopProduct(
                id: row['id'] as String,
                title: row['title'] as String,
                imageUrl: path == null ? null : images.getPublicUrl(path),
                views: _int(row['views']),
                units: _int(row['units']),
                sales: _double(row['sales']),
              );
            })
            .toList(),
      );
    });
  }

  @override
  Future<SellerDashboard?> getDashboard() {
    return guardFailures(() async {
      final json = await _client.rpc<Map<String, dynamic>?>(
        'get_seller_dashboard',
      );
      if (json == null) return null;
      return SellerDashboard(
        viewsToday: _int(json['views_today']),
        clicksToday: _int(json['clicks_today']),
        salesToday: _double(json['sales_today']),
        newOrders: _int(json['new_orders']),
        ratingAvg: _double(json['rating_avg']),
        ratingCount: _int(json['rating_count']),
        lowStock: _int(json['low_stock']),
        amountOwed: _double(json['amount_owed']),
      );
    });
  }

  @override
  void track(AnalyticsEvent event, String productId) {
    unawaited(_send(event, productId));
  }

  Future<void> _send(AnalyticsEvent event, String productId) async {
    try {
      await _client.rpc<void>(
        'track_event',
        params: {
          'p_type': event.dbName,
          'p_product_id': productId,
          'p_session_id': _sessionId,
        },
      );
    } on Object {
      // See the note on the repository.
    }
  }
}
