import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/repositories/report_repository.dart';

class ReportRepositoryImpl implements ReportRepository {
  const ReportRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<void> submit(
    ReportTarget target,
    String targetId,
    ReportReason reason, {
    String? details,
  }) {
    return guardFailures(
      () => _client.rpc<void>(
        'submit_report',
        params: {
          'p_target_type': target.name,
          'p_target_id': targetId,
          'p_reason': reason.name,
          'p_details': details,
        },
      ),
    );
  }
}
