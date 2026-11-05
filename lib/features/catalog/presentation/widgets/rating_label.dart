import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// A star, the average and how many ratings. Shows "New" before the first one.
class RatingLabel extends StatelessWidget {
  const RatingLabel({
    required this.average,
    required this.count,
    this.style,
    super.key,
  });

  final double average;
  final int count;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? Theme.of(context).textTheme.bodySmall;
    if (count == 0) {
      return Text(
        'New',
        style: textStyle?.copyWith(color: AppColors.textSecondary),
      );
    }
    return Semantics(
      label: 'Rated ${average.toStringAsFixed(1)} out of 5, $count ratings',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 16, color: AppColors.rating),
            const SizedBox(width: 2),
            Text(average.toStringAsFixed(1), style: textStyle),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '($count)',
                overflow: TextOverflow.ellipsis,
                style: textStyle?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
