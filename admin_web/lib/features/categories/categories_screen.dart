import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/paged_provider.dart';
import '../../core/widgets/admin_page.dart';
import 'categories_data.dart';

typedef _Provider = PagedProvider<AdminCategory, Never>;

/// The icon names the mobile app knows how to draw.
const _icons = [
  'category',
  'checkroom',
  'devices',
  'chair',
  'spa',
  'sports_soccer',
  'menu_book',
];

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    List<AdminCategory> all, [
    AdminCategory? existing,
  ]) async {
    final provider = context.read<_Provider>();
    final repository = context.read<CategoriesRepository>();
    final input = await showDialog<CategoryInput>(
      context: context,
      builder: (context) => _CategoryDialog(all: all, existing: existing),
    );
    if (input != null) {
      await provider.act(() => repository.save(existing?.id, input));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final repository = context.read<CategoriesRepository>();
        return _Provider((search, filter, next) => repository.getCategories())
          ..load();
      },
      child: Builder(
        builder: (context) {
          final provider = context.watch<_Provider>();
          final all = provider.state.data ?? const <AdminCategory>[];
          final namesById = {for (final c in all) c.id: c.name};
          return AdminPage(
            title: 'Categories',
            actions: [
              FilledButton.icon(
                onPressed: () => _edit(context, all),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add category'),
              ),
            ],
            child: PagedBody(
              provider: provider,
              emptyTitle: 'No categories yet',
              builder: (context, items) => AdminTable(
                columns: const [
                  'Name',
                  'Inside',
                  'Web name',
                  'Order',
                  'Products',
                  'Status',
                  '',
                ],
                rows: [
                  for (final category in items)
                    DataRow(
                      cells: [
                        DataCell(Text(category.name)),
                        DataCell(Text(namesById[category.parentId] ?? '–')),
                        DataCell(Text(category.slug)),
                        DataCell(Text('${category.sortOrder}')),
                        DataCell(Text('${category.productCount}')),
                        DataCell(
                          StatusPill(
                            label: category.isActive ? 'Active' : 'Hidden',
                            isBad: !category.isActive,
                          ),
                        ),
                        DataCell(
                          TextButton(
                            onPressed: () => _edit(context, all, category),
                            child: const Text('Edit'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.all, this.existing});

  final List<AdminCategory> all;
  final AdminCategory? existing;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _order;
  late String? _parentId;
  late String _icon;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name);
    _slug = TextEditingController(text: existing?.slug);
    _order = TextEditingController(text: '${existing?.sortOrder ?? 0}');
    _parentId = existing?.parentId;
    _icon = existing?.icon ?? _icons.first;
    _isActive = existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final parents = widget.all
        .where((c) => c.parentId == null && c.id != existing?.id)
        .toList();
    return AlertDialog(
      title: Text(existing == null ? 'Add category' : 'Edit category'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _slug,
                decoration: const InputDecoration(
                  labelText: 'Web name',
                  helperText: 'Small letters and dashes, such as home-living',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _parentId,
                decoration: const InputDecoration(labelText: 'Inside'),
                items: [
                  const DropdownMenuItem(child: Text('Nothing (top level)')),
                  for (final parent in parents)
                    DropdownMenuItem(
                      value: parent.id,
                      child: Text(parent.name),
                    ),
                ],
                onChanged: (value) => setState(() => _parentId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _icons.contains(_icon) ? _icon : _icons.first,
                decoration: const InputDecoration(labelText: 'Icon'),
                items: [
                  for (final icon in _icons)
                    DropdownMenuItem(value: icon, child: Text(icon)),
                ],
                onChanged: (value) => setState(() => _icon = value ?? _icon),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Order in lists'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show in the app'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            CategoryInput(
              parentId: _parentId,
              name: _name.text.trim(),
              slug: _slug.text.trim(),
              icon: _icon,
              sortOrder: int.tryParse(_order.text.trim()) ?? 0,
              isActive: _isActive,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
