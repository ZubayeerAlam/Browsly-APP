import 'dart:typed_data';

import '../../../catalog/domain/entities/shop.dart';

class ShopInput {
  const ShopInput({
    required this.name,
    required this.description,
    required this.regionId,
    required this.deliveryFee,
  });

  final String name;
  final String description;
  final String regionId;
  final double deliveryFee;
}

abstract interface class ShopRepository {
  /// Null until the user has opened a shop.
  Future<Shop?> getMyShop();

  /// Opens the shop and returns its ID. Doing this twice is harmless.
  Future<String> createShop(
    ShopInput input, {
    required String? payoutNumber,
    required bool acceptedTerms,
  });

  Future<void> updateShop(String shopId, ShopInput input);

  /// [jpegBytes] must come from `preparePhotoForUpload`.
  Future<void> updateLogo(String shopId, Uint8List jpegBytes);
}
