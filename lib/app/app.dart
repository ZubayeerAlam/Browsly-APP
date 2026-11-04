import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class BrowslyApp extends StatefulWidget {
  const BrowslyApp({required this.authRepository, this.theme, super.key});

  final AuthRepository authRepository;

  /// Lets tests supply a theme that doesn't download a font.
  final ThemeData? theme;

  @override
  State<BrowslyApp> createState() => _BrowslyAppState();
}

class _BrowslyAppState extends State<BrowslyApp> {
  late final AuthProvider _authProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider(widget.authRepository);
    _router = createAppRouter(_authProvider);
  }

  @override
  void dispose() {
    _router.dispose();
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: widget.authRepository),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
      ],
      child: MaterialApp.router(
        title: 'Browsly',
        debugShowCheckedModeBanner: false,
        theme: widget.theme ?? AppTheme.light(),
        routerConfig: _router,
      ),
    );
  }
}
