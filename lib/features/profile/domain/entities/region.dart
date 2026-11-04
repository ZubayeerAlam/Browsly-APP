/// A division or district. Addresses point to a district.
class Region {
  const Region({required this.id, required this.name, this.parentId});

  final String id;
  final String name;

  /// The division a district belongs to. Null for a division.
  final String? parentId;

  bool get isDivision => parentId == null;
}
