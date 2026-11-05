import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/buying_errors.dart';
import '../../../../core/widgets/busy_button.dart';
import '../../domain/repositories/review_repository.dart';

/// Returns true if a review was saved.
Future<bool> showWriteReviewSheet(
  BuildContext context, {
  required String orderItemId,
  required String productTitle,
}) async {
  final repository = context.read<ReviewRepository>();
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _WriteReviewSheet(
      repository: repository,
      orderItemId: orderItemId,
      productTitle: productTitle,
    ),
  );
  return saved ?? false;
}

class _WriteReviewSheet extends StatefulWidget {
  const _WriteReviewSheet({
    required this.repository,
    required this.orderItemId,
    required this.productTitle,
  });

  final ReviewRepository repository;
  final String orderItemId;
  final String productTitle;

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _isBusy = false;
  String? _failure;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isBusy = true;
      _failure = null;
    });
    try {
      final comment = _comment.text.trim();
      await widget.repository.submit(
        widget.orderItemId,
        _rating,
        comment: comment.isEmpty ? null : comment,
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
                'Review ${widget.productTitle}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      tooltip: '$star out of 5',
                      iconSize: 36,
                      icon: Icon(
                        star <= _rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: AppColors.rating,
                      ),
                      onPressed: () => setState(() => _rating = star),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _comment,
                maxLength: 1000,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Your review (optional)',
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
                label: 'Submit review',
                isBusy: _isBusy,
                onPressed: _rating == 0 ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
