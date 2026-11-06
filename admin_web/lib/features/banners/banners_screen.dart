import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../core/errors/app_failure.dart';
import '../../core/formatters.dart';
import '../../core/state/paged_provider.dart';
import '../../core/widgets/admin_page.dart';
import 'banners_data.dart';

typedef _Provider = PagedProvider<AdminBanner, Never>;

class BannersScreen extends StatelessWidget {
  const BannersScreen({super.key});

  Future<void> _edit(BuildContext context, [AdminBanner? existing]) async {
    final provider = context.read<_Provider>();
    final repository = context.read<BannersRepository>();
    final input = await showDialog<BannerInput>(
      context: context,
      builder: (context) =>
          _BannerDialog(repository: repository, existing: existing),
    );
    if (input != null) {
      await provider.act(() => repository.save(existing?.id, input));
    }
  }

  Future<void> _delete(BuildContext context, AdminBanner banner) async {
    final provider = context.read<_Provider>();
    final repository = context.read<BannersRepository>();
    final answer = await askToConfirm(
      context,
      title: 'Delete this banner?',
      message: 'It leaves the home screen straight away.',
      confirmLabel: 'Delete',
      isDanger: true,
    );
    if (answer != null) await provider.act(() => repository.delete(banner.id));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final repository = context.read<BannersRepository>();
        return _Provider((search, filter, next) => repository.getBanners())
          ..load();
      },
      child: Builder(
        builder: (context) {
          final provider = context.watch<_Provider>();
          return AdminPage(
            title: 'Banners',
            actions: [
              FilledButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add banner'),
              ),
            ],
            child: PagedBody(
              provider: provider,
              emptyIcon: Icons.view_carousel_outlined,
              emptyTitle: 'No banners yet',
              builder: (context, items) => AdminTable(
                columns: const ['', 'Title', 'Order', 'Until', 'Status', ''],
                rows: [
                  for (final banner in items)
                    DataRow(
                      cells: [
                        DataCell(PhotoThumb(url: banner.imageUrl)),
                        DataCell(
                          Text(banner.title.isEmpty ? '–' : banner.title),
                        ),
                        DataCell(Text('${banner.sortOrder}')),
                        DataCell(
                          Text(
                            banner.endsAt == null
                                ? 'No end date'
                                : formatDate(banner.endsAt!),
                          ),
                        ),
                        DataCell(
                          StatusPill(
                            label: banner.isActive ? 'Showing' : 'Hidden',
                            isBad: !banner.isActive,
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => _edit(context, banner),
                                child: const Text('Edit'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                ),
                                onPressed: () => _delete(context, banner),
                                child: const Text('Delete'),
                              ),
                            ],
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

class _BannerDialog extends StatefulWidget {
  const _BannerDialog({required this.repository, this.existing});

  final BannersRepository repository;
  final AdminBanner? existing;

  @override
  State<_BannerDialog> createState() => _BannerDialogState();
}

class _BannerDialogState extends State<_BannerDialog> {
  late final TextEditingController _title;
  late final TextEditingController _productId;
  late final TextEditingController _order;
  late bool _isActive;
  DateTime? _endsAt;
  String? _imagePath;
  Uint8List? _preview;
  bool _isUploading = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title);
    _productId = TextEditingController(text: existing?.productId);
    _order = TextEditingController(text: '${existing?.sortOrder ?? 0}');
    _isActive = existing?.isActive ?? true;
    _endsAt = existing?.endsAt;
    _imagePath = existing?.imagePath;
  }

  @override
  void dispose() {
    _title.dispose();
    _productId.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      _isUploading = true;
      _failure = null;
    });
    try {
      final bytes = await file.readAsBytes();
      final isPng = (file.mimeType ?? file.name).toLowerCase().contains('png');
      final path = await widget.repository.uploadImage(bytes, isPng: isPng);
      if (mounted) {
        setState(() {
          _imagePath = path;
          _preview = bytes;
        });
      }
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _failure = failure.message);
    }
    if (mounted) setState(() => _isUploading = false);
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      initialDate: _endsAt ?? now.add(const Duration(days: 30)),
    );
    if (date != null) setState(() => _endsAt = date);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final existing = widget.existing;
    return AlertDialog(
      title: Text(existing == null ? 'Add banner' : 'Edit banner'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (preview != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(preview, width: 96, height: 54),
                    )
                  else if (existing != null)
                    PhotoThumb(url: existing.imageUrl, size: 54),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _isUploading ? null : _pickImage,
                    child: Text(
                      _isUploading
                          ? 'Uploading...'
                          : _imagePath == null
                          ? 'Choose image'
                          : 'Change image',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'A wide JPG or PNG under 5 MB. About 3 times wider than tall '
                'looks best.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (_failure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _failure!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              TextField(
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Title (optional)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _productId,
                decoration: const InputDecoration(
                  labelText: 'Product ID to open (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Order'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _endsAt == null
                          ? 'No end date'
                          : 'Until ${formatDate(_endsAt!)}',
                    ),
                  ),
                  TextButton(
                    onPressed: _pickEndDate,
                    child: const Text('Choose date'),
                  ),
                  if (_endsAt != null)
                    TextButton(
                      onPressed: () => setState(() => _endsAt = null),
                      child: const Text('Clear'),
                    ),
                ],
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
          onPressed: _imagePath == null || _isUploading
              ? null
              : () {
                  final productId = _productId.text.trim();
                  Navigator.of(context).pop(
                    BannerInput(
                      imagePath: _imagePath!,
                      title: _title.text.trim(),
                      productId: productId.isEmpty ? null : productId,
                      sortOrder: int.tryParse(_order.text.trim()) ?? 0,
                      isActive: _isActive,
                      endsAt: _endsAt,
                    ),
                  );
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
