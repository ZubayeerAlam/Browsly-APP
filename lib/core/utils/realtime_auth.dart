import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Gives the live connection the current login. Call before subscribing.
///
/// Supabase only does this itself for some sign-ins. Opening a password reset
/// link is not one of them, so without this the channel joins as a guest, row
/// security hides every change, and nothing arrives until the app restarts.
void syncRealtimeAuth(SupabaseClient client) {
  final token = client.auth.currentSession?.accessToken;
  if (token != null) unawaited(client.realtime.setAuth(token));
}
