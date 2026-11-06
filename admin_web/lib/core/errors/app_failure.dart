/// A problem the app can explain to the user.
///
/// Repositories convert package exceptions into these types, so providers and
/// screens never depend on Supabase errors.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  /// A friendly message that is safe to show on screen.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = 'Please check your internet connection and try again.',
  ]);
}

class AuthFailure extends AppFailure {
  const AuthFailure([super.message = 'Please sign in and try again.']);
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

/// A business rule refused by the server, such as `OUT_OF_STOCK`.
class ServerFailure extends AppFailure {
  const ServerFailure(super.message, {this.code});

  final String? code;
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([
    super.message = 'Something went wrong. Please try again.',
  ]);
}
