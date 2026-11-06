import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/paging.dart';
import '../../core/errors/error_mapper.dart';

enum ReportFilter { open, resolved, dismissed }

class AdminReport {
  const AdminReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.details,
    required this.reporterName,
    required this.createdAt,
    required this.isOpen,
    this.targetText,
    this.targetUserId,
    this.resolutionNote,
  });

  final String id;

  /// `product`, `shop`, `review` or `message`.
  final String targetType;
  final String targetId;
  final String reason;
  final String details;
  final String reporterName;
  final DateTime createdAt;
  final bool isOpen;

  /// What was reported. Null if it has since gone.
  final String? targetText;

  /// The account behind it, for suspending if needed.
  final String? targetUserId;
  final String? resolutionNote;
}

abstract interface class ReportsRepository {
  Future<ItemPage<AdminReport>> getReports(
    ReportFilter filter, {
    PageCursor? cursor,
    int limit = 30,
  });

  Future<void> close(String reportId, {required bool upheld, String? note});

  Future<void> removeProduct(String productId, String reason);

  Future<void> hideReview(String reviewId);

  Future<void> suspendUser(String userId, String reason);
}

class ReportsRepositoryImpl implements ReportsRepository {
  const ReportsRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<ItemPage<AdminReport>> getReports(
    ReportFilter filter, {
    PageCursor? cursor,
    int limit = 30,
  }) {
    return guardFailures(() async {
      final rows = await _client.rpc<List<dynamic>>(
        'admin_list_reports',
        params: {
          'p_status': filter.name,
          'p_cursor_key': cursor?.key,
          'p_cursor_id': cursor?.id,
          'p_limit': limit + 1,
        },
      );
      return pageFromRows(rows, limit, (row) {
        return AdminReport(
          id: row['id'] as String,
          targetType: row['target_type'] as String,
          targetId: row['target_id'] as String,
          reason: row['reason'] as String,
          details: row['details'] as String,
          reporterName: row['reporter_name'] as String,
          createdAt: parseTime(row['created_at']),
          isOpen: row['status'] == 'open',
          targetText: row['target_text'] as String?,
          targetUserId: row['target_user_id'] as String?,
          resolutionNote: row['resolution_note'] as String?,
        );
      });
    });
  }

  @override
  Future<void> close(String reportId, {required bool upheld, String? note}) {
    return guardFailures(
      () => _client.rpc<void>(
        'admin_resolve_report',
        params: {
          'p_report_id': reportId,
          'p_status': upheld ? 'resolved' : 'dismissed',
          'p_note': note,
        },
      ),
    );
  }

  @override
  Future<void> removeProduct(String productId, String reason) {
    return guardFailures(
      () => _client.rpc<void>(
        'admin_set_product_removed',
        params: {
          'p_product_id': productId,
          'p_removed': true,
          'p_reason': reason,
        },
      ),
    );
  }

  @override
  Future<void> hideReview(String reviewId) {
    return guardFailures(
      () => _client.rpc<void>(
        'admin_set_review_hidden',
        params: {'p_review_id': reviewId, 'p_hidden': true},
      ),
    );
  }

  @override
  Future<void> suspendUser(String userId, String reason) {
    return guardFailures(
      () => _client.rpc<void>(
        'admin_set_user_status',
        params: {
          'p_user_id': userId,
          'p_status': 'suspended',
          'p_reason': reason,
        },
      ),
    );
  }
}
