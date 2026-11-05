import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/selling_errors.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/photo_preparer.dart';
import '../../../catalog/domain/entities/shop.dart';
import '../../../profile/domain/entities/region.dart';
import '../../../profile/domain/repositories/address_repository.dart';
import '../../domain/repositories/shop_repository.dart';

/// Opens a shop, or edits the one the seller already has.
class ShopFormProvider extends ChangeNotifier {
  ShopFormProvider(
    this._shops,
    this._addresses, {
    this._preparePhoto = _prepareLogo,
  });

  final ShopRepository _shops;
  final AddressRepository _addresses;
  final PhotoPreparer _preparePhoto;

  ViewState<List<Region>> _regions = const ViewState.initial();
  Shop? _existing;
  String? _divisionId;
  String? _districtId;
  Uint8List? _logo;
  bool _isSaving = false;
  String? _saveFailure;
  bool _isDisposed = false;

  static Future<Uint8List> _prepareLogo(Uint8List original) =>
      preparePhotoForUpload(original, maxSize: 400);

  ViewState<List<Region>> get regions => _regions;
  Shop? get existing => _existing;
  String? get divisionId => _divisionId;
  String? get districtId => _districtId;
  Uint8List? get logo => _logo;
  bool get isSaving => _isSaving;
  String? get saveFailure => _saveFailure;

  List<Region> get divisions =>
      (_regions.data ?? const <Region>[]).where((r) => r.isDivision).toList();

  List<Region> get districts => (_regions.data ?? const <Region>[])
      .where((r) => r.parentId != null && r.parentId == _divisionId)
      .toList();

  Future<void> load() async {
    _regions = const ViewState.loading();
    _notify();
    try {
      final regions = await _addresses.getRegions();
      final shop = await _shops.getMyShop();
      _existing = shop;
      _districtId = shop?.regionId;
      for (final region in regions) {
        if (region.id == shop?.regionId) _divisionId = region.parentId;
      }
      _regions = ViewState.success(regions);
    } on AppFailure catch (failure) {
      _regions = ViewState.error(failure);
    }
    _notify();
  }

  void selectDivision(String? id) {
    if (id == _divisionId) return;
    _divisionId = id;
    _districtId = null;
    _notify();
  }

  void selectDistrict(String? id) {
    _districtId = id;
    _notify();
  }

  /// Only the prepared photo is kept, so location data can never be uploaded.
  Future<void> setLogo(Uint8List original) async {
    try {
      _logo = await _preparePhoto(original);
      _saveFailure = null;
    } catch (_) {
      _saveFailure = 'We could not use that photo. Please try another.';
    }
    _notify();
  }

  /// Returns the shop's ID, or null if saving failed.
  Future<String?> save({
    required String name,
    required String description,
    required double deliveryFee,
    String? payoutNumber,
    bool acceptedTerms = false,
  }) async {
    final districtId = _districtId;
    if (districtId == null || _isSaving) return null;
    _isSaving = true;
    _saveFailure = null;
    _notify();
    final input = ShopInput(
      name: name,
      description: description,
      regionId: districtId,
      deliveryFee: deliveryFee,
    );
    try {
      final existing = _existing;
      final String shopId;
      if (existing == null) {
        shopId = await _shops.createShop(
          input,
          payoutNumber: payoutNumber,
          acceptedTerms: acceptedTerms,
        );
      } else {
        shopId = existing.id;
        await _shops.updateShop(shopId, input);
      }
      final logo = _logo;
      if (logo != null) await _shops.updateLogo(shopId, logo);
      return shopId;
    } on AppFailure catch (failure) {
      _saveFailure = sellingFailureMessage(failure);
      return null;
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
