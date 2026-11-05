import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// A rounded choice, filled purple when selected. Without [onSelected] it shows
/// as unavailable.
class PillChip extends StatelessWidget {
  const PillChip({
    required this.label,
    required this.selected,
    this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final onSelected = this.onSelected;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : onSelected == null
            ? AppColors.textSecondary
            : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      onSelected: onSelected == null ? null : (_) => onSelected(),
    );
  }
}
