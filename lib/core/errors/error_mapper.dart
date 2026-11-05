import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_failure.dart';

/// Runs a data-layer call and converts any error into an [AppFailure].
///
/// If a saved session turns out to be dead, the Supabase client signs out and
/// fails that one request. Retrying then runs it as a guest, so public screens
/// still load. Private data stays protected by RLS, and the sign-out already
/// sends the user to sign in where needed.
Future<T> guardFailures<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on AuthException catch (error) {
    if (!_endedSessionCodes.contains(error.code)) {
      throw mapErrorToFailure(error);
    }
  } catch (error) {
    throw mapErrorToFailure(error);
  }
  try {
    return await action();
  } catch (error) {
    throw mapErrorToFailure(error);
  }
}

const _endedSessionCodes = {
  'refresh_token_not_found',
  'refresh_token_already_used',
  'session_not_found',
  'session_expired',
};

AppFailure mapErrorToFailure(Object error) {
  return switch (error) {
    AppFailure() => error,
    AuthRetryableFetchException() ||
    SocketException() ||
    TimeoutException() ||
    HttpException() => const NetworkFailure(),
    AuthException() => _mapAuthError(error),
    PostgrestException() => _mapDatabaseError(error),
    StorageException() => const ServerFailure(
      'We could not upload that photo. Please use a JPG or PNG under 5 MB.',
    ),
    FunctionException() => const ServerFailure(
      'That did not work. Please try again.',
    ),
    _ when error.toString().contains('ClientException') =>
      const NetworkFailure(),
    _ => const UnknownFailure(),
  };
}

AppFailure _mapAuthError(AuthException error) {
  const tooManyAttempts =
      'Too many attempts. Please wait a minute and try again.';
  return switch (error.code) {
    'invalid_credentials' => const AuthFailure(
      'The email or password is incorrect.',
    ),
    'email_not_confirmed' => const AuthFailure(
      'Please confirm your email first. Check your inbox for the link.',
    ),
    'user_already_exists' || 'email_exists' => const AuthFailure(
      'An account with this email already exists. Please sign in.',
    ),
    'weak_password' => const ValidationFailure(
      'Please choose a stronger password with at least 8 characters.',
    ),
    'same_password' => const ValidationFailure(
      'Your new password must be different from your old one.',
    ),
    'otp_expired' || 'otp_disabled' => const AuthFailure(
      'That code is wrong or has expired. Please try again.',
    ),
    'phone_exists' => const AuthFailure(
      'This phone number is already linked to another account.',
    ),
    'sms_send_failed' => const ServerFailure(
      'We could not send the code. Please check the number and try again.',
    ),
    'over_email_send_rate_limit' ||
    'over_sms_send_rate_limit' ||
    'over_request_rate_limit' => const AuthFailure(tooManyAttempts),
    'user_banned' => const AuthFailure(
      'This account is suspended. Please contact support.',
    ),
    _ => const AuthFailure('We could not sign you in. Please try again.'),
  };
}

AppFailure _mapDatabaseError(PostgrestException error) {
  return switch (error.code) {
    'P0001' => ServerFailure(
      'That did not work. Please try again.',
      code: error.message,
    ),
    '23514' => const ValidationFailure(
      'Please check the details you entered and try again.',
    ),
    '42501' => const AuthFailure('You do not have permission to do that.'),
    _ => const ServerFailure('That did not work. Please try again.'),
  };
}
