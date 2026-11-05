import 'dart:async';

import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:browsly_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late AuthProvider authProvider;
  late FakeWishlistRepository repository;

  Future<WishlistProvider> build({bool signedIn = true}) async {
    auth = FakeAuthRepository(user: signedIn ? testUser : null);
    authProvider = AuthProvider(auth);
    final provider = WishlistProvider(repository, authProvider);
    await Future<void>.delayed(Duration.zero);
    return provider;
  }

  setUp(() => repository = FakeWishlistRepository());

  test('loads saved products for the signed-in user', () async {
    repository.saved = [testProduct('1')];

    final provider = await build();

    expect(provider.isSaved('1'), isTrue);
    expect(provider.isSaved('2'), isFalse);
  });

  test('the heart changes before the server answers', () async {
    final provider = await build();
    final server = Completer<void>();
    repository.writeGate = server.future;

    final result = provider.toggle('1');
    expect(provider.isSaved('1'), isTrue);

    server.complete();
    expect(await result, isTrue);
    expect(provider.isSaved('1'), isTrue);
    expect(repository.saved.single.id, '1');
  });

  test('the heart goes back if saving fails', () async {
    final provider = await build();
    repository.failWith = const NetworkFailure();

    expect(await provider.toggle('1'), isFalse);

    expect(provider.isSaved('1'), isFalse);
  });

  test('the heart goes back if removing fails', () async {
    repository.saved = [testProduct('1')];
    final provider = await build();
    repository.failWith = const NetworkFailure();

    expect(await provider.toggle('1'), isFalse);

    expect(provider.isSaved('1'), isTrue);
  });

  test('double taps send one change', () async {
    final provider = await build();
    final server = Completer<void>();
    repository.writeGate = server.future;

    final first = provider.toggle('1');
    final second = provider.toggle('1');
    server.complete();
    await Future.wait([first, second]);

    expect(repository.writes, 1);
    expect(provider.isSaved('1'), isTrue);
  });

  test('a change made during loading survives the load', () async {
    repository.saved = [testProduct('1')];
    final provider = await build();
    final server = Completer<void>();
    repository.writeGate = server.future;

    final change = provider.toggle('1');
    await provider.load();
    expect(provider.isSaved('1'), isFalse);

    server.complete();
    await change;
    expect(provider.isSaved('1'), isFalse);
  });

  test(
    'signing out clears hearts, and signing in loads the new user',
    () async {
      repository.saved = [testProduct('1')];
      final provider = await build();

      auth.emitUser(null);
      await Future<void>.delayed(Duration.zero);
      expect(provider.isSaved('1'), isFalse);

      auth.emitUser(testUser);
      await Future<void>.delayed(Duration.zero);
      expect(provider.isSaved('1'), isTrue);
    },
  );

  test('a change on its way does not leak into the next account', () async {
    final provider = await build();
    final server = Completer<void>();
    repository.writeGate = server.future;

    final change = provider.toggle('1');
    auth.emitUser(null);
    await Future<void>.delayed(Duration.zero);
    server.complete();
    await change;

    expect(provider.isSaved('1'), isFalse);
  });

  test('guests cannot save', () async {
    final provider = await build(signedIn: false);

    await provider.toggle('1');

    expect(repository.writes, 0);
    expect(provider.isSaved('1'), isFalse);
  });

  test('a failed load leaves hearts empty without an error', () async {
    repository.failWith = const NetworkFailure();

    final provider = await build();

    expect(provider.isSaved('1'), isFalse);
  });
}
