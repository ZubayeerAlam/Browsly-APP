import 'dart:typed_data';

import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/features/auth/presentation/providers/auth_form_provider.dart';
import 'package:browsly_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:browsly_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  group('AuthFormProvider', () {
    test('reports success and clears the busy state', () async {
      final provider = AuthFormProvider(FakeAuthRepository());

      final result = provider.signIn('a@example.com', 'password123');
      expect(provider.isBusy, isTrue);

      expect(await result, isTrue);
      expect(provider.isBusy, isFalse);
      expect(provider.failure, isNull);
    });

    test('exposes a friendly failure', () async {
      final repository = FakeAuthRepository()
        ..failWith = const AuthFailure('Nope');
      final provider = AuthFormProvider(repository);

      expect(await provider.signIn('a@example.com', 'x'), isFalse);
      expect(provider.failure?.message, 'Nope');
      expect(provider.isBusy, isFalse);
    });

    test('ignores a second tap while busy', () async {
      final repository = FakeAuthRepository();
      final provider = AuthFormProvider(repository);

      final first = provider.signIn('a@example.com', 'x');
      final second = await provider.signIn('a@example.com', 'x');
      await first;

      expect(second, isFalse);
      expect(repository.calls, hasLength(1));
    });

    test('a new attempt clears the old failure', () async {
      final repository = FakeAuthRepository()
        ..failWith = const AuthFailure('Nope');
      final provider = AuthFormProvider(repository);
      await provider.signIn('a@example.com', 'x');

      repository.failWith = null;
      await provider.signIn('a@example.com', 'x');

      expect(provider.failure, isNull);
    });

    test('sign-up returns null on failure', () async {
      final repository = FakeAuthRepository()
        ..failWith = const AuthFailure('Nope');
      final provider = AuthFormProvider(repository);

      expect(await provider.signUp('A', 'a@example.com', 'password1'), isNull);
    });

    test('survives being disposed during an action', () async {
      final provider = AuthFormProvider(FakeAuthRepository());

      final result = provider.signIn('a@example.com', 'password123');
      provider.dispose();

      expect(await result, isTrue);
    });

    test('chooses sign-in or linking for phone codes', () async {
      final repository = FakeAuthRepository();
      final provider = AuthFormProvider(repository);

      await provider.sendPhoneCode('+8801700000000', linkToAccount: false);
      await provider.sendPhoneCode('+8801700000000', linkToAccount: true);

      expect(repository.calls, [
        'phoneSignInCode:+8801700000000',
        'phoneLinkCode:+8801700000000',
      ]);
    });
  });

  group('AuthProvider', () {
    test('follows user changes', () async {
      final repository = FakeAuthRepository();
      final provider = AuthProvider(repository);
      expect(provider.isSignedIn, isFalse);

      repository.emitUser(verifiedUser);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isSignedIn, isTrue);
      expect(provider.isPhoneVerified, isTrue);
      provider.dispose();
    });

    test('signing out ends password recovery', () async {
      final repository = FakeAuthRepository(user: testUser);
      final provider = AuthProvider(repository);

      repository.emitPasswordRecovery();
      await Future<void>.delayed(Duration.zero);
      expect(provider.isRecoveringPassword, isTrue);

      repository.emitUser(null);
      await Future<void>.delayed(Duration.zero);
      expect(provider.isRecoveringPassword, isFalse);
      provider.dispose();
    });
  });

  group('ProfileProvider', () {
    test('loads on sign-in and clears on sign-out', () async {
      final repository = FakeAuthRepository();
      final auth = AuthProvider(repository);
      final provider = ProfileProvider(FakeProfileRepository(), auth);
      expect(provider.profile, isNull);

      repository.emitUser(testUser);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(provider.profile?.fullName, 'Test User');

      repository.emitUser(null);
      await Future<void>.delayed(Duration.zero);
      expect(provider.profile, isNull);

      provider.dispose();
      auth.dispose();
    });

    test('reloads when the phone becomes verified', () async {
      final repository = FakeAuthRepository(user: testUser);
      final auth = AuthProvider(repository);
      final profiles = FakeProfileRepository();
      final provider = ProfileProvider(profiles, auth);
      await Future<void>.delayed(Duration.zero);
      expect(profiles.loads, 1);

      repository.emitUser(verifiedUser);
      await Future<void>.delayed(Duration.zero);
      expect(profiles.loads, 2);

      provider.dispose();
      auth.dispose();
    });

    test('uploads only the prepared photo, never the original', () async {
      final auth = AuthProvider(FakeAuthRepository(user: testUser));
      final profiles = FakeProfileRepository();
      final prepared = Uint8List.fromList([9]);
      final provider = ProfileProvider(
        profiles,
        auth,
        preparePhoto: (_) async => prepared,
      );
      await Future<void>.delayed(Duration.zero);

      expect(await provider.updateAvatar(Uint8List.fromList([1])), isTrue);

      expect(profiles.uploadedAvatar, prepared);
      provider.dispose();
      auth.dispose();
    });

    test('uploads nothing if preparing the photo fails', () async {
      final auth = AuthProvider(FakeAuthRepository(user: testUser));
      final profiles = FakeProfileRepository();
      final provider = ProfileProvider(
        profiles,
        auth,
        preparePhoto: (_) async => throw StateError('decode failed'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(await provider.updateAvatar(Uint8List.fromList([1])), isFalse);

      expect(profiles.uploadedAvatar, isNull);
      expect(provider.saveFailure, isA<UnknownFailure>());
      expect(provider.isSaving, isFalse);
      provider.dispose();
      auth.dispose();
    });

    test('keeps a save failure for the screen to show', () async {
      final auth = AuthProvider(FakeAuthRepository(user: testUser));
      final profiles = FakeProfileRepository();
      final provider = ProfileProvider(profiles, auth);
      await Future<void>.delayed(Duration.zero);

      profiles.failWith = const NetworkFailure();
      expect(await provider.updateName('New'), isFalse);
      expect(provider.saveFailure, isA<NetworkFailure>());
      expect(provider.isSaving, isFalse);

      provider.dispose();
      auth.dispose();
    });
  });
}
