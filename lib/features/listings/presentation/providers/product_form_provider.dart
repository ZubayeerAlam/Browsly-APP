import 'package:flutter/foundation.dart' show ChangeNotifier, Uint8List;

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/selling_errors.dart';
import '../../../../core/utils/photo_preparer.dart';
import '../../../catalog/domain/entities/category.dart';
import '../../../catalog/domain/repositories/catalog_repository.dart';
import '../../../shop/domain/repositories/shop_repository.dart';
import '../../domain/entities/listing.dart';
import '../../domain/repositories/listing_repository.dart';

/// One category choice in the form.
class CategoryChoice {
  const CategoryChoice({required this.id, required this.label});

  final String id;
  final String label;
}

/// One colour and size combination, with its own price and stock.
class VariantRow {
  VariantRow({this.colour, this.size, this.price, this.stock});

  final String? colour;
  final String? size;
  double? price;
  int? stock;

  String get label => [colour, size].whereType<String>().join(' / ');
}

enum FormLoadState { loading, ready, needsShop, notFound, failed }

/// The Post flow: photos and basics, description, colours and sizes, then
/// preview. It holds the whole listing across steps and saves drafts.
class ProductFormProvider extends ChangeNotifier {
  ProductFormProvider(
    this._listings,
    this._catalog,
    this._shops, {
    this.editId,
    this._preparePhoto = _prepareProductPhoto,
  });

  static const maxPhotos = 5;
  static const maxVariants = 50;
  static const minDescription = 10;
  static const stepCount = 4;

  final ListingRepository _listings;
  final CatalogRepository _catalog;
  final ShopRepository _shops;
  final String? editId;
  final PhotoPreparer _preparePhoto;

  FormLoadState _loadState = FormLoadState.loading;
  AppFailure? _loadFailure;
  String? _shopId;
  String? _productId;
  ListingStatus _status = ListingStatus.draft;
  List<CategoryChoice> _categories = const [];
  int _step = 0;

  final List<FormPhoto> _photos = [];
  final List<String> _pathsToRemove = [];
  String title = '';
  String description = '';
  String? categoryId;
  bool isNew = true;
  double? price;
  double? compareAtPrice;
  int? stock;
  final List<String> _colours = [];
  final List<String> _sizes = [];
  List<VariantRow> _rows = [];

  bool _isBusy = false;
  bool _isDirty = false;
  String? _failure;
  bool _isDisposed = false;

  static Future<Uint8List> _prepareProductPhoto(Uint8List original) =>
      preparePhotoForUpload(original, maxSize: 1200);

  FormLoadState get loadState => _loadState;
  AppFailure? get loadFailure => _loadFailure;
  ListingStatus get status => _status;
  bool get isEditing => editId != null;
  List<CategoryChoice> get categories => _categories;
  int get step => _step;
  List<FormPhoto> get photos => List.unmodifiable(_photos);
  List<String> get colours => List.unmodifiable(_colours);
  List<String> get sizes => List.unmodifiable(_sizes);
  List<VariantRow> get rows => List.unmodifiable(_rows);
  bool get hasOptions => _colours.isNotEmpty || _sizes.isNotEmpty;
  bool get isBusy => _isBusy;
  bool get isDirty => _isDirty;
  String? get failure => _failure;

  /// A live listing leaves the marketplace if its content changes.
  bool get warnsAboutReview =>
      _status == ListingStatus.active || _status == ListingStatus.paused;

  String? get categoryLabel {
    for (final choice in _categories) {
      if (choice.id == categoryId) return choice.label;
    }
    return null;
  }

  Future<void> load() async {
    _loadState = FormLoadState.loading;
    _loadFailure = null;
    _notify();
    try {
      final shop = await _shops.getMyShop();
      if (shop == null) {
        _loadState = FormLoadState.needsShop;
        _notify();
        return;
      }
      _shopId = shop.id;
      _categories = _choicesFrom(await _catalog.getCategories());
      final id = editId;
      if (id != null) {
        final listing = await _listings.getListing(id);
        if (listing == null) {
          _loadState = FormLoadState.notFound;
          _notify();
          return;
        }
        _fill(listing);
      }
      _loadState = FormLoadState.ready;
    } on AppFailure catch (failure) {
      _loadFailure = failure;
      _loadState = FormLoadState.failed;
    }
    _notify();
  }

  /// Sellers choose the most specific category, shown with its parent.
  static List<CategoryChoice> _choicesFrom(List<Category> all) {
    final byId = {for (final category in all) category.id: category};
    final parents = all.map((category) => category.parentId).toSet();
    return [
      for (final category in all)
        if (!parents.contains(category.id))
          CategoryChoice(
            id: category.id,
            label: category.parentId == null
                ? category.name
                : '${byId[category.parentId]?.name ?? ''} › ${category.name}',
          ),
    ]..sort((a, b) => a.label.compareTo(b.label));
  }

  void _fill(EditableListing listing) {
    _productId = listing.id;
    _status = listing.status;
    title = listing.title;
    description = listing.description;
    categoryId = listing.categoryId;
    isNew = listing.isNew;
    _photos
      ..clear()
      ..addAll(listing.photos.map(FormPhoto.stored));
    final variants = listing.variants;
    if (variants.isNotEmpty) {
      price = variants.first.price;
      stock = variants.first.stock;
      compareAtPrice = variants.first.compareAtPrice;
    }
    for (final variant in variants) {
      if (variant.colour != null && !_colours.contains(variant.colour)) {
        _colours.add(variant.colour!);
      }
      if (variant.size != null && !_sizes.contains(variant.size)) {
        _sizes.add(variant.size!);
      }
    }
    _rows = [
      for (final variant in variants)
        if (variant.colour != null || variant.size != null)
          VariantRow(
            colour: variant.colour,
            size: variant.size,
            price: variant.price,
            stock: variant.stock,
          ),
    ];
  }

  /// A plain field changed in the screen.
  void markDirty() {
    _isDirty = true;
    _failure = null;
  }

  void setCategory(String? id) {
    categoryId = id;
    markDirty();
    _notify();
  }

  void setIsNew(bool value) {
    isNew = value;
    markDirty();
    _notify();
  }

  void goToStep(int step) {
    _step = step.clamp(0, stepCount - 1);
    _failure = null;
    _notify();
  }

  /// Keeps only the prepared bytes, so a photo's location data never leaves the
  /// phone. If any photo can't be prepared, it is left out.
  Future<void> addPhotos(List<Uint8List> originals) async {
    final space = maxPhotos - _photos.length;
    if (space <= 0) return;
    var failed = originals.length > space;
    for (final original in originals.take(space)) {
      try {
        _photos.add(FormPhoto.prepared(await _preparePhoto(original)));
        _isDirty = true;
      } catch (_) {
        failed = true;
      }
    }
    _failure = failed
        ? 'Some photos were not added. A listing can have up to '
              '$maxPhotos JPG or PNG photos.'
        : null;
    _notify();
  }

  void removePhoto(FormPhoto photo) {
    _photos.remove(photo);
    final path = photo.path;
    // The file goes only after the listing no longer uses it.
    if (path != null) _pathsToRemove.add(path);
    markDirty();
    _notify();
  }

  void addColour(String value) => _addOption(_colours, value);
  void addSize(String value) => _addOption(_sizes, value);

  void removeColour(String value) {
    _colours.remove(value);
    _rebuildRows();
  }

  void removeSize(String value) {
    _sizes.remove(value);
    _rebuildRows();
  }

  void _addOption(List<String> options, String value) {
    final text = value.trim();
    if (text.isEmpty || text.length > 30) return;
    final isDuplicate = options.any(
      (option) => option.toLowerCase() == text.toLowerCase(),
    );
    if (isDuplicate) return;
    options.add(text);
    if (_comboCount > maxVariants) {
      options.removeLast();
      _failure = 'A listing can have up to $maxVariants combinations.';
      _notify();
      return;
    }
    _rebuildRows();
  }

  int get _comboCount =>
      (_colours.isEmpty ? 1 : _colours.length) *
      (_sizes.isEmpty ? 1 : _sizes.length);

  /// New combinations start from the main price and stock. Existing ones keep
  /// what the seller typed.
  void _rebuildRows() {
    final old = {for (final row in _rows) '${row.colour}|${row.size}': row};
    final colours = _colours.isEmpty ? <String?>[null] : _colours;
    final sizes = _sizes.isEmpty ? <String?>[null] : _sizes;
    _rows = hasOptions
        ? [
            for (final colour in colours)
              for (final size in sizes)
                old['$colour|$size'] ??
                    VariantRow(
                      colour: colour,
                      size: size,
                      price: price,
                      stock: stock,
                    ),
          ]
        : [];
    markDirty();
    _notify();
  }

  void setRowPrice(VariantRow row, double? value) {
    row.price = value;
    markDirty();
  }

  void setRowStock(VariantRow row, int? value) {
    row.stock = value;
    markDirty();
  }

  /// The checks each step needs before moving on.
  String? validateStep(int step) => switch (step) {
    0 => _photos.isEmpty ? 'Please add at least one photo.' : null,
    1 =>
      description.trim().length < minDescription
          ? 'Please write at least $minDescription characters.'
          : null,
    2 => _validateVariants(),
    _ => null,
  };

  String? _validateVariants() {
    if (!hasOptions) return null;
    for (final row in _rows) {
      final rowPrice = row.price;
      if (rowPrice == null || rowPrice <= 0) {
        return 'Please enter a price for ${row.label}.';
      }
      if (row.stock == null) return 'Please enter the stock for ${row.label}.';
    }
    return null;
  }

  List<ListingVariant> _variantsForSave() {
    if (!hasOptions) {
      return [
        ListingVariant(
          price: price!,
          stock: stock ?? 0,
          compareAtPrice: _compareFor(price!),
        ),
      ];
    }
    return [
      for (final row in _rows)
        ListingVariant(
          colour: row.colour,
          size: row.size,
          price: row.price!,
          stock: row.stock!,
          compareAtPrice: _compareFor(row.price!),
        ),
    ];
  }

  /// A discount is only shown where the original price really is higher.
  double? _compareFor(double variantPrice) {
    final compare = compareAtPrice;
    return compare != null && compare > variantPrice ? compare : null;
  }

  /// Saves without sending to review, except that the server re-reviews a live
  /// listing whose content changed.
  Future<bool> saveDraft() => _run(() async {
    await _save();
  });

  /// Saves, and sends a draft or rejected listing to review.
  Future<bool> submit() => _run(() async {
    for (var step = 0; step < stepCount; step++) {
      final problem = validateStep(step);
      if (problem != null) throw ValidationFailure(problem);
    }
    await _save();
    if (_status.isSubmittable) {
      await _listings.submitForReview(_productId!);
      _status = ListingStatus.inReview;
    }
  });

  Future<void> _save() async {
    final variantsProblem = _validateVariants();
    if (variantsProblem != null) throw ValidationFailure(variantsProblem);
    if (categoryId == null || price == null) {
      throw const ValidationFailure(
        'Please enter the name, category, price and stock first.',
      );
    }
    // A photo that uploaded before a failure keeps its path, so retrying
    // doesn't upload it again.
    for (final photo in _photos) {
      final bytes = photo.bytes;
      if (photo.path == null && bytes != null) {
        photo.path = await _listings.uploadPhoto(_shopId!, bytes);
      }
    }
    _productId = await _listings.save(
      ListingInput(
        id: _productId,
        title: title.trim(),
        description: description.trim(),
        categoryId: categoryId!,
        isNew: isNew,
        photoPaths: [for (final photo in _photos) photo.path!],
        variants: _variantsForSave(),
      ),
    );
    _isDirty = false;
    if (_pathsToRemove.isNotEmpty) {
      await _listings.removePhotos(List.of(_pathsToRemove));
      _pathsToRemove.clear();
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_isBusy) return false;
    _isBusy = true;
    _failure = null;
    _notify();
    try {
      await action();
      return true;
    } on AppFailure catch (failure) {
      _failure = sellingFailureMessage(failure);
      return false;
    } finally {
      _isBusy = false;
      _notify();
    }
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
