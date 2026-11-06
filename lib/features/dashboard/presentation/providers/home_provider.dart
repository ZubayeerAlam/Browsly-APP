import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../../catalog/domain/entities/category.dart';
import '../../../catalog/domain/entities/home_banner.dart';
import '../../../catalog/domain/entities/product.dart';
import '../../../catalog/domain/entities/product_filters.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';

class HomeContent {
  const HomeContent({
    required this.categories,
    required this.popular,
    required this.newest,
    this.banners = const [],
  });

  final List<Category> categories;
  final List<ProductSummary> popular;
  final List<ProductSummary> newest;
  final List<HomeBanner> banners;
}

class HomeProvider extends ChangeNotifier {
  HomeProvider(this._repository);

  static const _sectionSize = 8;

  final CatalogRepository _repository;
  ViewState<HomeContent> _state = const ViewState.initial();
  bool _isDisposed = false;

  ViewState<HomeContent> get state => _state;

  Future<void> load() async {
    _state = ViewState.loading(data: _state.data);
    _notify();
    try {
      final categories = _repository.getCategories();
      // Banners are extra, so the home screen still opens without them.
      final banners = _repository.getBanners().catchError(
        (Object _) => const <HomeBanner>[],
        test: (error) => error is AppFailure,
      );
      final popular = _repository.searchProducts(
        const ProductFilters(sort: ProductSort.popular),
        limit: _sectionSize,
      );
      final newest = _repository.searchProducts(
        const ProductFilters(),
        limit: _sectionSize,
      );
      // Waits on all three, so when several fail every error is handled.
      await Future.wait([categories, popular, newest, banners]);
      _state = ViewState.success(
        HomeContent(
          categories: (await categories)
              .where((category) => category.isTopLevel)
              .toList(),
          popular: (await popular).items,
          newest: (await newest).items,
          banners: await banners,
        ),
      );
    } on AppFailure catch (failure) {
      _state = ViewState.error(failure, data: _state.data);
    }
    _notify();
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
