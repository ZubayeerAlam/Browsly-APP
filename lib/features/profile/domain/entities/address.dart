class Address {
  const Address({
    required this.id,
    required this.recipientName,
    required this.phone,
    required this.regionId,
    required this.districtName,
    required this.divisionId,
    required this.divisionName,
    required this.line1,
    required this.isDefault,
    this.postalCode,
  });

  final String id;
  final String recipientName;
  final String phone;
  final String regionId;
  final String districtName;
  final String divisionId;
  final String divisionName;
  final String line1;
  final String? postalCode;
  final bool isDefault;

  String get fullAddress {
    final area = '$districtName, $divisionName';
    return [line1, area, ?postalCode].join(', ');
  }
}

/// The fields a user fills in to add or change an address.
class AddressInput {
  const AddressInput({
    required this.recipientName,
    required this.phone,
    required this.regionId,
    required this.line1,
    this.postalCode,
  });

  final String recipientName;
  final String phone;
  final String regionId;
  final String line1;
  final String? postalCode;
}
