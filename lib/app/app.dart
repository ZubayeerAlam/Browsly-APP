import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/profile/domain/repositories/address_repository.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class BrowslyApp extends StatefulWidget {
  const BrowslyApp({
    required this.config,
    required this.authRepository,
    required this.profileRepository,
    required this.addressRepository,
    this.theme,
    super.key,
  });

  final AppConfig config;
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final AddressRepository addressRepository;

  /// Lets tests supply a theme that doesn't download a font.
  final ThemeData? theme;

  @override
  State<BrowslyApp> createState() => _BrowslyAppState();
}

class _BrowslyAppState extends State<BrowslyApp> {
  late final AuthProvider _authProvider;
  late final ProfileProvider _profileProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider(widget.authRepository);
    _profileProvider = ProfileProvider(widget.profileRepository, _authProvider);
    _router = createAppRouter(_authProvider);
  }

  @override
  void dispose() {
    _router.dispose();
    _profileProvider.dispose();
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: widget.config),
        Provider<AuthRepository>.value(value: widget.authRepository),
        Provider<AddressRepository>.value(value: widget.addressRepository),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<ProfileProvider>.value(value: _profileProvider),
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
