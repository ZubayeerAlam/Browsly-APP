import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';

/// Items, delivery and total, as shown on the cart, checkout and order screens.
class OrderTotals extends StatelessWidget {
  const OrderTotals({
    required this.subtotal,
    required this.delivery,
    required this.total,
    this.totalLabel = 'Total',
    super.key,
  });

  final double subtotal;
  final double delivery;
  final double total;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _row('Items', formatTaka(subtotal), theme.textTheme.bodyMedium),
        const SizedBox(height: 2),
        _row('Delivery', formatTaka(delivery), theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        _row(
          totalLabel,
          formatTaka(total),
          theme.textTheme.titleMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value, TextStyle? style) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
