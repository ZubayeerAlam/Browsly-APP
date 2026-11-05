import 'dart:async';
import 'dart:typed_data';

import 'package:browsly_app/app/app.dart';
import 'package:browsly_app/app/theme/app_theme.dart';
import 'package:browsly_app/core/config/app_config.dart';
import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/features/auth/domain/entities/auth_user.dart';
import 'package:browsly_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:browsly_app/features/catalog/domain/entities/category.dart';
import 'package:browsly_app/features/catalog/domain/entities/product.dart';
import 'package:browsly_app/features/catalog/domain/entities/product_filters.dart';
import 'package:browsly_app/features/catalog/domain/entities/shop.dart';
import 'package:browsly_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:browsly_app/features/profile/domain/entities/address.dart';
import 'package:browsly_app/features/profile/domain/entities/profile.dart';
import 'package:browsly_app/features/profile/domain/entities/region.dart';
import 'package:browsly_app/features/profile/domain/repositories/address_repository.dart';
import 'package:browsly_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:browsly_app/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const testUser = AuthUser(
  id: 'user-1',
  email: 'a@example.com',
  isPhoneVerified: false,
);
const verifiedUser = AuthUser(
  id: 'user-1',
  email: 'a@example.com',
  phone: '8801700000000',
  isPhoneVerified: true,
);

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? user}) : currentUser = user;

  final _users = StreamController<AuthUser?>.broadcast();
  final _recovery = StreamController<void>.broadcast();

  /// When set, every action fails with this.
  AppFailure? failWith;
  final List<String> calls = [];
  bool signUpNeedsConfirmation = true;

  @override
  AuthUser? currentUser;

  @override
  Stream<AuthUser?> get userChanges => _users.stream;

  @override
  Stream<void> get passwordRecoveryRequests => _recovery.stream;

  void emitUser(AuthUser? user) {
    currentUser = user;
    _users.add(user);
  }

  void emitPasswordRecovery() => _recovery.add(null);

  Future<void> _record(String call, [AuthUser? signsInAs]) async {
    calls.add(call);
    final failure = failWith;
    if (failure != null) throw failure;
    if (signsInAs != null) emitUser(signsInAs);
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _record('signIn:$email', testUser);

  @override
  Future<bool> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    await _record('signUp:$name:$email');
    return signUpNeedsConfirmation;
  }

  @override
  Future<void> sendPasswordReset(String email) => _record('reset:$email');

  @override
  Future<void> updatePassword(String password) => _record('updatePassword');

  @override
  Future<void> signInWithGoogle() => _record('google');

  @override
  Future<void> sendPhoneSignInCode(String phone) =>
      _record('phoneSignInCode:$phone');

  @override
  Future<void> verifyPhoneSignInCode({
    required String phone,
    required String code,
  }) => _record('phoneSignIn:$phone:$code', verifiedUser);

  @override
  Future<void> sendPhoneLinkCode(String phone) =>
      _record('phoneLinkCode:$phone');

  @override
  Future<void> verifyPhoneLinkCode({
    required String phone,
    required String code,
  }) => _record('phoneLink:$phone:$code', verifiedUser);

  @override
  Future<void> signOut() async {
    await _record('signOut');
    emitUser(null);
  }

  @override
  Future<void> deleteAccount() async {
    await _record('deleteAccount');
    emitUser(null);
  }
}

class FakeProfileRepository implements ProfileRepository {
  Profile profile = const Profile(id: 'user-1', fullName: 'Test User');
  AppFailure? failWith;
  int loads = 0;
  Uint8List? uploadedAvatar;

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<Profile> getProfile(String userId) async {
    loads++;
    _maybeFail();
    return Profile(id: userId, fullName: profile.fullName);
  }

  @override
  Future<void> updateName(String userId, String fullName) async {
    _maybeFail();
    profile = Profile(id: userId, fullName: fullName);
  }

  @override
  Future<void> updateAvatar(String userId, Uint8List jpegBytes) async {
    _maybeFail();
    uploadedAvatar = jpegBytes;
  }
}

class FakeAddressRepository implements AddressRepository {
  List<Address> addresses = [];
  AppFailure? failWith;
  AddressInput? lastInput;
  String? lastUpdatedId;
  String? lastDefaultId;
  String? lastDeletedId;

  static const regions = [
    Region(id: 'dhaka', name: 'Dhaka'),
    Region(id: 'sylhet', name: 'Sylhet'),
    Region(id: 'gazipur', name: 'Gazipur', parentId: 'dhaka'),
    Region(id: 'tangail', name: 'Tangail', parentId: 'dhaka'),
    Region(id: 'sunamganj', name: 'Sunamganj', parentId: 'sylhet'),
  ];

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<List<Address>> getAddresses() async {
    _maybeFail();
    return addresses;
  }

  @override
  Future<List<Region>> getRegions() async {
    _maybeFail();
    return regions;
  }

  @override
  Future<void> createAddress(AddressInput input) async {
    _maybeFail();
    lastInput = input;
  }

  @override
  Future<void> updateAddress(String id, AddressInput input) async {
    _maybeFail();
    lastUpdatedId = id;
    lastInput = input;
  }

  @override
  Future<void> deleteAddress(String id) async {
    _maybeFail();
    lastDeletedId = id;
  }

  @override
  Future<void> setDefaultAddress(String id) async {
    _maybeFail();
    lastDefaultId = id;
  }
}

ProductSummary testProduct(
  String id, {
  String? title,
  String shopId = 'shop-1',
  double price = 1000,
  double? compareAtPrice,
  int stock = 5,
}) {
  return ProductSummary(
    id: id,
    title: title ?? 'Product $id',
    shopId: shopId,
    shopName: 'Test Shop',
    price: price,
    compareAtPrice: compareAtPrice,
    totalStock: stock,
  );
}

ProductVariant testVariant(
  String id, {
  String? colour,
  String? size,
  double price = 1000,
  double? compareAtPrice,
  int stock = 5,
}) {
  return ProductVariant(
    id: id,
    colour: colour,
    size: size,
    price: price,
    compareAtPrice: compareAtPrice,
    stock: stock,
  );
}

ProductDetail testDetail(
  String id, {
  List<ProductVariant>? variants,
  List<String> imageUrls = const [],
}) {
  return ProductDetail(
    id: id,
    title: 'Product $id',
    description: 'About product $id',
    isNew: true,
    imageUrls: imageUrls,
    variants: variants ?? [testVariant('$id-default')],
    shop: const ProductShop(id: 'shop-1', name: 'Test Shop', deliveryFee: 60),
  );
}

/// An in-memory catalog with cursor paging like the server's.
class FakeCatalogRepository implements CatalogRepository {
  List<ProductSummary> products = [];
  List<Category> categories = [];
  final Map<String, ProductDetail> details = {};
  final Map<String, String> categoryOf = {};
  Shop? shop;
  AppFailure? failWith;
  final List<ProductFilters> searches = [];

  /// When set, the next search waits for this, to test slow responses.
  Future<void>? searchGate;

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<List<Category>> getCategories() async {
    _maybeFail();
    return categories;
  }

  @override
  Future<ProductPage> searchProducts(
    ProductFilters filters, {
    ProductCursor? cursor,
    int limit = 20,
  }) async {
    searches.add(filters);
    final gate = searchGate;
    searchGate = null;
    if (gate != null) await gate;
    _maybeFail();
    final query = filters.query?.toLowerCase();
    final matches = products.where((product) {
      return (query == null || product.title.toLowerCase().contains(query)) &&
          (filters.categoryId == null ||
              categoryOf[product.id] == filters.categoryId) &&
          (filters.shopId == null || product.shopId == filters.shopId);
    }).toList();
    return pageOf(matches, cursor, limit);
  }

  @override
  Future<ProductDetail?> getProduct(String id) async {
    _maybeFail();
    return details[id];
  }

  @override
  Future<Shop?> getShop(String id) async {
    _maybeFail();
    return shop;
  }
}

ProductPage pageOf(
  List<ProductSummary> items,
  ProductCursor? cursor,
  int limit,
) {
  final start = cursor == null ? 0 : int.parse(cursor.key);
  final end = start + limit;
  return ProductPage(
    items: items.sublist(start, end.clamp(0, items.length)),
    next: end < items.length ? ProductCursor(key: '$end', id: 'id') : null,
  );
}

class FakeWishlistRepository implements WishlistRepository {
  /// Everything the server considers saved, newest first.
  List<ProductSummary> saved = [];
  AppFailure? failWith;
  int writes = 0;

  /// When set, writes wait for this, to test taps while one is on its way.
  Future<void>? writeGate;

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<Set<String>> getSavedIds() async {
    _maybeFail();
    return saved.map((product) => product.id).toSet();
  }

  @override
  Future<void> add(String productId) async {
    writes++;
    if (writeGate != null) await writeGate;
    _maybeFail();
    saved = [testProduct(productId), ...saved];
  }

  @override
  Future<void> remove(String productId) async {
    writes++;
    if (writeGate != null) await writeGate;
    _maybeFail();
    saved = saved.where((product) => product.id != productId).toList();
  }

  @override
  Future<ProductPage> getPage({ProductCursor? cursor, int limit = 20}) async {
    _maybeFail();
    return pageOf(saved, cursor, limit);
  }
}

Future<void> pumpApp(
  WidgetTester tester, {
  required AuthRepository auth,
  ProfileRepository? profile,
  AddressRepository? addresses,
  CatalogRepository? catalog,
  WishlistRepository? wishlist,
}) async {
  await tester.pumpWidget(
    BrowslyApp(
      config: const AppConfig(
        supabaseUrl: 'test',
        supabasePublishableKey: 'test',
      ),
      authRepository: auth,
      profileRepository: profile ?? FakeProfileRepository(),
      addressRepository: addresses ?? FakeAddressRepository(),
      catalogRepository: catalog ?? FakeCatalogRepository(),
      wishlistRepository: wishlist ?? FakeWishlistRepository(),
      theme: AppTheme.light(baseTextTheme: ThemeData().textTheme),
    ),
  );
  await tester.pumpAndSettle();
}
