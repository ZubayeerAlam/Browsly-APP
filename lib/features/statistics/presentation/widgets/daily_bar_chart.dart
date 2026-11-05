import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';

class ChartPoint {
  const ChartPoint({required this.day, required this.value});

  final DateTime day;
  final double value;
}

/// One measure per day, on one axis. Tapping a bar shows its exact value, and
/// the top of the scale and the date range are labelled in plain text.
class DailyBarChart extends StatelessWidget {
  const DailyBarChart({
    required this.points,
    required this.formatValue,
    required this.label,
    super.key,
  });

  static const _height = 140.0;

  final List<ChartPoint> points;
  final String Function(double value) formatValue;

  /// What the chart measures, for screen readers.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = points.fold<double>(
      0,
      (highest, point) => point.value > highest ? point.value : highest,
    );
    final total = points.fold<double>(0, (sum, point) => sum + point.value);
    final dayFormat = DateFormat('d MMM', 'en_US');
    return Semantics(
      label:
          '$label over ${points.length} days. Total ${formatValue(total)}, '
          'highest day ${formatValue(maxValue)}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Highest day: ${formatValue(maxValue)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _height,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final point in points)
                    Expanded(
                      child: Tooltip(
                        message:
                            '${dayFormat.format(point.day)}: '
                            '${formatValue(point.value)}',
                        triggerMode: TooltipTriggerMode.tap,
                        // The whole column is the target, so a short bar is
                        // still easy to tap.
                        child: Container(
                          color: Colors.transparent,
                          alignment: Alignment.bottomCenter,
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: _Bar(
                            fraction: maxValue == 0
                                ? 0
                                : point.value / maxValue,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (points.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dayFormat.format(points.first.day),
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  dayFormat.format(points.last.day),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    if (fraction == 0) return const SizedBox(width: double.infinity, height: 0);
    return FractionallySizedBox(
      heightFactor: fraction,
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: const BoxConstraints(minHeight: 2, maxWidth: 24),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ),
    );
  }
}
