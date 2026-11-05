import 'package:flutter/material.dart';

import '../../../../core/widgets/pill_chip.dart';
import '../../domain/entities/category.dart';

/// All, then each top-level category with how many products it holds.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    required this.categories,
    required this.totalCount,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<Category> categories;
  final int totalCount;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(56),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          PillChip(
            label: 'All ($totalCount)',
            selected: selectedId == null,
            onSelected: () => onSelected(null),
          ),
          for (final category in categories) ...[
            const SizedBox(width: 8),
            PillChip(
              label: '${category.name} (${category.productCount})',
              selected: selectedId == category.id,
              onSelected: () => onSelected(category.id),
            ),
          ],
        ],
      ),
    );
  }
}
