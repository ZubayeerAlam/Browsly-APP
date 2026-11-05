enum ProductSort { newest, popular, priceLow, priceHigh, rating, relevance }

enum ProductConditionFilter { isNew, used }

/// What a product list is showing.
class ProductFilters {
  const ProductFilters({
    this.query,
    this.categoryId,
    this.shopId,
    this.minPrice,
    this.maxPrice,
    this.condition,
    this.minRating,
    this.inStockOnly = false,
    this.sort,
  });

  final String? query;
  final String? categoryId;
  final String? shopId;
  final double? minPrice;
  final double? maxPrice;
  final ProductConditionFilter? condition;
  final double? minRating;
  final bool inStockOnly;

  /// Null means the default for this list.
  final ProductSort? sort;

  bool get hasQuery => query != null && query!.isNotEmpty;

  /// A search shows the best matches first. Everything else shows newest first.
  ProductSort get effectiveSort =>
      sort ?? (hasQuery ? ProductSort.relevance : ProductSort.newest);

  /// How many choices from the filter sheet are in use.
  int get refinementCount => [
    minPrice != null || maxPrice != null,
    condition != null,
    minRating != null,
    inStockOnly,
    sort != null,
  ].where((isUsed) => isUsed).length;

  ProductFilters withQuery(String? query) => ProductFilters(
    query: query,
    categoryId: categoryId,
    shopId: shopId,
    minPrice: minPrice,
    maxPrice: maxPrice,
    condition: condition,
    minRating: minRating,
    inStockOnly: inStockOnly,
    sort: sort,
  );

  ProductFilters withCategory(String? categoryId) => ProductFilters(
    query: query,
    categoryId: categoryId,
    shopId: shopId,
    minPrice: minPrice,
    maxPrice: maxPrice,
    condition: condition,
    minRating: minRating,
    inStockOnly: inStockOnly,
    sort: sort,
  );

  /// Replaces the filter sheet's choices and keeps the rest.
  ProductFilters withRefinements({
    double? minPrice,
    double? maxPrice,
    ProductConditionFilter? condition,
    double? minRating,
    bool inStockOnly = false,
    ProductSort? sort,
  }) => ProductFilters(
    query: query,
    categoryId: categoryId,
    shopId: shopId,
    minPrice: minPrice,
    maxPrice: maxPrice,
    condition: condition,
    minRating: minRating,
    inStockOnly: inStockOnly,
    sort: sort,
  );
}
