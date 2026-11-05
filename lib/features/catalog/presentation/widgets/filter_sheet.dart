import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/pill_chip.dart';
import '../../domain/entities/product_filters.dart';

/// Asks for sort order and filters. Returns the new filters, or null if closed.
Future<ProductFilters?> showFilterSheet(
  BuildContext context,
  ProductFilters filters,
) {
  return showModalBottomSheet<ProductFilters>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => _FilterSheet(filters: filters),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filters});

  final ProductFilters filters;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  static const _ratings = {'Any': null, '3+': 3.0, '4+': 4.0, '4.5+': 4.5};

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minPrice;
  late final TextEditingController _maxPrice;
  late ProductSort? _sort = widget.filters.sort;
  late ProductConditionFilter? _condition = widget.filters.condition;
  late double? _minRating = widget.filters.minRating;
  late bool _inStockOnly = widget.filters.inStockOnly;

  @override
  void initState() {
    super.initState();
    _minPrice = TextEditingController(
      text: _priceText(widget.filters.minPrice),
    );
    _maxPrice = TextEditingController(
      text: _priceText(widget.filters.maxPrice),
    );
  }

  @override
  void dispose() {
    _minPrice.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  static String _priceText(double? price) =>
      price == null ? '' : price.toStringAsFixed(0);

  static double? _parsePrice(String text) => double.tryParse(text.trim());

  void _clearAll() {
    setState(() {
      _sort = null;
      _condition = null;
      _minRating = null;
      _inStockOnly = false;
      _minPrice.clear();
      _maxPrice.clear();
    });
  }

  void _apply() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      widget.filters.withRefinements(
        minPrice: _parsePrice(_minPrice.text),
        maxPrice: _parsePrice(_maxPrice.text),
        condition: _condition,
        minRating: _minRating,
        inStockOnly: _inStockOnly,
        sort: _sort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = widget.filters.hasQuery;
    final sortChoices = <(ProductSort?, String)>[
      (null, hasQuery ? 'Best match' : 'Newest'),
      if (hasQuery) (ProductSort.newest, 'Newest'),
      (ProductSort.popular, 'Most popular'),
      (ProductSort.priceLow, 'Price: low to high'),
      (ProductSort.priceHigh, 'Price: high to low'),
      (ProductSort.rating, 'Top rated'),
    ];
    final sectionStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Filters', style: theme.textTheme.titleLarge),
                    ),
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Sort by', style: sectionStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (sort, label) in sortChoices)
                      PillChip(
                        label: label,
                        selected: _sort == sort,
                        onSelected: () => setState(() => _sort = sort),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Price (৳)', style: sectionStyle),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PriceField(
                        controller: _minPrice,
                        label: 'Min price',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PriceField(
                        controller: _maxPrice,
                        label: 'Max price',
                        validator: (value) {
                          final min = _parsePrice(_minPrice.text);
                          final max = _parsePrice(value ?? '');
                          if (min != null && max != null && max < min) {
                            return 'Must be above min';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Condition', style: sectionStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    PillChip(
                      label: 'Any',
                      selected: _condition == null,
                      onSelected: () => setState(() => _condition = null),
                    ),
                    PillChip(
                      label: 'New',
                      selected: _condition == ProductConditionFilter.isNew,
                      onSelected: () => setState(
                        () => _condition = ProductConditionFilter.isNew,
                      ),
                    ),
                    PillChip(
                      label: 'Used',
                      selected: _condition == ProductConditionFilter.used,
                      onSelected: () => setState(
                        () => _condition = ProductConditionFilter.used,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Rating', style: sectionStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final MapEntry(key: label, value: rating)
                        in _ratings.entries)
                      PillChip(
                        label: label,
                        selected: _minRating == rating,
                        onSelected: () => setState(() => _minRating = rating),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('In stock only'),
                  value: _inStockOnly,
                  onChanged: (value) => setState(() => _inStockOnly = value),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Text('Show results'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.label,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
      ],
    );
  }
}
