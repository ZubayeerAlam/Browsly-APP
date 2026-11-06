import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/paging.dart';
import '../../core/errors/error_mapper.dart';

class SellerOwing {
  const SellerOwing({
    required this.sellerId,
    required this.shopName,
    required this.totalCharged,
    required this.totalPaid,
    required this.balance,
    this.phone,
    this.payoutNumber,
  });

  final String sellerId;
  final String shopName;
  final String? phone;
  final String? payoutNumber;
  final double totalCharged;
  final double totalPaid;
  final double balance;
}

class Settlement {
  const Settlement({
    required this.id,
    required this.shopName,
    required this.amount,
    required this.method,
    required this.reference,
    required this.recordedBy,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String shopName;
  final double amount;

  /// `bkash` or `bank`.
  final String method;
  final String reference;
  final String? note;
  final String recordedBy;
  final DateTime createdAt;
}

class SettlementInput {
  const SettlementInput({
    required this.amount,
    required this.method,
    required this.reference,
    this.note,
  });

  final double amount;
  final String method;
  final String reference;
  final String? note;
}

abstract interface class SettlementsRepository {
  Future<ItemPage<SellerOwing>> getSellersOwing({
    String? search,
    int offset = 0,
    int limit = 50,
  });

  Future<ItemPage<Settlement>> getSettlements({
    PageCursor? cursor,
    int limit = 30,
  });

  Future<void> record(String sellerId, SettlementInput input);
}

class SettlementsRepositoryImpl implements SettlementsRepository {
  const SettlementsRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<ItemPage<SellerOwing>> getSellersOwing({
    String? search,
    int offset = 0,
    int limit = 50,
  }) {
    return guardFailures(() async {
      // One extra row shows whether another page exists.
      final result = await _client.rpc<List<dynamic>>(
        'admin_list_sellers_owing',
        params: {'p_search': search, 'p_limit': limit + 1, 'p_offset': offset},
      );
      final rows = result.cast<Map<String, dynamic>>();
      final hasMore = rows.length > limit;
      return ItemPage(
        items: (hasMore ? rows.sublist(0, limit) : rows).map((row) {
          return SellerOwing(
            sellerId: row['seller_id'] as String,
            shopName: row['shop_name'] as String,
            phone: row['phone'] as String?,
            payoutNumber: row['payout_number'] as String?,
            totalCharged: parseMoney(row['total_charged']),
            totalPaid: parseMoney(row['total_paid']),
            balance: parseMoney(row['balance']),
          );
        }).toList(),
        // These pages count rows, because the order changes as sellers pay.
        next: hasMore ? PageCursor(key: '${offset + limit}', id: '') : null,
      );
    });
  }

  @override
  Future<ItemPage<Settlement>> getSettlements({
    PageCursor? cursor,
    int limit = 30,
  }) {
    return guardFailures(() async {
      final rows = await _client.rpc<List<dynamic>>(
        'admin_list_settlements',
        params: {
          'p_cursor_key': cursor?.key,
          'p_cursor_id': cursor?.id,
          'p_limit': limit + 1,
        },
      );
      return pageFromRows(rows, limit, (row) {
        return Settlement(
          id: row['id'] as String,
          shopName: row['shop_name'] as String,
          amount: parseMoney(row['amount']),
          method: row['method'] as String,
          reference: row['reference'] as String,
          note: row['note'] as String?,
          recordedBy: row['recorded_by_name'] as String,
          createdAt: parseTime(row['created_at']),
        );
      });
    });
  }

  @override
  Future<void> record(String sellerId, SettlementInput input) {
    return guardFailures(
      () => _client.rpc<String>(
        'admin_record_settlement',
        params: {
          'p_seller_id': sellerId,
          'p_amount': input.amount,
          'p_method': input.method,
          'p_reference': input.reference,
          'p_note': input.note,
        },
      ),
    );
  }
}
