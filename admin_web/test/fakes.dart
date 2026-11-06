import 'dart:async';
import 'dart:typed_data';

import 'package:browsly_admin/app/app.dart';
import 'package:browsly_admin/app/theme/app_theme.dart';
import 'package:browsly_admin/core/data/paging.dart';
import 'package:browsly_admin/core/errors/app_failure.dart';
import 'package:browsly_admin/features/auth/admin_auth.dart';
import 'package:browsly_admin/features/banners/banners_data.dart';
import 'package:browsly_admin/features/categories/categories_data.dart';
import 'package:browsly_admin/features/orders/orders_data.dart';
import 'package:browsly_admin/features/overview/overview_data.dart';
import 'package:browsly_admin/features/products/products_data.dart';
import 'package:browsly_admin/features/reports/reports_data.dart';
import 'package:browsly_admin/features/review/review_data.dart';
import 'package:browsly_admin/features/settings/settings_data.dart';
import 'package:browsly_admin/features/settlements/settlements_data.dart';
import 'package:browsly_admin/features/users/users_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuth implements AdminAuthRepository {
  FakeAuth({this.signedIn = false, this.admin = true});

  bool signedIn;
  bool admin;
  AppFailure? failSignIn;
  final _changes = StreamController<bool>.broadcast();

  @override
  bool get isSignedIn => signedIn;

  @override
  Stream<bool> get signedInChanges => _changes.stream;

  @override
  Future<void> signIn(String email, String password) async {
    final failure = failSignIn;
    if (failure != null) throw failure;
    signedIn = true;
    _changes.add(true);
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
    _changes.add(false);
  }

  @override
  Future<bool> isAdmin() async => admin;
}

class FakeOverview implements OverviewRepository {
  Overview overview = const Overview(
    reviewQueue: 3,
    openReports: 0,
    users: 12,
    sellers: 4,
    liveProducts: 22,
    openOrders: 5,
    ordersToday: 2,
    commissionOwed: 14.5,
  );

  @override
  Future<Overview> getOverview() async => overview;
}

QueuedProduct queued(String id, {String? decision = 'suspicious'}) {
  return QueuedProduct(
    id: id,
    title: 'Lamp $id',
    description: 'A lamp used for testing',
    isNew: true,
    shopName: 'Test Shop',
    categoryName: 'Home',
    price: 1000,
    totalStock: 3,
    imageUrls: const [],
    variantNames: const [],
    waitingSince: DateTime(2026, 11, 6),
    aiDecision: decision,
    reasonCode: decision == null ? null : 'PRICE',
    aiReason: decision == null ? null : 'Looks too cheap',
  );
}

class FakeReview implements ReviewRepository {
  List<QueuedProduct> queue = [];
  final List<String> decisions = [];
  AppFailure? failWith;

  @override
  Future<ItemPage<QueuedProduct>> getQueue({
    PageCursor? cursor,
    int limit = 20,
  }) async => ItemPage(items: queue);

  @override
  Future<void> approve(String productId) async {
    final failure = failWith;
    if (failure != null) throw failure;
    decisions.add('approve:$productId');
    queue = queue.where((item) => item.id != productId).toList();
  }

  @override
  Future<void> reject(String productId, String reason) async {
    decisions.add('reject:$productId:$reason');
    queue = queue.where((item) => item.id != productId).toList();
  }
}

class FakeUsers implements UsersRepository {
  List<AdminUser> users = [];
  final List<String> calls = [];
  final List<String?> searches = [];

  @override
  Future<ItemPage<AdminUser>> getUsers({
    String? search,
    PageCursor? cursor,
    int limit = 30,
  }) async {
    searches.add(search);
    return ItemPage(items: users);
  }

  @override
  Future<void> setSuspended(
    String userId,
    bool suspended, {
    String? reason,
  }) async {
    calls.add('$userId:$suspended:$reason');
  }
}

class FakeProducts implements ProductsRepository {
  List<AdminProduct> products = [];
  final List<String> calls = [];
  final List<String?> statuses = [];

  @override
  Future<ItemPage<AdminProduct>> getProducts({
    String? search,
    String? status,
    PageCursor? cursor,
    int limit = 30,
  }) async {
    statuses.add(status);
    return ItemPage(items: products);
  }

  @override
  Future<void> setRemoved(
    String productId,
    bool removed, {
    String? reason,
  }) async {
    calls.add('$productId:$removed:$reason');
  }
}

class FakeOrders implements OrdersRepository {
  List<AdminOrder> orders = [];

  @override
  Future<ItemPage<AdminOrder>> getOrders({
    String? search,
    String? status,
    PageCursor? cursor,
    int limit = 30,
  }) async => ItemPage(items: orders);
}

class FakeCategories implements CategoriesRepository {
  List<AdminCategory> categories = [];
  final List<CategoryInput> saved = [];
  AppFailure? failWith;

  @override
  Future<ItemPage<AdminCategory>> getCategories() async =>
      ItemPage(items: categories);

  @override
  Future<void> save(String? id, CategoryInput input) async {
    final failure = failWith;
    if (failure != null) throw failure;
    saved.add(input);
  }
}

class FakeSettings implements SettingsRepository {
  PlatformSettings settings = const PlatformSettings(
    commissionRate: 1,
    commissionBlockLimit: 5000,
    maxCodOrderValue: 50000,
  );
  PlatformSettings? updated;

  @override
  Future<PlatformSettings> getSettings() async => settings;

  @override
  Future<void> update(PlatformSettings settings) async {
    updated = settings;
  }
}

class FakeBanners implements BannersRepository {
  List<AdminBanner> banners = [];
  final List<String> deleted = [];

  @override
  Future<ItemPage<AdminBanner>> getBanners() async => ItemPage(items: banners);

  @override
  Future<String> uploadImage(Uint8List bytes, {required bool isPng}) async =>
      'a.jpg';

  @override
  Future<void> save(String? id, BannerInput input) async {}

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
  }
}

class FakeReports implements ReportsRepository {
  List<AdminReport> reports = [];
  final List<String> calls = [];

  @override
  Future<ItemPage<AdminReport>> getReports(
    ReportFilter filter, {
    PageCursor? cursor,
    int limit = 30,
  }) async {
    calls.add('list:${filter.name}');
    return ItemPage(items: reports);
  }

  @override
  Future<void> close(
    String reportId, {
    required bool upheld,
    String? note,
  }) async {
    calls.add('close:$reportId:$upheld:$note');
    reports = [];
  }

  @override
  Future<void> removeProduct(String productId, String reason) async {
    calls.add('removeProduct:$productId:$reason');
  }

  @override
  Future<void> hideReview(String reviewId) async {
    calls.add('hideReview:$reviewId');
  }

  @override
  Future<void> suspendUser(String userId, String reason) async {
    calls.add('suspend:$userId:$reason');
  }
}

class FakeSettlements implements SettlementsRepository {
  List<SellerOwing> owing = [];
  List<Settlement> history = [];
  final List<String> recorded = [];
  AppFailure? failWith;

  @override
  Future<ItemPage<SellerOwing>> getSellersOwing({
    String? search,
    int offset = 0,
    int limit = 50,
  }) async => ItemPage(items: owing);

  @override
  Future<ItemPage<Settlement>> getSettlements({
    PageCursor? cursor,
    int limit = 30,
  }) async => ItemPage(items: history);

  @override
  Future<void> record(String sellerId, SettlementInput input) async {
    final failure = failWith;
    if (failure != null) throw failure;
    recorded.add(
      '$sellerId:${input.amount}:${input.method}:${input.reference}',
    );
    owing = [];
  }
}

class Fakes {
  final auth = FakeAuth(signedIn: true);
  final overview = FakeOverview();
  final review = FakeReview();
  final users = FakeUsers();
  final products = FakeProducts();
  final orders = FakeOrders();
  final categories = FakeCategories();
  final settings = FakeSettings();
  final banners = FakeBanners();
  final reports = FakeReports();
  final settlements = FakeSettlements();

  AdminRepositories get repositories => AdminRepositories(
    auth: auth,
    overview: overview,
    review: review,
    users: users,
    products: products,
    orders: orders,
    categories: categories,
    settings: settings,
    banners: banners,
    reports: reports,
    settlements: settlements,
  );
}

/// Opens the panel on a wide window, as an admin uses it.
Future<void> pumpAdmin(WidgetTester tester, Fakes fakes) async {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AdminApp(
      repositories: fakes.repositories,
      theme: AppTheme.light(baseTextTheme: ThemeData().textTheme),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openPage(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}
