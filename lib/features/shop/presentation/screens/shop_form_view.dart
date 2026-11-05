import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/busy_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../providers/shop_form_provider.dart';

/// The shop details form, used both to open a shop and to edit it.
class ShopFormView extends StatefulWidget {
  const ShopFormView({required this.onSaved, super.key});

  final ValueChanged<String> onSaved;

  @override
  State<ShopFormView> createState() => _ShopFormViewState();
}

class _ShopFormViewState extends State<ShopFormView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _deliveryFee = TextEditingController();
  final _payoutNumber = TextEditingController();
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  bool _filled = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _deliveryFee.dispose();
    _payoutNumber.dispose();
    super.dispose();
  }

  void _fillOnce(ShopFormProvider provider) {
    final shop = provider.existing;
    if (_filled || provider.regions.status != ViewStatus.success) return;
    _filled = true;
    if (shop == null) return;
    _name.text = shop.name;
    _description.text = shop.description;
    _deliveryFee.text = shop.deliveryFee.toStringAsFixed(0);
  }

  Future<void> _pickLogo(ShopFormProvider provider) async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (photo != null) await provider.setLogo(await photo.readAsBytes());
  }

  Future<void> _save(ShopFormProvider provider) async {
    final isNew = provider.existing == null;
    final isValid = _formKey.currentState!.validate();
    setState(() => _showTermsError = isNew && !_acceptedTerms);
    if (!isValid || _showTermsError) return;
    final shopId = await provider.save(
      name: _name.text.trim(),
      description: _description.text.trim(),
      deliveryFee: double.parse(_deliveryFee.text.trim()),
      payoutNumber: _payoutNumber.text.trim(),
      acceptedTerms: _acceptedTerms,
    );
    if (shopId != null) widget.onSaved(shopId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShopFormProvider>();
    final theme = Theme.of(context);
    final regions = provider.regions;
    if (regions.status == ViewStatus.error) {
      return ErrorView(
        message: regions.failure!.message,
        onRetry: provider.load,
      );
    }
    if (regions.status != ViewStatus.success) return const LoadingView();
    _fillOnce(provider);
    final isNew = provider.existing == null;
    final logo = provider.logo;
    return SingleChildScrollView(
      // Number keyboards have no key to close them.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isNew) ...[
              Text('Open your shop', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('You need a shop before you can post products.'),
              const SizedBox(height: 16),
            ],
            if (provider.saveFailure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  provider.saveFailure!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primarySoft,
                  foregroundImage: logo == null ? null : MemoryImage(logo),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => _pickLogo(provider),
                  child: const Text('Choose logo'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Shop name',
                counterText: '',
              ),
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? 'Please enter your shop name'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLength: 2000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'About your shop (optional)',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: provider.divisionId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Division'),
              items: [
                for (final region in provider.divisions)
                  DropdownMenuItem(value: region.id, child: Text(region.name)),
              ],
              onChanged: provider.selectDivision,
              validator: (value) =>
                  value == null ? 'Please choose a division' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(provider.divisionId),
              initialValue: provider.districtId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'District'),
              items: [
                for (final region in provider.districts)
                  DropdownMenuItem(value: region.id, child: Text(region.name)),
              ],
              onChanged: provider.selectDistrict,
              validator: (value) =>
                  value == null ? 'Please choose a district' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deliveryFee,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'Delivery fee (৳)',
                helperText:
                    'One flat fee for each order. You arrange delivery.',
              ),
              validator: (value) =>
                  Validators.required(value, 'a delivery fee'),
            ),
            if (isNew) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _payoutNumber,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'bKash or contact number (optional)',
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? null
                    : Validators.phone(value),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _acceptedTerms,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) =>
                    setState(() => _acceptedTerms = value ?? false),
                title: const Text(
                  'I agree to sell at fixed prices, and to pay Browsly 1% '
                  'commission on the listing price of each completed order.',
                ),
                subtitle: _showTermsError
                    ? const Text(
                        'Please accept to continue',
                        style: TextStyle(color: AppColors.danger),
                      )
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            BusyButton(
              label: isNew ? 'Open shop' : 'Save shop',
              isBusy: provider.isSaving,
              onPressed: () => _save(provider),
            ),
          ],
        ),
      ),
    );
  }
}
