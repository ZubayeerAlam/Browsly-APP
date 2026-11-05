import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/core/state/view_state.dart';
import 'package:browsly_app/features/orders/presentation/providers/checkout_provider.dart';
import 'package:browsly_app/features/profile/domain/entities/address.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Address address(String id, {bool isDefault = false}) => Address(
  id: id,
  recipientName: 'Person $id',
  phone: '+8801700000000',
  regionId: 'gazipur',
  districtName: 'Gazipur',
  divisionId: 'dhaka',
  divisionName: 'Dhaka',
  line1: 'House 1',
  isDefault: isDefault,
);

void main() {
  late FakeCartRepository carts;
  late FakeOrderRepository orders;
  late FakeAddressRepository addresses;

  CheckoutProvider build({String? buyNow}) {
    return CheckoutProvider(carts, orders, addresses, buyNowVariantId: buyNow);
  }

  setUp(() {
    carts = FakeCartRepository()..lines = [testCartLine('v1')];
    orders = FakeOrderRepository();
    addresses = FakeAddressRepository()
      ..addresses = [address('a1'), address('a2', isDefault: true)];
  });

  test('starts with the default address and the server total', () async {
    final provider = build();
    await provider.load();

    expect(provider.selectedAddress!.id, 'a2');
    expect(provider.state.data!.grandTotal, 1060);
    expect(provider.canPlace, isTrue);
  });

  test('cannot place an order without an address', () async {
    addresses.addresses = [];
    final provider = build();
    await provider.load();

    expect(provider.canPlace, isFalse);
    expect(await provider.placeOrder(), isNull);
    expect(orders.placeKeys, isEmpty);
  });

  test('an empty cart shows the empty state', () async {
    carts.lines = [];
    final provider = build();
    await provider.load();

    expect(provider.state.status, ViewStatus.empty);
  });

  test('sends the chosen address and the total the buyer saw', () async {
    final provider = build();
    await provider.load();
    provider.selectAddress(addresses.addresses.first);

    final placed = await provider.placeOrder();

    expect(placed!.orderNumber, 'BR-100001');
    expect(orders.lastAddressId, 'a1');
    expect(orders.lastExpectedTotal, 1060);
    expect(orders.lastBuyNowVariantId, isNull);
  });

  test('Buy Now reads and orders only that item', () async {
    final provider = build(buyNow: 'v9');
    await provider.load();
    await provider.placeOrder();

    expect(carts.calls, contains('getBuyNow:v9'));
    expect(orders.lastBuyNowVariantId, 'v9');
  });

  test('retrying after a lost connection reuses the same key', () async {
    final provider = build();
    await provider.load();

    orders.failWith = const NetworkFailure();
    expect(await provider.placeOrder(), isNull);
    expect(provider.placeFailure, const NetworkFailure().message);

    orders.failWith = null;
    expect(await provider.placeOrder(), isNotNull);

    expect(orders.placeKeys, hasLength(2));
    expect(orders.placeKeys[0], orders.placeKeys[1]);
    expect(orders.placeKeys[0].length, inInclusiveRange(16, 64));
  });

  test('a clear refusal explains it, reloads and uses a new key', () async {
    final provider = build();
    await provider.load();

    orders.failWith = const ServerFailure('x', code: 'PRICE_CHANGED');
    carts.lines = [testCartLine('v1', price: 1200)];
    expect(await provider.placeOrder(), isNull);

    expect(provider.placeFailure, contains('check the new total'));
    expect(provider.state.data!.grandTotal, 1260);

    orders.failWith = null;
    await provider.placeOrder();
    expect(orders.placeKeys[0], isNot(orders.placeKeys[1]));
    expect(orders.lastExpectedTotal, 1260);
  });

  test('a double tap sends one request', () async {
    final provider = build();
    await provider.load();

    final results = await Future.wait([
      provider.placeOrder(),
      provider.placeOrder(),
    ]);

    expect(orders.placeKeys, hasLength(1));
    expect(results.whereType<Object>(), hasLength(1));
  });

  test('a newly added address becomes the chosen one', () async {
    final provider = build();
    await provider.load();

    addresses.addresses = [...addresses.addresses, address('a3')];
    await provider.reloadAddresses();

    expect(provider.selectedAddress!.id, 'a3');
  });
}
