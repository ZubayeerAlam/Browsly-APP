/// The percentage saved, or null when there is no real discount.
int? discountPercentOf(double price, double? compareAtPrice) {
  if (compareAtPrice == null || compareAtPrice <= price) return null;
  return ((compareAtPrice - price) / compareAtPrice * 100).round();
}

/// What a product card shows.
class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.title,
    required this.shopId,
    required this.shopName,
    required this.price,
    this.imageUrl,
    this.compareAtPrice,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.soldCount = 0,
    this.totalStock = 0,
  });

  final String id;
  final String title;
  final String shopId;
  final String shopName;
  final String? imageUrl;
  final double price;
  final double? compareAtPrice;
  final double ratingAvg;
  final int ratingCount;
  final int soldCount;
  final int totalStock;

  bool get isInStock => totalStock > 0;
  int? get discountPercent => discountPercentOf(price, compareAtPrice);
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.price,
    required this.stock,
    this.colour,
    this.size,
    this.compareAtPrice,
  });

  final String id;
  final String? colour;
  final String? size;
  final double price;
  final double? compareAtPrice;
  final int stock;

  bool get isInStock => stock > 0;
  int? get discountPercent => discountPercentOf(price, compareAtPrice);
}

class ProductShop {
  const ProductShop({
    required this.id,
    required this.name,
    required this.deliveryFee,
    this.logoUrl,
    this.ratingAvg = 0,
    this.ratingCount = 0,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final double deliveryFee;
  final double ratingAvg;
  final int ratingCount;
}

class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.isNew,
    required this.shop,
    required this.imageUrls,
    required this.variants,
    this.categoryName,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.soldCount = 0,
  });

  final String id;
  final String title;
  final String description;
  final bool isNew;
  final ProductShop shop;
  final String? categoryName;
  final List<String> imageUrls;
  final List<ProductVariant> variants;
  final double ratingAvg;
  final int ratingCount;
  final int soldCount;
}

/// Where the next page starts. Comes from the server, and is never built here.
class ProductCursor {
  const ProductCursor({required this.key, required this.id});

  final String key;
  final String id;
}

class ProductPage {
  const ProductPage({required this.items, this.next});

  final List<ProductSummary> items;

  /// Null when this is the last page.
  final ProductCursor? next;
}
