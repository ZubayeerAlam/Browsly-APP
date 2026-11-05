import 'dart:async';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_filters.dart';
import '../../domain/repositories/catalog_repository.dart';
import 'paged_products_provider.dart';

/// Browsing, searching and filtering the marketplace.
class ProductListProvider extends PagedProductsProvider {
  ProductListProvider(
    this._repository, {
    this._filters = const ProductFilters(),
    this.searchDelay = const Duration(milliseconds: 400),
  });

  final CatalogRepository _repository;

  /// Waits for a pause in typing, so each letter doesn't call the server.
  final Duration searchDelay;

  ProductFilters _filters;
  List<Category> _categories = const [];
  Timer? _searchTimer;

  ProductFilters get filters => _filters;

  /// Top-level categories for the chips.
  List<Category> get categories => _categories;

  /// The count for the All chip.
  int get totalProductCount =>
      _categories.fold(0, (total, category) => total + category.productCount);

  @override
  Future<ProductPage> fetchPage(ProductCursor? cursor) {
    return _repository.searchProducts(_filters, cursor: cursor);
  }

  /// Without chips the list still works, so a failure here isn't an error.
  Future<void> loadCategories() async {
    try {
      final all = await _repository.getCategories();
      _categories = all.where((category) => category.isTopLevel).toList();
      notifyListeners();
    } on AppFailure {
      // The chips are simply hidden until the next refresh.
    }
  }

  Future<void> refresh() {
    return Future.wait([reload(keepList: true), loadCategories()]);
  }

  Future<void> setCategory(String? categoryId) {
    if (categoryId == _filters.categoryId) return Future.value();
    _filters = _filters.withCategory(categoryId);
    return reload();
  }

  Future<void> applyFilters(ProductFilters filters) {
    _filters = filters;
    return reload();
  }

  /// For the search screen: nothing is listed until something has been typed.
  void setQuery(String text) {
    final query = text.trim();
    _searchTimer?.cancel();
    if (query == (_filters.query ?? '')) return;
    _filters = _filters.withQuery(query.isEmpty ? null : query);
    if (query.isEmpty) {
      clear();
      return;
    }
    _searchTimer = Timer(searchDelay, reload);
  }

  /// Keeps the search list empty until a query exists.
  Future<void> applySearchFilters(ProductFilters filters) {
    _filters = filters;
    if (!_filters.hasQuery) return Future.value();
    return reload();
  }

  bool get isSearchIdle =>
      !_filters.hasQuery && state.status == ViewStatus.initial;

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}
