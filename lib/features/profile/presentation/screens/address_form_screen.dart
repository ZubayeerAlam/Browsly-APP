import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/state/view_state.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/busy_button.dart';
import '../../../../core/widgets/failure_banner.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/address.dart';
import '../../domain/entities/region.dart';
import '../providers/address_form_provider.dart';

class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({this.existing, super.key});

  final Address? existing;

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _line1;
  late final TextEditingController _postalCode;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.recipientName);
    _phone = TextEditingController(text: existing?.phone);
    _line1 = TextEditingController(text: existing?.line1);
    _postalCode = TextEditingController(text: existing?.postalCode);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _line1.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final postalCode = _postalCode.text.trim();
    final saved = await context.read<AddressFormProvider>().save(
      recipientName: _name.text.trim(),
      phone: Validators.normalizeBangladeshPhone(_phone.text)!,
      line1: _line1.text.trim(),
      postalCode: postalCode.isEmpty ? null : postalCode,
    );
    if (saved && mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AddressFormProvider>();
    final regions = provider.regions;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add address' : 'Edit address'),
      ),
      body: switch (regions.status) {
        ViewStatus.error => ErrorView(
          message: regions.failure!.message,
          onRetry: provider.loadRegions,
        ),
        ViewStatus.success => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                FailureBanner(failure: provider.saveFailure),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: Validators.name,
                  decoration: const InputDecoration(
                    labelText: 'Recipient name',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: Validators.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    hintText: '01712345678',
                  ),
                ),
                const SizedBox(height: 16),
                _RegionDropdown(
                  label: 'Division',
                  value: provider.divisionId,
                  regions: provider.divisions,
                  onChanged: provider.selectDivision,
                ),
                const SizedBox(height: 16),
                _RegionDropdown(
                  // A new key clears the field when the division changes.
                  key: ValueKey(provider.divisionId),
                  label: 'District',
                  value: provider.districtId,
                  regions: provider.districts,
                  onChanged: provider.selectDistrict,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _line1,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  validator: (value) =>
                      Validators.required(value, 'your house, road and area'),
                  decoration: const InputDecoration(
                    labelText: 'House, road and area',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _postalCode,
                  keyboardType: TextInputType.number,
                  validator: Validators.postalCode,
                  decoration: const InputDecoration(
                    labelText: 'Postal code (optional)',
                  ),
                ),
                const SizedBox(height: 24),
                BusyButton(
                  label: 'Save address',
                  isBusy: provider.isSaving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _RegionDropdown extends StatelessWidget {
  const _RegionDropdown({
    required this.label,
    required this.value,
    required this.regions,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String? value;
  final List<Region> regions;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      validator: (selected) => selected == null ? 'Please choose $label' : null,
      items: [
        for (final region in regions)
          DropdownMenuItem(value: region.id, child: Text(region.name)),
      ],
      onChanged: onChanged,
    );
  }
}
