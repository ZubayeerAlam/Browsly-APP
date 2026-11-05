import 'dart:async';
import 'dart:typed_data';

import 'package:browsly_app/app/app.dart';
import 'package:browsly_app/app/theme/app_theme.dart';
import 'package:browsly_app/core/config/app_config.dart';
import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/features/auth/domain/entities/auth_user.dart';
import 'package:browsly_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:browsly_app/features/cart/domain/entities/cart.dart';
import 'package:browsly_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:browsly_app/features/catalog/domain/entities/category.dart';
import 'package:browsly_app/features/catalog/domain/entities/product.dart';
import 'package:browsly_app/features/catalog/domain/entities/product_filters.dart';
import 'package:browsly_app/features/catalog/domain/entities/shop.dart';
import 'package:browsly_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:browsly_app/features/chat/domain/entities/chat.dart';
import 'package:browsly_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:browsly_app/features/listings/domain/entities/listing.dart';
import 'package:browsly_app/features/listings/domain/repositories/listing_repository.dart';
import 'package:browsly_app/features/notifications/domain/entities/app_notification.dart';
import 'package:browsly_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:browsly_app/features/orders/domain/entities/order.dart';
import 'package:browsly_app/features/orders/domain/repositories/order_repository.dart';
import 'package:browsly_app/features/profile/domain/entities/address.dart';
import 'package:browsly_app/features/profile/domain/entities/profile.dart';
import 'package:browsly_app/features/profile/domain/entities/region.dart';
import 'package:browsly_app/features/profile/domain/repositories/address_repository.dart';
import 'package:browsly_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:browsly_app/features/reports/domain/repositories/report_repository.dart';
import 'package:browsly_app/features/reviews/domain/entities/review.dart';
import 'package:browsly_app/features/reviews/domain/repositories/review_repository.dart';
import 'package:browsly_app/features/sales/domain/entities/sale.dart';
import 'package:browsly_app/features/sales/domain/repositories/sales_repository.dart';
import 'package:browsly_app/features/shop/domain/repositories/shop_repository.dart';
import 'package:browsly_app/features/statistics/domain/entities/seller_stats.dart';
import 'package:browsly_app/features/statistics/domain/repositories/statistics_repository.dart';
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

const testShop = Shop(
  id: 'shop-1',
  name: 'Test Shop',
  description: 'A shop for testing',
  deliveryFee: 60,
  regionId: 'gazipur',
  regionName: 'Gazipur',
);

class FakeShopRepository implements ShopRepository {
  FakeShopRepository({this.shop = testShop});

  Shop? shop;
  AppFailure? failWith;
  ShopInput? lastInput;
  bool? lastAcceptedTerms;
  Uint8List? uploadedLogo;
  int creates = 0;

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<Shop?> getMyShop() async {
    _maybeFail();
    return shop;
  }

  @override
  Future<String> createShop(
    ShopInput input, {
    required String? payoutNumber,
    required bool acceptedTerms,
  }) async {
    _maybeFail();
    creates++;
    lastInput = input;
    lastAcceptedTerms = acceptedTerms;
    shop = Shop(
      id: 'new-shop',
      name: input.name,
      description: input.description,
      deliveryFee: input.deliveryFee,
      regionId: input.regionId,
    );
    return 'new-shop';
  }

  @override
  Future<void> updateShop(String shopId, ShopInput input) async {
    _maybeFail();
    lastInput = input;
  }

  @override
  Future<void> updateLogo(String shopId, Uint8List jpegBytes) async {
    _maybeFail();
    uploadedLogo = jpegBytes;
  }
}

class FakeListingRepository implements ListingRepository {
  final List<ListingSummary> listings = [];
  final Map<String, EditableListing> editable = {};
  AppFailure? failWith;
  AppFailure? failSubmitWith;
  AppFailure? failUploadWith;
  final List<ListingInput> saves = [];
  final List<Uint8List> uploads = [];
  final List<String> submitted = [];
  final List<String> removedPaths = [];
  final List<String> deleted = [];
  final List<(String, bool)> pausedCalls = [];
  final List<ListingTab> tabsRequested = [];

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<ListingPage> getMyListings(
    ListingTab tab, {
    ListingCursor? cursor,
    int limit = 20,
  }) async {
    _maybeFail();
    tabsRequested.add(tab);
    final matches = listings.where((listing) {
      return switch (tab) {
        ListingTab.all => true,
        ListingTab.active =>
          listing.status == ListingStatus.active ||
              listing.status == ListingStatus.paused,
        ListingTab.inReview => listing.status == ListingStatus.inReview,
        ListingTab.draft => listing.status == ListingStatus.draft,
        ListingTab.rejected => listing.status == ListingStatus.rejected,
      };
    }).toList();
    final start = cursor == null ? 0 : int.parse(cursor.key);
    final end = start + limit;
    return ListingPage(
      items: matches.sublist(start, end.clamp(0, matches.length)),
      next: end < matches.length ? ListingCursor(key: '$end', id: 'id') : null,
    );
  }

  @override
  Future<EditableListing?> getListing(String id) async {
    _maybeFail();
    return editable[id];
  }

  @override
  Future<String> uploadPhoto(String shopId, Uint8List jpegBytes) async {
    final failure = failUploadWith;
    if (failure != null) throw failure;
    uploads.add(jpegBytes);
    return '$shopId/photo-${uploads.length}.jpg';
  }

  @override
  Future<String> save(ListingInput input) async {
    _maybeFail();
    saves.add(input);
    return input.id ?? 'new-listing';
  }

  @override
  Future<void> submitForReview(String id) async {
    final failure = failSubmitWith;
    if (failure != null) throw failure;
    submitted.add(id);
  }

  @override
  Future<void> setPaused(String id, {required bool paused}) async {
    _maybeFail();
    pausedCalls.add((id, paused));
  }

  @override
  Future<void> delete(String id) async {
    _maybeFail();
    deleted.add(id);
    listings.removeWhere((listing) => listing.id == id);
  }

  @override
  Future<void> removePhotos(List<String> paths) async {
    removedPaths.addAll(paths);
  }
}

/// One line of a test cart.
CartLine testCartLine(
  String id, {
  String title = 'Test Lamp',
  double price = 1000,
  int quantity = 1,
  int stock = 5,
  CartProblem? problem,
}) {
  return CartLine(
    variantId: id,
    productId: 'product-$id',
    title: title,
    unitPrice: price,
    quantity: quantity,
    stock: stock,
    problem: problem,
  );
}

/// One shop's worth of lines, with totals worked out like the server does.
Cart testCart(List<CartLine> lines, {double deliveryFee = 60}) {
  if (lines.isEmpty) return Cart.empty;
  final buyable = lines.where((line) => line.problem == null);
  final subtotal = buyable.fold<double>(0, (sum, l) => sum + l.lineTotal);
  final delivery = buyable.isEmpty ? 0.0 : deliveryFee;
  return Cart(
    shops: [
      CartShop(
        id: 'shop-1',
        name: 'Test Shop',
        deliveryFee: deliveryFee,
        subtotal: subtotal,
        lines: lines,
      ),
    ],
    subtotal: subtotal,
    deliveryTotal: delivery,
    grandTotal: subtotal + delivery,
    itemCount: lines.fold(0, (sum, line) => sum + line.quantity),
    canCheckout: lines.every((line) => line.problem == null),
  );
}

class FakeCartRepository implements CartRepository {
  List<CartLine> lines = [];
  AppFailure? failWith;
  Cart? buyNowCart;
  final List<String> calls = [];

  /// When set, writes wait for this, to test what shows while one is on its way.
  Future<void>? writeGate;

  Cart get _cart => testCart(lines);

  Future<void> _write(String call) async {
    calls.add(call);
    if (writeGate != null) await writeGate;
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<Cart> getCart() async {
    final failure = failWith;
    if (failure != null) throw failure;
    return _cart;
  }

  @override
  Future<Cart> getBuyNow(String variantId) async {
    calls.add('getBuyNow:$variantId');
    final failure = failWith;
    if (failure != null) throw failure;
    return buyNowCart ?? testCart([testCartLine(variantId)]);
  }

  @override
  Future<Cart> addVariant(String variantId) async {
    await _write('addVariant:$variantId');
    lines = [...lines, testCartLine(variantId)];
    return _cart;
  }

  @override
  Future<Cart> addProduct(String productId) async {
    await _write('addProduct:$productId');
    lines = [...lines, testCartLine('variant-of-$productId')];
    return _cart;
  }

  @override
  Future<Cart> setQuantity(String variantId, int quantity) async {
    await _write('setQuantity:$variantId:$quantity');
    lines = [
      for (final line in lines)
        if (line.variantId != variantId)
          line
        else if (quantity > 0)
          testCartLine(
            variantId,
            title: line.title,
            price: line.unitPrice,
            quantity: quantity,
            stock: line.stock,
          ),
    ];
    return _cart;
  }
}

OrderDetail testOrder({
  String id = 'order-1',
  OrderStatus status = OrderStatus.pending,
}) {
  return OrderDetail(
    id: id,
    orderNumber: 'BR-100001',
    subtotal: 1000,
    deliveryTotal: 60,
    grandTotal: 1060,
    createdAt: DateTime(2026, 11, 5),
    shippingAddress: const ShippingAddress(
      recipientName: 'Test Person',
      phone: '+8801700000000',
      line1: 'House 1',
      region: 'Gazipur, Dhaka',
    ),
    groups: [
      OrderGroup(
        id: 'group-1',
        shopId: 'shop-1',
        shopName: 'Test Shop',
        status: status,
        subtotal: 1000,
        deliveryFee: 60,
        items: const [
          OrderItem(
            id: 'item-1',
            title: 'Test Lamp',
            unitPrice: 1000,
            quantity: 1,
            lineTotal: 1000,
          ),
        ],
      ),
    ],
  );
}

class FakeOrderRepository implements OrderRepository {
  OrderDetail? order;
  List<OrderSummary> summaries = [];
  AppFailure? failWith;
  AppFailure? cancelFailure;
  final List<String> placeKeys = [];
  String? lastAddressId;
  double? lastExpectedTotal;
  String? lastBuyNowVariantId;
  String? lastCancelledGroupId;

  /// Runs when an order is placed, as the server emptying the cart.
  void Function()? onPlaced;

  @override
  Future<PlacedOrder> placeOrder({
    required String addressId,
    required String idempotencyKey,
    required double expectedTotal,
    String? buyNowVariantId,
  }) async {
    placeKeys.add(idempotencyKey);
    lastAddressId = addressId;
    lastExpectedTotal = expectedTotal;
    lastBuyNowVariantId = buyNowVariantId;
    final failure = failWith;
    if (failure != null) throw failure;
    onPlaced?.call();
    order ??= testOrder();
    return PlacedOrder(id: order!.id, orderNumber: order!.orderNumber);
  }

  @override
  Future<OrderPage> getMyOrders({OrderCursor? cursor, int limit = 20}) async {
    final failure = failWith;
    if (failure != null) throw failure;
    return OrderPage(items: summaries);
  }

  @override
  Future<OrderDetail?> getOrder(String id) async {
    final failure = failWith;
    if (failure != null) throw failure;
    return order;
  }

  @override
  Future<void> cancelGroup(String groupId) async {
    lastCancelledGroupId = groupId;
    final failure = cancelFailure;
    if (failure != null) throw failure;
    order = testOrder(status: OrderStatus.cancelled);
  }
}

SaleSummary testSale({
  String id = 'sale-1',
  OrderStatus status = OrderStatus.pending,
}) {
  return SaleSummary(
    id: id,
    orderNumber: 'BR-100001',
    status: status,
    amountToCollect: 1060,
    createdAt: DateTime(2026, 11, 5),
    recipientName: 'Test Person',
    itemCount: 1,
    firstTitle: 'Test Lamp',
  );
}

SaleDetail testSaleDetail({
  String id = 'sale-1',
  OrderStatus status = OrderStatus.pending,
}) {
  return SaleDetail(
    id: id,
    orderNumber: 'BR-100001',
    status: status,
    subtotal: 1000,
    deliveryFee: 60,
    commissionTotal: 10,
    createdAt: DateTime(2026, 11, 5),
    buyer: const ShippingAddress(
      recipientName: 'Test Person',
      phone: '+8801700000000',
      line1: 'House 1',
      region: 'Gazipur, Dhaka',
    ),
    items: const [
      OrderItem(
        id: 'item-1',
        title: 'Test Lamp',
        unitPrice: 1000,
        quantity: 1,
        lineTotal: 1000,
      ),
    ],
    history: [
      OrderStatusEvent(
        status: OrderStatus.pending,
        createdAt: DateTime(2026, 11, 5, 10),
      ),
    ],
  );
}

class FakeSalesRepository implements SalesRepository {
  /// Everything the server has, which the tabs filter by status.
  List<SaleSummary> sales = [];
  SaleDetail? sale;
  CommissionSummary summary = const CommissionSummary(
    balance: 0,
    totalCharged: 0,
    totalPaid: 0,
    commissionRate: 1,
    blockLimit: 5000,
    isBlocked: false,
  );
  List<CommissionEntry> entries = [];
  AppFailure? failWith;
  AppFailure? actionFailure;
  final List<String> calls = [];

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw failure;
  }

  static bool _inTab(OrderStatus status, SaleTab tab) {
    return switch (tab) {
      SaleTab.pending => status == OrderStatus.pending,
      SaleTab.packaging => status == OrderStatus.packaging,
      SaleTab.outForDelivery => status == OrderStatus.outForDelivery,
      SaleTab.completed => status == OrderStatus.completed,
      SaleTab.closed => status.isClosedWithoutPayment,
    };
  }

  @override
  Future<SalePage> getSales(
    SaleTab tab, {
    PageCursor? cursor,
    int limit = 20,
  }) async {
    _maybeFail();
    return SalePage(
      items: sales.where((sale) => _inTab(sale.status, tab)).toList(),
    );
  }

  @override
  Future<SaleDetail?> getSale(String id) async {
    _maybeFail();
    return sale;
  }

  void _moveTo(String id, OrderStatus status) {
    sale = testSaleDetail(id: id, status: status);
    sales = [
      for (final item in sales)
        item.id == id ? testSale(id: id, status: status) : item,
    ];
  }

  @override
  Future<void> setStatus(String id, OrderStatus status, {String? note}) async {
    calls.add('setStatus:$id:${status.name}:$note');
    final failure = actionFailure;
    if (failure != null) throw failure;
    _moveTo(id, status);
  }

  @override
  Future<void> cancel(String id, {String? reason}) async {
    calls.add('cancel:$id:$reason');
    final failure = actionFailure;
    if (failure != null) throw failure;
    _moveTo(id, OrderStatus.cancelled);
  }

  @override
  Future<CommissionSummary> getCommissionSummary() async {
    _maybeFail();
    return summary;
  }

  @override
  Future<CommissionPage> getCommissionEntries({
    PageCursor? cursor,
    int limit = 20,
  }) async {
    _maybeFail();
    return CommissionPage(items: entries);
  }
}

class FakeChatRepository implements ChatRepository {
  List<Conversation> conversations = [];
  ChatHeader? header = const ChatHeader(
    id: 'chat-1',
    otherName: 'Test Shop',
    productId: '1',
    productTitle: 'Test Lamp',
    productPrice: 1000,
  );
  List<ChatMessage> messages = [];
  AppFailure? failWith;
  final List<String> calls = [];
  final _incoming = StreamController<ChatMessage>.broadcast();

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw failure;
  }

  /// A message arriving live from the other person.
  void receive(ChatMessage message) => _incoming.add(message);

  @override
  Future<ConversationPage> getConversations({
    ConversationCursor? cursor,
    int limit = 20,
  }) async {
    _maybeFail();
    return ConversationPage(items: conversations);
  }

  @override
  Future<ChatHeader?> getHeader(String conversationId) async {
    _maybeFail();
    return header;
  }

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    DateTime? before,
    int limit = 30,
  }) async {
    _maybeFail();
    return before == null ? messages : [];
  }

  @override
  Future<ChatMessage> send(String conversationId, String body) async {
    calls.add('send:$body');
    _maybeFail();
    return ChatMessage(
      id: 'sent-${calls.length}',
      conversationId: conversationId,
      senderId: verifiedUser.id,
      body: body,
      createdAt: DateTime(2026, 11, 6, 12, calls.length),
    );
  }

  @override
  Future<void> markRead(String conversationId) async {
    calls.add('markRead');
  }

  @override
  Future<String> startForProduct(String productId) async {
    calls.add('startForProduct:$productId');
    _maybeFail();
    return 'chat-1';
  }

  @override
  Future<String> startForOrder(String groupId) async {
    calls.add('startForOrder:$groupId');
    _maybeFail();
    return 'chat-1';
  }

  @override
  Stream<ChatMessage> watchMessages(String conversationId) => _incoming.stream;
}

class FakeNotificationRepository implements NotificationRepository {
  List<AppNotification> items = [];
  UnreadCounts counts = const UnreadCounts();
  final List<String?> markedRead = [];
  final _incoming = StreamController<AppNotification>.broadcast();

  /// A notification arriving live.
  void receive(AppNotification notification) => _incoming.add(notification);

  @override
  Future<NotificationPage> getPage({DateTime? before, int limit = 20}) async {
    return NotificationPage(items: before == null ? items : const []);
  }

  @override
  Future<UnreadCounts> getUnreadCounts() async => counts;

  @override
  Future<void> markRead(String? id) async {
    markedRead.add(id);
  }

  @override
  Stream<AppNotification> watch(String userId) => _incoming.stream;
}

class FakeReviewRepository implements ReviewRepository {
  List<Review> reviews = [];
  AppFailure? failWith;
  final List<String> submitted = [];

  @override
  Future<ReviewPage> getReviews(
    String productId, {
    ReviewCursor? cursor,
    int limit = 20,
  }) async {
    return ReviewPage(items: cursor == null ? reviews : const []);
  }

  @override
  Future<void> submit(String orderItemId, int rating, {String? comment}) async {
    final failure = failWith;
    if (failure != null) throw failure;
    submitted.add('$orderItemId:$rating:$comment');
  }
}

class FakeReportRepository implements ReportRepository {
  final List<String> reports = [];
  AppFailure? failWith;

  @override
  Future<void> submit(
    ReportTarget target,
    String targetId,
    ReportReason reason, {
    String? details,
  }) async {
    final failure = failWith;
    if (failure != null) throw failure;
    reports.add('${target.name}:$targetId:${reason.name}:$details');
  }
}

class FakeStatisticsRepository implements StatisticsRepository {
  SellerStats? stats;
  SellerDashboard? dashboard;
  AppFailure? failWith;
  final List<String> tracked = [];
  final List<int> requestedDays = [];

  @override
  Future<SellerStats?> getStats(int days) async {
    requestedDays.add(days);
    final failure = failWith;
    if (failure != null) throw failure;
    return stats;
  }

  @override
  Future<SellerDashboard?> getDashboard() async {
    final failure = failWith;
    if (failure != null) throw failure;
    return dashboard;
  }

  @override
  void track(AnalyticsEvent event, String productId) {
    tracked.add('${event.name}:$productId');
  }
}

Future<void> pumpApp(
  WidgetTester tester, {
  required AuthRepository auth,
  ProfileRepository? profile,
  AddressRepository? addresses,
  CatalogRepository? catalog,
  WishlistRepository? wishlist,
  ShopRepository? shops,
  ListingRepository? listings,
  CartRepository? cart,
  OrderRepository? orders,
  SalesRepository? sales,
  ChatRepository? chat,
  NotificationRepository? notifications,
  ReviewRepository? reviews,
  ReportRepository? reports,
  StatisticsRepository? statistics,
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
      shopRepository: shops ?? FakeShopRepository(),
      listingRepository: listings ?? FakeListingRepository(),
      cartRepository: cart ?? FakeCartRepository(),
      orderRepository: orders ?? FakeOrderRepository(),
      salesRepository: sales ?? FakeSalesRepository(),
      chatRepository: chat ?? FakeChatRepository(),
      notificationRepository: notifications ?? FakeNotificationRepository(),
      reviewRepository: reviews ?? FakeReviewRepository(),
      reportRepository: reports ?? FakeReportRepository(),
      statisticsRepository: statistics ?? FakeStatisticsRepository(),
      theme: AppTheme.light(baseTextTheme: ThemeData().textTheme),
    ),
  );
  await tester.pumpAndSettle();
}
