import '../../domain/entities/address.dart';
import '../../domain/entities/region.dart';

abstract final class AddressModel {
  /// The columns [fromJson] needs, including the district and its division.
  /// `division:parent_id` follows the link up to the parent. Writing
  /// `regions!parent_id` here would return the district's children instead.
  static const selectColumns =
      '*, district:regions!region_id(name, division:parent_id(id, name))';

  static Address fromJson(Map<String, dynamic> json) {
    final district = json['district'] as Map<String, dynamic>;
    final division = district['division'] as Map<String, dynamic>;
    return Address(
      id: json['id'] as String,
      recipientName: json['recipient_name'] as String,
      phone: json['phone'] as String,
      regionId: json['region_id'] as String,
      districtName: district['name'] as String,
      divisionId: division['id'] as String,
      divisionName: division['name'] as String,
      line1: json['line1'] as String,
      postalCode: json['postal_code'] as String?,
      isDefault: json['is_default'] as bool,
    );
  }

  static Map<String, dynamic> inputToJson(AddressInput input) {
    return {
      'recipient_name': input.recipientName,
      'phone': input.phone,
      'region_id': input.regionId,
      'line1': input.line1,
      'postal_code': input.postalCode,
    };
  }
}

abstract final class RegionModel {
  static Region fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parent_id'] as String?,
    );
  }
}
