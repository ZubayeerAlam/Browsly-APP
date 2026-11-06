import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/paging.dart';
import '../../core/errors/error_mapper.dart';

class PlatformSettings {
  const PlatformSettings({
    required this.commissionRate,
    required this.commissionBlockLimit,
    required this.maxCodOrderValue,
  });

  final double commissionRate;
  final double commissionBlockLimit;
  final double maxCodOrderValue;
}

abstract interface class SettingsRepository {
  Future<PlatformSettings> getSettings();
  Future<void> update(PlatformSettings settings);
}

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<PlatformSettings> getSettings() {
    return guardFailures(() async {
      final row = await _client
          .from('platform_settings')
          .select(
            'commission_rate, commission_block_limit, max_cod_order_value',
          )
          .eq('country_code', 'BD')
          .single();
      return PlatformSettings(
        commissionRate: parseMoney(row['commission_rate']),
        commissionBlockLimit: parseMoney(row['commission_block_limit']),
        maxCodOrderValue: parseMoney(row['max_cod_order_value']),
      );
    });
  }

  @override
  Future<void> update(PlatformSettings settings) {
    return guardFailures(
      () => _client.rpc<void>(
        'admin_update_settings',
        params: {
          'p_commission_rate': settings.commissionRate,
          'p_commission_block_limit': settings.commissionBlockLimit,
          'p_max_cod_order_value': settings.maxCodOrderValue,
        },
      ),
    );
  }
}
