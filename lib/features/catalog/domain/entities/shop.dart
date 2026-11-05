class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.description,
    required this.deliveryFee,
    this.logoUrl,
    this.bannerUrl,
    this.regionId,
    this.regionName,
    this.ratingAvg = 0,
    this.ratingCount = 0,
  });

  final String id;
  final String name;
  final String description;
  final double deliveryFee;
  final String? logoUrl;
  final String? bannerUrl;
  final String? regionId;
  final String? regionName;
  final double ratingAvg;
  final int ratingCount;
}
