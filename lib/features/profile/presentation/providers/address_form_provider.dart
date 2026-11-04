import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/address.dart';
import '../../domain/entities/region.dart';
import '../../domain/repositories/address_repository.dart';

/// Loads the division and district choices, and saves one address.
class AddressFormProvider extends ChangeNotifier {
  AddressFormProvider(this._repository, {Address? existing})
    : _existingId = existing?.id,
      _divisionId = existing?.divisionId,
      _districtId = existing?.regionId;

  final AddressRepository _repository;
  final String? _existingId;
  ViewState<List<Region>> _regions = const ViewState.initial();
  String? _divisionId;
  String? _districtId;
  bool _isSaving = false;
  AppFailure? _saveFailure;
  bool _isDisposed = false;

  ViewState<List<Region>> get regions => _regions;
  String? get divisionId => _divisionId;
  String? get districtId => _districtId;
  bool get isSaving => _isSaving;
  AppFailure? get saveFailure => _saveFailure;

  List<Region> get divisions =>
      (_regions.data ?? const <Region>[]).where((r) => r.isDivision).toList();

  List<Region> get districts => (_regions.data ?? const <Region>[])
      .where((r) => r.parentId != null && r.parentId == _divisionId)
      .toList();

  Future<void> loadRegions() async {
    _regions = const ViewState.loading();
    notifyListeners();
    try {
      _regions = ViewState.success(await _repository.getRegions());
    } on AppFailure catch (failure) {
      _regions = ViewState.error(failure);
    }
    notifyListeners();
  }

  void selectDivision(String? id) {
    if (id == _divisionId) return;
    _divisionId = id;
    _districtId = null;
    notifyListeners();
  }

  void selectDistrict(String? id) {
    _districtId = id;
    notifyListeners();
  }

  Future<bool> save({
    required String recipientName,
    required String phone,
    required String line1,
    String? postalCode,
  }) async {
    final districtId = _districtId;
    if (districtId == null || _isSaving) return false;
    _isSaving = true;
    _saveFailure = null;
    notifyListeners();
    final input = AddressInput(
      recipientName: recipientName,
      phone: phone,
      regionId: districtId,
      line1: line1,
      postalCode: postalCode,
    );
    try {
      final existingId = _existingId;
      if (existingId == null) {
        await _repository.createAddress(input);
      } else {
        await _repository.updateAddress(existingId, input);
      }
      return true;
    } on AppFailure catch (failure) {
      _saveFailure = failure;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
