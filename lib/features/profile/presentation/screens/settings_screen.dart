import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_form_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_avatar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final form = context.watch<AuthFormProvider>();
    final failure = form.failure;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.dashboard)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _ProfileCard(),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.shield_outlined,
                  label: 'Account & Security',
                  onTap: () => context.go(AppRoutes.accountSecurity),
                ),
                _SettingsRow(
                  icon: Icons.location_on_outlined,
                  label: 'Addresses',
                  onTap: () => context.go(AppRoutes.addresses),
                ),
                const _SettingsRow(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  value: 'English',
                ),
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  label: 'About Browsly',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Browsly',
                    applicationVersion: '1.0.0',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (failure != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                failure.message,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          Material(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              enabled: !form.isBusy,
              leading: const Icon(
                Icons.logout_rounded,
                color: AppColors.danger,
              ),
              title: const Text(
                'Log Out',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: form.signOut,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final user = context.watch<AuthProvider>().user;
    final name = profile?.fullName ?? '';
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProfileAvatar(url: profile?.avatarUrl, radius: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Add your name' : name,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? profile?.phone ?? '',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 36),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => context.go(AppRoutes.editProfile),
                    child: const Text('Edit Profile'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(label),
      trailing: value != null
          ? Text(value, style: const TextStyle(color: AppColors.textSecondary))
          : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
