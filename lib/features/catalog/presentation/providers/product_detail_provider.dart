import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/catalog_repository.dart';

/// One product and the colour and size chosen on screen.
class ProductDetailProvider extends ChangeNotifier {
  ProductDetailProvider(this._repository, this.productId);

  final CatalogRepository _repository;
  final String productId;

  ViewState<ProductDetail> _state = const ViewState.initial();
  ProductVariant? _selected;
  bool _isDisposed = false;

  ViewState<ProductDetail> get state => _state;

  /// The variant whose price and stock are shown.
  ProductVariant? get selected => _selected;

  List<ProductVariant> get _variants => _state.data?.variants ?? const [];

  List<String> get colours => _unique(_variants.map((v) => v.colour));
  List<String> get sizes => _unique(_variants.map((v) => v.size));

  /// Whether a size exists for the chosen colour, so others can be disabled.
  bool isSizeOffered(String size) {
    final colour = _selected?.colour;
    return _variants.any((v) => v.size == size && v.colour == colour);
  }

  Future<void> load() async {
    _state = ViewState.loading(data: _state.data);
    _notify();
    try {
      final product = await _repository.getProduct(productId);
      if (product == null || product.variants.isEmpty) {
        _state = const ViewState.empty();
      } else {
        _state = ViewState.success(product);
        _selected =
            _keepSelection(product.variants) ??
            product.variants.firstWhere(
              (variant) => variant.isInStock,
              orElse: () => product.variants.first,
            );
      }
    } on AppFailure catch (failure) {
      _state = ViewState.error(failure, data: _state.data);
    }
    _notify();
  }

  ProductVariant? _keepSelection(List<ProductVariant> variants) {
    final id = _selected?.id;
    if (id == null) return null;
    for (final variant in variants) {
      if (variant.id == id) return variant;
    }
    return null;
  }

  /// Keeps the size if the new colour has it. Otherwise moves to that colour's
  /// first in-stock variant, so the screen never shows a combination that
  /// doesn't exist.
  void selectColour(String colour) {
    final matches = _variants.where((v) => v.colour == colour).toList();
    if (matches.isEmpty) return;
    final sameSize = matches.where((v) => v.size == _selected?.size);
    _selected = sameSize.isNotEmpty
        ? sameSize.first
        : matches.firstWhere((v) => v.isInStock, orElse: () => matches.first);
    _notify();
  }

  void selectSize(String size) {
    final colour = _selected?.colour;
    final matches = _variants.where(
      (v) => v.size == size && v.colour == colour,
    );
    if (matches.isEmpty) return;
    _selected = matches.first;
    _notify();
  }

  static List<String> _unique(Iterable<String?> values) {
    return values.whereType<String>().toSet().toList();
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
