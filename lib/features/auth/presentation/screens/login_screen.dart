import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/busy_button.dart';
import '../../../../core/widgets/failure_banner.dart';
import '../providers/auth_form_provider.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/password_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({this.from, super.key});

  /// Where to go after signing in.
  final String? from;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthFormProvider>().signIn(_email.text.trim(), _password.text);
  }

  String _withFrom(String path) => AppRoutes.withFrom(path, widget.from);

  @override
  Widget build(BuildContext context) {
    final form = context.watch<AuthFormProvider>();
    final showGoogle = context.read<AppConfig>().isGoogleSignInEnabled;
    return AuthScaffold(
      showLogo: true,
      title: 'Welcome back',
      subtitle: 'Sign in to buy and sell on Browsly.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            children: [
              FailureBanner(failure: form.failure),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: Validators.email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Please enter your password' : null,
                onSubmitted: _submit,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 8),
              BusyButton(
                label: 'Sign in',
                isBusy: form.isBusy,
                onPressed: _submit,
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go(_withFrom(AppRoutes.phoneSignIn)),
                  icon: const Icon(Icons.phone_iphone_rounded),
                  label: const Text('Continue with phone'),
                ),
              ),
              if (showGoogle) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: form.isBusy ? null : form.signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                    label: const Text('Continue with Google'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go(_withFrom(AppRoutes.signUp)),
                child: const Text('New to Browsly? Create an account'),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const Text('Keep browsing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
