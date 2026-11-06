import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../core/errors/app_failure.dart';
import '../../core/widgets/admin_page.dart';
import '../../core/widgets/busy_button.dart';
import '../../core/widgets/state_views.dart';
import 'settings_data.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _rate = TextEditingController();
  final _limit = TextEditingController();
  final _cod = TextEditingController();
  bool _isLoaded = false;
  bool _isSaving = false;
  String? _failure;
  String? _saved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rate.dispose();
    _limit.dispose();
    _cod.dispose();
    super.dispose();
  }

  static String _plain(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  Future<void> _load() async {
    setState(() => _failure = null);
    try {
      final settings = await context.read<SettingsRepository>().getSettings();
      if (!mounted) return;
      _rate.text = _plain(settings.commissionRate);
      _limit.text = _plain(settings.commissionBlockLimit);
      _cod.text = _plain(settings.maxCodOrderValue);
      setState(() => _isLoaded = true);
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _failure = failure.message);
    }
  }

  Future<void> _save() async {
    final rate = double.tryParse(_rate.text.trim());
    final limit = double.tryParse(_limit.text.trim());
    final cod = double.tryParse(_cod.text.trim());
    if (rate == null || limit == null || cod == null) {
      setState(() {
        _failure = 'Please enter numbers only.';
        _saved = null;
      });
      return;
    }
    final repository = context.read<SettingsRepository>();
    final confirmed = await askToConfirm(
      context,
      title: 'Save these settings?',
      message:
          'These apply to everyone straight away. A new commission rate '
          'applies to new orders only.',
      confirmLabel: 'Save',
    );
    if (confirmed == null) return;
    setState(() {
      _isSaving = true;
      _failure = null;
      _saved = null;
    });
    try {
      await repository.update(
        PlatformSettings(
          commissionRate: rate,
          commissionBlockLimit: limit,
          maxCodOrderValue: cod,
        ),
      );
      if (mounted) setState(() => _saved = 'Saved.');
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _failure = failure.message);
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    return AdminPage(
      title: 'Settings',
      child: !_isLoaded
          ? (failure == null
                ? const LoadingView()
                : ErrorView(message: failure, onRetry: _load))
          : SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 480,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _rate,
                            decoration: const InputDecoration(
                              labelText: 'Commission rate (%)',
                              helperText:
                                  'Of the listing price, not counting delivery',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _limit,
                            decoration: const InputDecoration(
                              labelText: 'Unpaid commission limit (৳)',
                              helperText: 'Above this, a seller cannot post new listings',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _cod,
                            decoration: const InputDecoration(
                              labelText: 'Largest Cash on Delivery order (৳)',
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (failure != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                failure,
                                style: const TextStyle(color: AppColors.danger),
                              ),
                            ),
                          if (_saved != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _saved!,
                                style: const TextStyle(
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          BusyButton(
                            label: 'Save settings',
                            isBusy: _isSaving,
                            onPressed: _save,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
