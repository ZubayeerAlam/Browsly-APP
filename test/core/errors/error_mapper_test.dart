import 'dart:io';

import 'package:browsly_app/core/errors/app_failure.dart';
import 'package:browsly_app/core/errors/error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps sign-in errors to clear messages', () {
    final messages = {
      'invalid_credentials': 'incorrect',
      'email_not_confirmed': 'confirm your email',
      'otp_expired': 'wrong or has expired',
      'phone_exists': 'already linked',
      'over_sms_send_rate_limit': 'Too many attempts',
    };
    messages.forEach((code, text) {
      final failure = mapErrorToFailure(AuthException('raw', code: code));
      expect(failure.message, contains(text), reason: code);
    });
  });

  test('never shows raw server text', () {
    final failure = mapErrorToFailure(
      const AuthException('secret internal detail', code: 'unexpected'),
    );
    expect(failure.message, isNot(contains('secret')));
  });

  test('network problems become NetworkFailure', () {
    expect(
      mapErrorToFailure(const SocketException('down')),
      isA<NetworkFailure>(),
    );
    expect(
      mapErrorToFailure(AuthRetryableFetchException(message: 'down')),
      isA<NetworkFailure>(),
    );
  });

  test('database errors keep the server code for later handling', () {
    final failure = mapErrorToFailure(
      const PostgrestException(message: 'OUT_OF_STOCK', code: 'P0001'),
    );
    expect(failure, isA<ServerFailure>());
    expect((failure as ServerFailure).code, 'OUT_OF_STOCK');
    expect(failure.message, isNot(contains('OUT_OF_STOCK')));
  });

  test('an AppFailure passes through unchanged', () {
    const failure = ValidationFailure('Check this');
    expect(mapErrorToFailure(failure), same(failure));
  });

  test('guardFailures converts thrown errors', () async {
    await expectLater(
      guardFailures<void>(() => throw const SocketException('down')),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
