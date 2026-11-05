class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.productCount,
    this.parentId,
  });

  final String id;
  final String? parentId;
  final String name;

  /// A short icon name stored with the category, such as `devices`.
  final String icon;

  /// Live products, including those in subcategories.
  final int productCount;

  bool get isTopLevel => parentId == null;
}
