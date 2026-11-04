import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/busy_button.dart';
import '../../../../core/widgets/failure_banner.dart';
import '../../../../core/widgets/state_views.dart';
import '../providers/auth_form_provider.dart';
import '../widgets/auth_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _isSent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final sent = await context.read<AuthFormProvider>().sendPasswordReset(
      _email.text.trim(),
    );
    if (sent && mounted) setState(() => _isSent = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isSent) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyView(
          icon: Icons.mark_email_read_outlined,
          title: 'Check your email',
          message: 'If an account uses this email, a reset link is on its way.',
          action: OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Back to sign in'),
          ),
        ),
      );
    }

    final form = context.watch<AuthFormProvider>();
    return AuthScaffold(
      title: 'Reset your password',
      subtitle: 'Enter your email and we will send you a reset link.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            FailureBanner(failure: form.failure),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 24),
            BusyButton(
              label: 'Send reset link',
              isBusy: form.isBusy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
