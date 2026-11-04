import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/busy_button.dart';
import '../../../../core/widgets/failure_banner.dart';
import '../../../../core/widgets/state_views.dart';
import '../providers/auth_form_provider.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/password_field.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _confirmationSentTo;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    final needsConfirmation = await context.read<AuthFormProvider>().signUp(
      _name.text.trim(),
      email,
      _password.text,
    );
    if (needsConfirmation == true && mounted) {
      setState(() => _confirmationSentTo = email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _confirmationSentTo;
    if (sentTo != null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyView(
          icon: Icons.mark_email_read_outlined,
          title: 'Check your email',
          message: 'We sent a confirmation link to $sentTo. Open it to finish.',
          action: OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Back to sign in'),
          ),
        ),
      );
    }

    final form = context.watch<AuthFormProvider>();
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'One account lets you both buy and sell.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            children: [
              FailureBanner(failure: form.failure),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                validator: Validators.name,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 16),
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
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
                onSubmitted: _submit,
              ),
              const SizedBox(height: 24),
              BusyButton(
                label: 'Create account',
                isBusy: form.isBusy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
