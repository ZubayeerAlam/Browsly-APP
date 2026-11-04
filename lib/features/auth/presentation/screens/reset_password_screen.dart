import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/busy_button.dart';
import '../../../../core/widgets/failure_banner.dart';
import '../providers/auth_form_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/password_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final saved = await context.read<AuthFormProvider>().updatePassword(
      _password.text,
    );
    if (saved) auth.finishPasswordRecovery();
  }

  @override
  Widget build(BuildContext context) {
    final form = context.watch<AuthFormProvider>();
    return AuthScaffold(
      title: 'Choose a new password',
      subtitle: 'Use at least 8 characters.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            FailureBanner(failure: form.failure),
            PasswordField(
              controller: _password,
              label: 'New password',
              autofillHints: const [AutofillHints.newPassword],
              validator: Validators.password,
              onSubmitted: _submit,
            ),
            const SizedBox(height: 24),
            BusyButton(
              label: 'Save password',
              isBusy: form.isBusy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
