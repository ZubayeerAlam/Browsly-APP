import 'dart:async';
import 'dart:io' show SocketException;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_failure.dart';

/// Runs a data-layer call and converts any error into an [AppFailure], so
/// screens never depend on Supabase errors.
Future<T> guardFailures<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (error) {
    throw mapErrorToFailure(error);
  }
}

AppFailure mapErrorToFailure(Object error) {
  return switch (error) {
    AppFailure() => error,
    SocketException() || TimeoutException() => const NetworkFailure(),
    AuthRetryableFetchException() => const NetworkFailure(),
    AuthException() => _mapAuthError(error),
    PostgrestException() => _mapDatabaseError(error),
    StorageException() => const ServerFailure(
      'We could not upload that image. Please use a JPG or PNG under 5 MB.',
    ),
    _ when error.toString().contains('ClientException') =>
      const NetworkFailure(),
    _ => const UnknownFailure(),
  };
}

AppFailure _mapAuthError(AuthException error) {
  return switch (error.code) {
    'invalid_credentials' => const AuthFailure(
      'The email or password is incorrect.',
    ),
    'email_not_confirmed' => const AuthFailure(
      'Please confirm your email first.',
    ),
    'over_request_rate_limit' => const AuthFailure(
      'Too many attempts. Please wait a minute and try again.',
    ),
    _ => const AuthFailure('We could not sign you in. Please try again.'),
  };
}

AppFailure _mapDatabaseError(PostgrestException error) {
  if (error.code != 'P0001') {
    return error.code == '42501'
        ? const AuthFailure('You do not have permission to do that.')
        : const ServerFailure('That did not work. Please try again.');
  }
  return ServerFailure(
    _messages[error.message] ?? 'That did not work. Please try again.',
    code: error.message,
  );
}

/// What the server's refusals mean, in plain words.
const _messages = {
  'NOT_AN_ADMIN': 'This account is not an admin.',
  'REASON_REQUIRED': 'Please give a reason.',
  'PRODUCT_NOT_IN_REVIEW': 'This product has already been decided.',
  'PRODUCT_NOT_FOUND': 'We could not find that product.',
  'PRODUCT_UNCHANGED': 'This product has already changed.',
  'USER_NOT_FOUND': 'We could not find that user.',
  'CANNOT_CHANGE_ADMIN': 'Admins cannot be suspended here.',
  'NAME_REQUIRED': 'Please enter a name.',
  'INVALID_SLUG':
      'The web name can use only small letters, numbers and single dashes.',
  'SLUG_TAKEN': 'Another category already uses that web name.',
  'INVALID_PARENT': 'Categories can only go two levels deep.',
  'CATEGORY_NOT_FOUND': 'We could not find that category.',
  'INVALID_SETTINGS': 'Please check the numbers you entered.',
  'INVALID_PHOTO': 'The image did not upload. Please add it again.',
  'INVALID_DATES': 'The end date must be after the start date.',
  'BANNER_NOT_FOUND': 'We could not find that banner.',
  'REPORT_NOT_FOUND': 'We could not find that report.',
  'REPORT_ALREADY_CLOSED': 'This report has already been closed.',
  'REVIEW_NOT_FOUND': 'We could not find that review.',
  'INVALID_AMOUNT': 'Please enter a valid amount.',
  'REFERENCE_REQUIRED': 'Please enter the payment reference.',
  'SELLER_NOT_FOUND': 'We could not find that seller.',
  'SETTLEMENT_TOO_HIGH': 'That is more than this seller owes.',
};
