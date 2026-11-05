import 'package:supabase_flutter/supabase_flutter.dart';

class AddressRemoteDataSource {
  const AddressRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchAddresses(String selectColumns) {
    return _client
        .from('addresses')
        .select(selectColumns)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> fetchRegions() {
    return _client
        .from('regions')
        .select('id, name, parent_id')
        .eq('country_code', 'BD')
        .inFilter('level', ['division', 'district'])
        // The client sorts newest-style (descending) unless told otherwise.
        .order('name', ascending: true);
  }

  Future<void> insertAddress(Map<String, dynamic> values) {
    return _client.from('addresses').insert(values);
  }

  Future<void> updateAddress(String id, Map<String, dynamic> values) {
    return _client.from('addresses').update(values).eq('id', id);
  }

  Future<void> deleteAddress(String id) {
    return _client.from('addresses').delete().eq('id', id);
  }

  Future<void> setDefaultAddress(String id) {
    return _client.rpc<void>(
      'set_default_address',
      params: {'p_address_id': id},
    );
  }
}
