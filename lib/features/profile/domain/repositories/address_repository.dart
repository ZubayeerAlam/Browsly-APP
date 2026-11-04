import '../entities/address.dart';
import '../entities/region.dart';

abstract interface class AddressRepository {
  Future<List<Address>> getAddresses();

  /// All divisions and districts.
  Future<List<Region>> getRegions();

  Future<void> createAddress(AddressInput input);

  Future<void> updateAddress(String id, AddressInput input);

  Future<void> deleteAddress(String id);

  Future<void> setDefaultAddress(String id);
}
