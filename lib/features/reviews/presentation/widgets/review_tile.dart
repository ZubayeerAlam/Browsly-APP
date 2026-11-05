import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../reports/presentation/widgets/report_sheet.dart';
import '../../domain/entities/review.dart';

class StarRow extends StatelessWidget {
  const StarRow({required this.rating, this.size = 16, super.key});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rating out of 5 stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var star = 1; star <= 5; star++)
              Icon(
                star <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                size: size,
                color: AppColors.rating,
              ),
          ],
        ),
      ),
    );
  }
}

class ReviewTile extends StatelessWidget {
  const ReviewTile({required this.review, super.key});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRow(rating: review.rating),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${review.reviewerName} · ${formatDate(review.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: 'Report this review',
                icon: const Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => showReportSheet(
                  context,
                  targetType: ReportTarget.review,
                  targetId: review.id,
                  title: 'Report this review',
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) Text(review.comment),
        ],
      ),
    );
  }
}
