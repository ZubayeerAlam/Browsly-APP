/// Values supplied at build time with `--dart-define-from-file=env.json`.
///
/// Only public values belong here. The Supabase service role key must never
/// be added to the app.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.isGoogleSignInEnabled = false,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
      isGoogleSignInEnabled: bool.fromEnvironment('GOOGLE_SIGN_IN_ENABLED'),
    );
  }

  final String supabaseUrl;
  final String supabasePublishableKey;

  /// Hides the Google button until Google is set up in Supabase.
  final bool isGoogleSignInEnabled;

  bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
