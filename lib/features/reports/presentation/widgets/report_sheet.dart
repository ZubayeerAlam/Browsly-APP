import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/buying_errors.dart';
import '../../../../core/widgets/busy_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/repositories/report_repository.dart';

export '../../domain/repositories/report_repository.dart' show ReportTarget;

/// Asks why something is being reported. Guests sign in first.
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTarget targetType,
  required String targetId,
  required String title,
}) async {
  if (!context.read<AuthProvider>().isSignedIn) {
    final here = GoRouterState.of(context).uri.toString();
    context.go(AppRoutes.withFrom(AppRoutes.login, here));
    return;
  }
  final repository = context.read<ReportRepository>();
  final messenger = ScaffoldMessenger.of(context);
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _ReportSheet(
      repository: repository,
      targetType: targetType,
      targetId: targetId,
      title: title,
    ),
  );
  if (sent == true) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Thank you. We will look into this.')),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.repository,
    required this.targetType,
    required this.targetId,
    required this.title,
  });

  final ReportRepository repository;
  final ReportTarget targetType;
  final String targetId;
  final String title;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  ReportReason? _reason;
  bool _isBusy = false;
  String? _failure;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() {
      _isBusy = true;
      _failure = null;
    });
    try {
      final details = _details.text.trim();
      await widget.repository.submit(
        widget.targetType,
        widget.targetId,
        reason,
        details: details.isEmpty ? null : details,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AppFailure catch (failure) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _failure = buyingFailureMessage(failure);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (value) => setState(() => _reason = value),
                child: Column(
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: reason,
                        contentPadding: EdgeInsets.zero,
                        title: Text(reason.label),
                      ),
                  ],
                ),
              ),
              TextField(
                controller: _details,
                maxLength: 1000,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'More details (optional)',
                ),
              ),
              if (_failure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _failure!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              BusyButton(
                label: 'Send report',
                isBusy: _isBusy,
                onPressed: _reason == null ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
