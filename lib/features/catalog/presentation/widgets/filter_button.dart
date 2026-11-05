import 'package:flutter/material.dart';

/// The filter icon, with a count of the filters in use.
class FilterButton extends StatelessWidget {
  const FilterButton({required this.count, required this.onPressed, super.key});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: count == 0 ? 'Filters' : 'Filters, $count in use',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.tune_rounded),
      ),
    );
  }
}
