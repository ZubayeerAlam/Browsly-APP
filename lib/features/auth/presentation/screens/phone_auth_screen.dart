import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/busy_button.dart';
import '../../../../core/widgets/failure_banner.dart';
import '../providers/auth_form_provider.dart';
import '../widgets/auth_scaffold.dart';

/// Signs in with a phone number, or adds a verified phone to an account.
/// The router moves on automatically once the code is accepted.
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({required this.linkToAccount, this.backTo, super.key});

  final bool linkToAccount;
  final String? backTo;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  static const _resendWait = 60;

  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode(String phone) async {
    final sent = await context.read<AuthFormProvider>().sendPhoneCode(
      phone,
      linkToAccount: widget.linkToAccount,
    );
    if (!sent || !mounted) return;
    setState(() {
      _sentTo = phone;
      _secondsLeft = _resendWait;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  void _submitPhone() {
    if (!_formKey.currentState!.validate()) return;
    _sendCode(Validators.normalizeBangladeshPhone(_phone.text)!);
  }

  void _submitCode() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthFormProvider>().verifyPhoneCode(
      _sentTo!,
      _code.text.trim(),
      linkToAccount: widget.linkToAccount,
    );
  }

  void _changeNumber() {
    _timer?.cancel();
    _code.clear();
    setState(() {
      _sentTo = null;
      _secondsLeft = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final form = context.watch<AuthFormProvider>();
    final sentTo = _sentTo;
    if (sentTo != null) {
      return AuthScaffold(
        backTo: widget.backTo,
        title: 'Enter your code',
        subtitle: 'We sent a 6-digit code to $sentTo.',
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              FailureBanner(failure: form.failure),
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                autofocus: true,
                validator: Validators.otp,
                onFieldSubmitted: (_) => _submitCode(),
                decoration: const InputDecoration(
                  labelText: 'Code',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              BusyButton(
                label: 'Verify',
                isBusy: form.isBusy,
                onPressed: _submitCode,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _secondsLeft > 0 || form.isBusy
                    ? null
                    : () => _sendCode(sentTo),
                child: Text(
                  _secondsLeft > 0
                      ? 'Resend code in ${_secondsLeft}s'
                      : 'Resend code',
                ),
              ),
              TextButton(
                onPressed: _changeNumber,
                child: const Text('Change number'),
              ),
            ],
          ),
        ),
      );
    }

    return AuthScaffold(
      backTo: widget.backTo,
      title: widget.linkToAccount ? 'Verify your phone' : 'Continue with phone',
      subtitle: widget.linkToAccount
          ? 'A verified phone is needed to order and to sell.'
          : 'We will text you a 6-digit code.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            FailureBanner(failure: form.failure),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: Validators.phone,
              onFieldSubmitted: (_) => _submitPhone(),
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                hintText: '01712345678',
              ),
            ),
            const SizedBox(height: 24),
            BusyButton(
              label: 'Send code',
              isBusy: form.isBusy,
              onPressed: _submitPhone,
            ),
          ],
        ),
      ),
    );
  }
}
