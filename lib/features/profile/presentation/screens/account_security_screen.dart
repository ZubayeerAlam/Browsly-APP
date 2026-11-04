import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/failure_banner.dart';
import '../../../auth/presentation/providers/auth_form_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  Future<void> _confirmDelete(BuildContext context) async {
    final form = context.read<AuthFormProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'Your profile, addresses and photo will be permanently deleted. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed == true) await form.deleteAccount();
  }

  Future<void> _sendPasswordReset(BuildContext context, String email) async {
    final messenger = ScaffoldMessenger.of(context);
    final sent = await context.read<AuthFormProvider>().sendPasswordReset(
      email,
    );
    if (sent) {
      messenger.showSnackBar(
        SnackBar(content: Text('We sent a reset link to $email.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = context.watch<AuthFormProvider>();
    final user = context.watch<AuthProvider>().user;
    final email = user?.email;
    final phone = user?.phone;
    final isVerified = user?.isPhoneVerified ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Account & Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FailureBanner(failure: form.failure),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                if (email != null)
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(email),
                  ),
                ListTile(
                  leading: const Icon(Icons.phone_iphone_rounded),
                  title: const Text('Phone'),
                  subtitle: Text(
                    isVerified ? '+$phone • Verified' : 'Not verified',
                  ),
                  trailing: isVerified
                      ? const Icon(
                          Icons.verified_rounded,
                          color: AppColors.success,
                        )
                      : TextButton(
                          onPressed: () => context.go(
                            AppRoutes.withFrom(
                              AppRoutes.verifyPhone,
                              AppRoutes.accountSecurity,
                            ),
                          ),
                          child: const Text('Verify'),
                        ),
                ),
                if (email != null)
                  ListTile(
                    enabled: !form.isBusy,
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: const Text('Change password'),
                    subtitle: const Text('We will email you a reset link'),
                    onTap: () => _sendPasswordReset(context, email),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              enabled: !form.isBusy,
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
              title: const Text(
                'Delete account',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _confirmDelete(context),
            ),
          ),
        ],
      ),
    );
  }
}
