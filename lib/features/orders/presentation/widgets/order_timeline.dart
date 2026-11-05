import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/order.dart';

/// Pending → Packaging → Out for delivery → Complete, with when each happened.
/// A cancelled or failed order stops at the step it reached.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({required this.status, required this.history, super.key});

  static const _steps = [
    OrderStatus.pending,
    OrderStatus.packaging,
    OrderStatus.outForDelivery,
    OrderStatus.completed,
  ];

  final OrderStatus status;
  final List<OrderStatusEvent> history;

  OrderStatusEvent? _eventFor(OrderStatus step) {
    return history.where((event) => event.status == step).lastOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final closed = status.isClosedWithoutPayment;
    final steps = closed
        ? [..._steps.where((step) => _eventFor(step) != null), status]
        : _steps;
    final currentIndex = steps.indexOf(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, step) in steps.indexed)
          _TimelineRow(
            label: step.label,
            event: _eventFor(step),
            isDone: index <= currentIndex,
            isCurrent: index == currentIndex,
            isFailure: step.isClosedWithoutPayment,
            isLast: index == steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.event,
    required this.isDone,
    required this.isCurrent,
    required this.isFailure,
    required this.isLast,
  });

  final String label;
  final OrderStatusEvent? event;
  final bool isDone;
  final bool isCurrent;
  final bool isFailure;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isFailure
        ? AppColors.danger
        : isDone
        ? AppColors.primary
        : AppColors.border;
    final event = this.event;
    final note = event?.note;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(
                isFailure
                    ? Icons.cancel_rounded
                    : isDone
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: color,
                size: 20,
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: AppColors.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                      color: isDone ? null : AppColors.textSecondary,
                    ),
                  ),
                  if (event != null)
                    Text(
                      formatDateTime(event.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  if (note != null)
                    Text(note, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
