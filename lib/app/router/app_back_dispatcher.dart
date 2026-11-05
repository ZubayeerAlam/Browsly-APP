import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// Handles the phone's Back when no screen is left to go back to. Many screens
/// open with `go`, so without this, Back on them would close the app instead
/// of going where their on-screen back arrow goes.
class AppBackDispatcher extends RootBackButtonDispatcher {
  AppBackDispatcher(this._router);

  final GoRouter _router;

  @override
  Future<bool> didPopRoute() async {
    if (await super.didPopRoute()) return true;
    final target = AppRoutes.backFallback(
      _router.routerDelegate.currentConfiguration.uri,
    );
    if (target == null) return false;
    _router.go(target);
    return true;
  }
}
