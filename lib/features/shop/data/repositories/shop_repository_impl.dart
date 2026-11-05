import 'dart:typed_data';

import '../../../../core/errors/error_mapper.dart';
import '../../../catalog/domain/entities/shop.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../domain/repositories/shop_repository.dart';
import '../datasources/shop_remote_data_source.dart';

class ShopRepositoryImpl implements ShopRepository {
  const ShopRepositoryImpl(this._dataSource, this._catalog);

  final ShopRemoteDataSource _dataSource;
  final CatalogRepository _catalog;

  @override
  Future<Shop?> getMyShop() {
    return guardFailures(() async {
      final id = await _dataSource.fetchMyShopId();
      return id == null ? null : _catalog.getShop(id);
    });
  }

  @override
  Future<String> createShop(
    ShopInput input, {
    required String? payoutNumber,
    required bool acceptedTerms,
  }) {
    return guardFailures(
      () => _dataSource.createShop({
        'p_name': input.name,
        'p_description': input.description,
        'p_region_id': input.regionId,
        'p_delivery_fee': input.deliveryFee,
        'p_payout_number': payoutNumber,
        'p_accept_terms': acceptedTerms,
      }),
    );
  }

  @override
  Future<void> updateShop(String shopId, ShopInput input) {
    return guardFailures(
      () => _dataSource.updateShop(shopId, {
        'name': input.name,
        'description': input.description,
        'region_id': input.regionId,
        'delivery_fee': input.deliveryFee,
      }),
    );
  }

  @override
  Future<void> updateLogo(String shopId, Uint8List jpegBytes) {
    return guardFailures(() async {
      final oldPath = await _dataSource.fetchLogoPath(shopId);
      // A new name each time means image caches never show the old logo.
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$shopId/logo-$timestamp.jpg';
      await _dataSource.uploadLogo(path, jpegBytes);
      await _dataSource.updateShop(shopId, {'logo_path': path});
      if (oldPath != null) {
        // The new logo is already saved, so a leftover file is harmless.
        await _dataSource.removeLogo(oldPath).catchError((Object _) {});
      }
    });
  }
}
