import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../core/formatters.dart';
import '../../core/state/paged_provider.dart';
import '../../core/widgets/admin_page.dart';
import 'reports_data.dart';

typedef _Provider = PagedProvider<AdminReport, ReportFilter>;

const _targetLabels = {
  'product': 'Product',
  'shop': 'Shop',
  'review': 'Review',
  'message': 'Chat message',
};

const _reasonLabels = {
  'prohibited': 'Not allowed on Browsly',
  'fake': 'Fake or misleading',
  'offensive': 'Offensive or abusive',
  'spam': 'Spam',
  'other': 'Something else',
};

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final repository = context.read<ReportsRepository>();
        return _Provider(
          (search, filter, next) =>
              repository.getReports(filter ?? ReportFilter.open, cursor: next),
          filter: ReportFilter.open,
        )..load();
      },
      child: Builder(
        builder: (context) {
          final provider = context.watch<_Provider>();
          return AdminPage(
            title: 'Reports',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilterChips<ReportFilter>(
                  selected: provider.filter,
                  options: const {
                    ReportFilter.open: 'Open',
                    ReportFilter.resolved: 'Upheld',
                    ReportFilter.dismissed: 'Dismissed',
                  },
                  onSelected: provider.setFilter,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PagedBody(
                    provider: provider,
                    emptyIcon: Icons.flag_outlined,
                    emptyTitle: 'No reports here',
                    builder: (context, items) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final report in items) _ReportCard(report: report),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final AdminReport report;

  /// Taking something down leaves the report open, so the card looks the same
  /// afterwards. This says it worked.
  Future<void> _takeAction(
    BuildContext context,
    Future<void> Function() action,
    String done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final worked = await context.read<_Provider>().act(action);
    if (worked) {
      messenger.showSnackBar(
        SnackBar(content: Text('$done You can now close this report.')),
      );
    }
  }

  Future<void> _close(BuildContext context, {required bool upheld}) async {
    final provider = context.read<_Provider>();
    final repository = context.read<ReportsRepository>();
    final note = await askToConfirm(
      context,
      title: upheld ? 'Close as upheld?' : 'Dismiss this report?',
      message:
          'Anyone who reported this hears that it was looked at, and not the '
          'details. Taking something down is a separate button.',
      reasonLabel: 'Private note (optional)',
      confirmLabel: upheld ? 'Uphold' : 'Dismiss',
    );
    if (note != null) {
      await provider.act(
        () => repository.close(report.id, upheld: upheld, note: note),
      );
    }
  }

  Future<void> _removeProduct(BuildContext context) async {
    final repository = context.read<ReportsRepository>();
    final reason = await askToConfirm(
      context,
      title: 'Remove this listing?',
      reasonLabel: 'Reason for the seller',
      reasonRequired: true,
      confirmLabel: 'Remove',
      isDanger: true,
    );
    if (reason != null && context.mounted) {
      await _takeAction(
        context,
        () => repository.removeProduct(report.targetId, reason),
        'Listing removed.',
      );
    }
  }

  Future<void> _hideReview(BuildContext context) async {
    final repository = context.read<ReportsRepository>();
    final answer = await askToConfirm(
      context,
      title: 'Hide this review?',
      message: 'It stops showing and no longer counts towards the rating.',
      confirmLabel: 'Hide',
      isDanger: true,
    );
    if (answer != null && context.mounted) {
      await _takeAction(
        context,
        () => repository.hideReview(report.targetId),
        'Review hidden.',
      );
    }
  }

  Future<void> _suspend(BuildContext context, String userId) async {
    final repository = context.read<ReportsRepository>();
    final reason = await askToConfirm(
      context,
      title: 'Suspend this account?',
      message: 'A seller\'s shop and all its products also disappear.',
      reasonLabel: 'Reason (kept in the admin record)',
      reasonRequired: true,
      confirmLabel: 'Suspend',
      isDanger: true,
    );
    if (reason != null && context.mounted) {
      await _takeAction(
        context,
        () => repository.suspendUser(userId, reason),
        'Account suspended.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = report.targetUserId;
    final dangerStyle = TextButton.styleFrom(foregroundColor: AppColors.danger);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StatusPill(
                    label:
                        _targetLabels[report.targetType] ?? report.targetType,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _reasonLabels[report.reason] ?? report.reason,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${report.reporterName} · ${formatDateTime(report.createdAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  report.targetText == null || report.targetText!.isEmpty
                      ? 'This is no longer available, or has no text.'
                      : report.targetText!,
                ),
              ),
              if (report.details.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('They said: ${report.details}'),
              ],
              if (report.resolutionNote != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Note: ${report.resolutionNote}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (report.isOpen) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    if (report.targetType == 'product')
                      TextButton(
                        style: dangerStyle,
                        onPressed: () => _removeProduct(context),
                        child: const Text('Remove listing'),
                      ),
                    if (report.targetType == 'review')
                      TextButton(
                        style: dangerStyle,
                        onPressed: () => _hideReview(context),
                        child: const Text('Hide review'),
                      ),
                    if (userId != null)
                      TextButton(
                        style: dangerStyle,
                        onPressed: () => _suspend(context, userId),
                        child: const Text('Suspend account'),
                      ),
                    OutlinedButton(
                      onPressed: () => _close(context, upheld: false),
                      child: const Text('Dismiss'),
                    ),
                    FilledButton(
                      onPressed: () => _close(context, upheld: true),
                      child: const Text('Uphold'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
