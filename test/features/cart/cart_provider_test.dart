import 'dart:async';

import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:browsly_app/features/cart/data/models/cart_model.dart';
import 'package:browsly_app/features/cart/domain/entities/cart.dart';
import 'package:browsly_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeCartRepository repository;
  late AuthProvider authProvider;
  late CartProvider provider;

  Future<void> start({List<CartLine> lines = const []}) async {
    repository.lines = lines;
    await provider.load();
  }

  setUp(() {
    auth = FakeAuthRepository(user: verifiedUser);
    repository = FakeCartRepository();
    authProvider = AuthProvider(auth);
    provider = CartProvider(repository, authProvider);
  });

  tearDown(() {
    provider.dispose();
    authProvider.dispose();
  });

  test('loads the cart for a signed-in user', () async {
    await start(lines: [testCartLine('v1', quantity: 2)]);

    expect(provider.cart!.shops.single.name, 'Test Shop');
    expect(provider.itemCount, 2);
  });

  test('the badge changes at once, before the server replies', () async {
    await start();
    final gate = Completer<void>();
    repository.writeGate = gate.future;

    final adding = provider.addVariant('v1');
    expect(provider.itemCount, 1);

    gate.complete();
    expect(await adding, isNull);
    expect(provider.itemCount, 1);
    expect(provider.cart!.itemCount, 1);
  });

  test('the badge corrects itself when the server refuses', () async {
    await start();
    repository.failWith = const ServerFailure('x', code: 'OUT_OF_STOCK');

    final failure = await provider.addVariant('v1');

    expect((failure! as ServerFailure).code, 'OUT_OF_STOCK');
    expect(provider.itemCount, 0);
  });

  test('requests run in order, so an older reply cannot win', () async {
    await start(lines: [testCartLine('v1')]);
    final gate = Completer<void>();
    repository.writeGate = gate.future;

    final first = provider.setQuantity(provider.cart!.shops[0].lines[0], 2);
    expect(provider.isBusy('v1'), isTrue);
    final second = provider.addVariant('v2');
    await Future<void>.delayed(Duration.zero);
    expect(repository.calls, ['setQuantity:v1:2']);

    repository.writeGate = null;
    gate.complete();
    await Future.wait([first, second]);

    expect(repository.calls, ['setQuantity:v1:2', 'addVariant:v2']);
    expect(provider.itemCount, 3);
    expect(provider.isBusy('v1'), isFalse);
  });

  test('removing sets the quantity to zero', () async {
    await start(lines: [testCartLine('v1')]);

    await provider.remove(provider.cart!.shops[0].lines[0]);

    expect(repository.calls, ['setQuantity:v1:0']);
    expect(provider.cart!.isEmpty, isTrue);
  });

  test('signing out clears the cart', () async {
    await start(lines: [testCartLine('v1')]);

    auth.emitUser(null);
    await Future<void>.delayed(Duration.zero);

    expect(provider.cart, isNull);
    expect(provider.itemCount, 0);
  });

  test('parses the server reply', () {
    final cart = CartModel.fromJson({
      'shops': [
        {
          'shop_id': 's1',
          'shop_name': 'Alpha',
          'delivery_fee': 60,
          'subtotal': 250.5,
          'items': [
            {
              'variant_id': 'v1',
              'product_id': 'p1',
              'title': 'Lamp',
              'variant_name': 'Default',
              'image_path': 'a/b.jpg',
              'unit_price': 250.5,
              'compare_at_price': null,
              'quantity': 1,
              'stock': 3,
              'problem': null,
            },
            {
              'variant_id': 'v2',
              'product_id': 'p2',
              'title': 'Shirt',
              'variant_name': 'Red / M',
              'image_path': null,
              'unit_price': 300,
              'compare_at_price': 400,
              'quantity': 4,
              'stock': 2,
              'problem': 'LOW_STOCK',
            },
          ],
        },
      ],
      'subtotal': 250.5,
      'delivery_total': 60,
      'grand_total': 310.5,
      'item_count': 5,
      'can_checkout': false,
    }, (path) => 'https://img/$path');

    final lines = cart.shops.single.lines;
    expect(lines[0].variantLabel, isNull);
    expect(lines[0].imageUrl, 'https://img/a/b.jpg');
    expect(lines[0].problem, isNull);
    expect(lines[1].variantLabel, 'Red / M');
    expect(lines[1].imageUrl, isNull);
    expect(lines[1].problem, CartProblem.lowStock);
    expect(lines[1].problemMessage, contains('Only 2 left'));
    expect(cart.grandTotal, 310.5);
    expect(cart.canCheckout, isFalse);
  });
}
