import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/paging.dart';
import '../../core/errors/error_mapper.dart';

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.isSuspended,
    required this.isAdmin,
    required this.commissionOwed,
    required this.joinedAt,
    this.email,
    this.phone,
    this.shopName,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final bool isSuspended;
  final bool isAdmin;
  final String? shopName;
  final double commissionOwed;
  final DateTime joinedAt;
}

abstract interface class UsersRepository {
  Future<ItemPage<AdminUser>> getUsers({
    String? search,
    PageCursor? cursor,
    int limit = 30,
  });

  /// Suspending a seller also turns off their shop, and needs a reason.
  Future<void> setSuspended(String userId, bool suspended, {String? reason});
}

class UsersRepositoryImpl implements UsersRepository {
  const UsersRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<ItemPage<AdminUser>> getUsers({
    String? search,
    PageCursor? cursor,
    int limit = 30,
  }) {
    return guardFailures(() async {
      final rows = await _client.rpc<List<dynamic>>(
        'admin_list_users',
        params: {
          'p_search': search,
          'p_cursor_key': cursor?.key,
          'p_cursor_id': cursor?.id,
          'p_limit': limit + 1,
        },
      );
      return pageFromRows(rows, limit, (row) {
        return AdminUser(
          id: row['id'] as String,
          name: row['full_name'] as String,
          email: row['email'] as String?,
          phone: row['phone'] as String?,
          isSuspended: row['status'] == 'suspended',
          isAdmin: row['is_admin'] as bool,
          shopName: row['shop_name'] as String?,
          commissionOwed: parseMoney(row['commission_owed']),
          joinedAt: parseTime(row['created_at']),
        );
      });
    });
  }

  @override
  Future<void> setSuspended(String userId, bool suspended, {String? reason}) {
    return guardFailures(
      () => _client.rpc<void>(
        'admin_set_user_status',
        params: {
          'p_user_id': userId,
          'p_status': suspended ? 'suspended' : 'active',
          'p_reason': reason,
        },
      ),
    );
  }
}
