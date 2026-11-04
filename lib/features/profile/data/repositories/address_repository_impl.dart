import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/address.dart';
import '../../domain/entities/region.dart';
import '../../domain/repositories/address_repository.dart';
import '../datasources/address_remote_data_source.dart';
import '../models/address_model.dart';

class AddressRepositoryImpl implements AddressRepository {
  const AddressRepositoryImpl(this._dataSource);

  final AddressRemoteDataSource _dataSource;

  @override
  Future<List<Address>> getAddresses() {
    return guardFailures(() async {
      final rows = await _dataSource.fetchAddresses(AddressModel.selectColumns);
      return rows.map(AddressModel.fromJson).toList();
    });
  }

  @override
  Future<List<Region>> getRegions() {
    return guardFailures(() async {
      final rows = await _dataSource.fetchRegions();
      return rows.map(RegionModel.fromJson).toList();
    });
  }

  @override
  Future<void> createAddress(AddressInput input) {
    return guardFailures(
      () => _dataSource.insertAddress(AddressModel.inputToJson(input)),
    );
  }

  @override
  Future<void> updateAddress(String id, AddressInput input) {
    return guardFailures(
      () => _dataSource.updateAddress(id, AddressModel.inputToJson(input)),
    );
  }

  @override
  Future<void> deleteAddress(String id) {
    return guardFailures(() => _dataSource.deleteAddress(id));
  }

  @override
  Future<void> setDefaultAddress(String id) {
    return guardFailures(() => _dataSource.setDefaultAddress(id));
  }
}
