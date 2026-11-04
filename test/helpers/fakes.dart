import 'dart:async';
import 'dart:typed_data';

import 'package:browsly_app/app/app.dart';
import 'package:browsly_app/app/theme/app_theme.dart';
import 'package:browsly_app/core/config/app_config.dart';
import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/features/auth/domain/entities/auth_user.dart';
import 'package:browsly_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:browsly_app/features/profile/domain/entities/address.dart';
import 'package:browsly_app/features/profile/domain/entities/profile.dart';
import 'package:browsly_app/features/profile/domain/entities/region.dart';
import 'package:browsly_app/features/profile/domain/repositories/address_repository.dart';
import 'package:browsly_app/features/profile/domain/repositories/profile_repository.dart';
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

Future<void> pumpApp(
  WidgetTester tester, {
  required AuthRepository auth,
  ProfileRepository? profile,
  AddressRepository? addresses,
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
      theme: AppTheme.light(baseTextTheme: ThemeData().textTheme),
    ),
  );
  await tester.pumpAndSettle();
}
