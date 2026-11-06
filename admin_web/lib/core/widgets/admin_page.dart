import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../state/paged_provider.dart';
import '../state/view_state.dart';
import 'state_views.dart';

/// A page's title with optional actions, and its content below.
class AdminPage extends StatelessWidget {
  const AdminPage({
    required this.title,
    required this.child,
    this.actions = const [],
    super.key,
  });

  final String title;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A search box that waits for a pause in typing before searching.
class SearchBox extends StatefulWidget {
  const SearchBox({required this.hint, required this.onChanged, super.key});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: TextField(
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search_rounded),
          isDense: true,
        ),
        onChanged: (text) {
          _debounce?.cancel();
          _debounce = Timer(
            const Duration(milliseconds: 350),
            () => widget.onChanged(text),
          );
        },
      ),
    );
  }
}

/// Filter choices shown in a row above a table.
class FilterChips<F> extends StatelessWidget {
  const FilterChips({
    required this.selected,
    required this.options,
    required this.onSelected,
    super.key,
  });

  final F? selected;

  /// Each value with its label. A null value means everything.
  final Map<F?, String> options;
  final ValueChanged<F?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options.entries)
          ChoiceChip(
            label: Text(option.value),
            selected: selected == option.key,
            showCheckmark: false,
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: selected == option.key
                  ? Colors.white
                  : AppColors.textPrimary,
            ),
            onSelected: (_) => onSelected(option.key),
          ),
      ],
    );
  }
}

/// The loading, empty and error handling every list shares, plus the message for
/// a refused action and a Load more button.
class PagedBody<T, F> extends StatelessWidget {
  const PagedBody({
    required this.provider,
    required this.emptyTitle,
    required this.builder,
    this.emptyIcon = Icons.inbox_outlined,
    super.key,
  });

  final PagedProvider<T, F> provider;
  final String emptyTitle;
  final IconData emptyIcon;
  final Widget Function(BuildContext context, List<T> items) builder;

  @override
  Widget build(BuildContext context) {
    final state = provider.state;
    final items = state.data;
    final failure = provider.actionFailure;
    return switch (state.status) {
      ViewStatus.empty => EmptyView(icon: emptyIcon, title: emptyTitle),
      ViewStatus.error when items == null => ErrorView(
        message: state.failure!.message,
        onRetry: provider.load,
      ),
      _ when items == null => const LoadingView(),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                failure,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                builder(context, items),
                if (provider.hasMore)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: OutlinedButton(
                        onPressed: provider.isLoadingMore
                            ? null
                            : provider.loadMore,
                        child: Text(
                          provider.isLoadingMore ? 'Loading...' : 'Load more',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    };
  }
}

/// A table that scrolls sideways on a narrow window rather than overflowing.
class AdminTable extends StatelessWidget {
  const AdminTable({required this.columns, required this.rows, super.key});

  final List<String> columns;
  final List<DataRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          dataRowMaxHeight: 72,
          columnSpacing: 28,
          columns: [
            for (final column in columns) DataColumn(label: Text(column)),
          ],
          rows: rows,
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, this.isBad = false, super.key});

  final String label;
  final bool isBad;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isBad ? AppColors.dangerSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isBad ? AppColors.danger : AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A photo that stays tidy if it is missing.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({required this.url, this.size = 48, super.key});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    const placeholder = ColoredBox(
      color: AppColors.primarySoft,
      child: Icon(Icons.image_outlined, color: AppColors.primary),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: url == null
            ? placeholder
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => placeholder,
              ),
      ),
    );
  }
}

/// Asks for confirmation, with a reason if [reasonRequired] or [reasonLabel] is
/// given. Returns null if cancelled, and the reason (maybe empty) if confirmed.
Future<String?> askToConfirm(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,
  String? reasonLabel,
  bool reasonRequired = false,
  bool isDanger = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ConfirmDialog(
      title: title,
      confirmLabel: confirmLabel,
      message: message,
      reasonLabel: reasonLabel,
      reasonRequired: reasonRequired,
      isDanger: isDanger,
    ),
  );
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.title,
    required this.confirmLabel,
    required this.message,
    required this.reasonLabel,
    required this.reasonRequired,
    required this.isDanger,
  });

  final String title;
  final String confirmLabel;
  final String? message;
  final String? reasonLabel;
  final bool reasonRequired;
  final bool isDanger;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.reasonLabel;
    final canConfirm = !widget.reasonRequired || _reason.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) Text(widget.message!),
            if (label != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                autofocus: true,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(labelText: label),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: widget.isDanger
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: canConfirm
              ? () => Navigator.of(context).pop(_reason.text.trim())
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
