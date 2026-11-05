import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/busy_button.dart';
import '../../../../core/widgets/pill_chip.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../profile/domain/repositories/address_repository.dart';
import '../../../shop/domain/repositories/shop_repository.dart';
import '../../../shop/presentation/providers/shop_form_provider.dart';
import '../../../shop/presentation/screens/shop_form_view.dart';
import '../../domain/entities/listing.dart';
import '../providers/product_form_provider.dart';

class PostScreen extends StatelessWidget {
  const PostScreen({this.backTo, super.key});

  /// Where to return to.
  final String? backTo;

  Future<void> _leave(BuildContext context, ProductFormProvider form) async {
    if (form.loadState == FormLoadState.ready && form.step > 0) {
      form.goToStep(form.step - 1);
      return;
    }
    if (form.isDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard your changes?'),
          content: const Text('Anything you have not saved will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !context.mounted) return;
    }
    context.go(backTo ?? AppRoutes.dashboard);
  }

  Future<void> _saveDraft(
    BuildContext context,
    ProductFormProvider form,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await form.saveDraft()) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            form.isEditing && !form.status.isSubmittable
                ? 'Changes saved.'
                : 'Draft saved.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = context.watch<ProductFormProvider>();
    final isReady = form.loadState == FormLoadState.ready;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(context, form);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(form.isEditing ? 'Edit listing' : 'Post'),
          centerTitle: true,
          leading: BackButton(onPressed: () => _leave(context, form)),
          actions: [
            if (isReady)
              TextButton(
                onPressed: form.isBusy ? null : () => _saveDraft(context, form),
                child: const Text('Save'),
              ),
          ],
        ),
        body: switch (form.loadState) {
          FormLoadState.loading => const LoadingView(),
          FormLoadState.failed => ErrorView(
            message: form.loadFailure!.message,
            onRetry: form.load,
          ),
          FormLoadState.notFound => const EmptyView(
            icon: Icons.inventory_2_outlined,
            title: 'This listing is not available',
          ),
          FormLoadState.needsShop => ChangeNotifierProvider(
            create: (context) => ShopFormProvider(
              context.read<ShopRepository>(),
              context.read<AddressRepository>(),
            )..load(),
            child: ShopFormView(onSaved: (_) => form.load()),
          ),
          FormLoadState.ready => _FormSteps(form: form),
        },
      ),
    );
  }
}

class _FormSteps extends StatefulWidget {
  const _FormSteps({required this.form});

  final ProductFormProvider form;

  @override
  State<_FormSteps> createState() => _FormStepsState();
}

class _FormStepsState extends State<_FormSteps> {
  static const _stepNames = ['Basics', 'Description', 'Options', 'Preview'];

  final _basicsKey = GlobalKey<FormState>();
  String? _stepProblem;

  void _next() {
    final form = widget.form;
    if (form.step == 0 && !_basicsKey.currentState!.validate()) return;
    final problem = form.validateStep(form.step);
    setState(() => _stepProblem = problem);
    if (problem == null) form.goToStep(form.step + 1);
  }

  Future<void> _submit() async {
    final form = widget.form;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final wasSubmittable = form.status.isSubmittable;
    if (await form.submit()) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            wasSubmittable || form.status == ListingStatus.inReview
                ? 'Submitted. We will let you know after the review.'
                : 'Changes saved.',
          ),
        ),
      );
      router.go(AppRoutes.myPosts);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final problem = form.failure ?? _stepProblem;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (form.step + 1) / ProductFormProvider.stepCount,
                semanticsLabel: 'Step ${form.step + 1} of 4',
              ),
              const SizedBox(height: 4),
              Text(
                'Step ${form.step + 1} of 4: ${_stepNames[form.step]}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            // Number keyboards have no key to close them.
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (problem != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      problem,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                if (form.warnsAboutReview && form.step == 0)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Price and stock changes stay live. Changing anything '
                      'else sends this listing back for review.',
                    ),
                  ),
                switch (form.step) {
                  0 => _BasicsStep(form: form, formKey: _basicsKey),
                  1 => _DescriptionStep(form: form),
                  2 => _OptionsStep(form: form),
                  _ => _PreviewStep(form: form),
                },
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: form.step < ProductFormProvider.stepCount - 1
                ? SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(switch (form.step) {
                        0 => 'Next: Add Description',
                        1 => 'Next: Colours and Sizes',
                        _ => 'Next: Preview',
                      }),
                    ),
                  )
                : BusyButton(
                    label: form.status.isSubmittable
                        ? 'Submit for review'
                        : 'Save changes',
                    isBusy: form.isBusy,
                    onPressed: _submit,
                  ),
          ),
        ),
      ],
    );
  }
}

class _BasicsStep extends StatelessWidget {
  const _BasicsStep({required this.form, required this.formKey});

  final ProductFormProvider form;
  final GlobalKey<FormState> formKey;

  Future<void> _pickPhotos() async {
    final space = ProductFormProvider.maxPhotos - form.photos.length;
    if (space <= 0) return;
    // Location data is removed by the provider. This setting alone doesn't do it.
    final picked = await ImagePicker().pickMultiImage(
      limit: space > 1 ? space : null,
      requestFullMetadata: false,
    );
    if (picked.isEmpty) return;
    await form.addPhotos(
      await Future.wait(picked.map((photo) => photo.readAsBytes())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            form.isEditing ? 'Edit Your Listing' : 'Create Your Listing',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Upload Photos (JPG, PNG, max ${ProductFormProvider.maxPhotos})',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final photo in form.photos)
                _PhotoTile(
                  photo: photo,
                  onRemove: () => form.removePhoto(photo),
                ),
              if (form.photos.length < ProductFormProvider.maxPhotos)
                Semantics(
                  button: true,
                  label: 'Add photos',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickPhotos,
                    child: Ink(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: form.title,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Product name',
              counterText: '',
            ),
            onChanged: (value) {
              form.title = value;
              form.markDirty();
            },
            validator: (value) => (value?.trim().length ?? 0) < 3
                ? 'Please enter at least 3 characters'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: form.categoryId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final choice in form.categories)
                DropdownMenuItem(value: choice.id, child: Text(choice.label)),
            ],
            onChanged: form.setCategory,
            validator: (value) =>
                value == null ? 'Please choose a category' : null,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _moneyText(form.price),
                  keyboardType: TextInputType.number,
                  inputFormatters: _digits(9),
                  decoration: const InputDecoration(labelText: 'Price (৳)'),
                  onChanged: (value) {
                    form.price = double.tryParse(value);
                    form.markDirty();
                  },
                  validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                      ? 'Please enter a price'
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: form.stock?.toString() ?? '',
                  keyboardType: TextInputType.number,
                  inputFormatters: _digits(6),
                  decoration: const InputDecoration(labelText: 'Stock'),
                  onChanged: (value) {
                    form.stock = int.tryParse(value);
                    form.markDirty();
                  },
                  validator: (value) => int.tryParse(value ?? '') == null
                      ? 'Please enter the stock'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _moneyText(form.compareAtPrice),
            keyboardType: TextInputType.number,
            inputFormatters: _digits(9),
            decoration: const InputDecoration(
              labelText: 'Original price (optional)',
              helperText:
                  'Shows a discount. Buyers always pay the price above.',
            ),
            onChanged: (value) {
              form.compareAtPrice = double.tryParse(value);
              form.markDirty();
            },
            validator: (value) {
              final compare = double.tryParse(value ?? '');
              final price = form.price;
              if (compare != null && price != null && compare <= price) {
                return 'Must be higher than the price';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              PillChip(
                label: 'New',
                selected: form.isNew,
                onSelected: () => form.setIsNew(true),
              ),
              const SizedBox(width: 8),
              PillChip(
                label: 'Used',
                selected: !form.isNew,
                onSelected: () => form.setIsNew(false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _moneyText(double? value) =>
    value == null ? '' : value.toStringAsFixed(0);

List<TextInputFormatter> _digits(int length) => [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(length),
];

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, this.onRemove});

  final FormPhoto photo;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final bytes = photo.bytes;
    return SizedBox.square(
      dimension: 88,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 300)
                : AppNetworkImage(url: photo.url, displayWidth: 88),
          ),
          if (onRemove != null)
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                tooltip: 'Remove photo',
                style: IconButton.styleFrom(backgroundColor: Colors.white70),
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onRemove,
              ),
            ),
        ],
      ),
    );
  }
}

class _DescriptionStep extends StatelessWidget {
  const _DescriptionStep({required this.form});

  final ProductFormProvider form;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: form.description,
      maxLength: 5000,
      minLines: 6,
      maxLines: 12,
      decoration: const InputDecoration(
        labelText: 'Description',
        alignLabelWithHint: true,
        helperText:
            'Describe the condition, size and materials. Please do not add '
            'phone numbers or links.',
        helperMaxLines: 2,
      ),
      onChanged: (value) {
        form.description = value;
        form.markDirty();
      },
    );
  }
}

class _OptionsStep extends StatelessWidget {
  const _OptionsStep({required this.form});

  final ProductFormProvider form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Colours and sizes (optional)',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text('Skip this if your product comes in one version.'),
        const SizedBox(height: 16),
        _OptionEditor(
          label: 'Add a colour',
          values: form.colours,
          onAdd: form.addColour,
          onRemove: form.removeColour,
        ),
        const SizedBox(height: 16),
        _OptionEditor(
          label: 'Add a size',
          values: form.sizes,
          onAdd: form.addSize,
          onRemove: form.removeSize,
        ),
        for (final row in form.rows) ...[
          const SizedBox(height: 12),
          _VariantRowEditor(key: ValueKey(row.label), form: form, row: row),
        ],
      ],
    );
  }
}

class _OptionEditor extends StatefulWidget {
  const _OptionEditor({
    required this.label,
    required this.values,
    required this.onAdd,
    required this.onRemove,
  });

  final String label;
  final List<String> values;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<_OptionEditor> createState() => _OptionEditorState();
}

class _OptionEditorState extends State<_OptionEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    widget.onAdd(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          maxLength: 30,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(
            labelText: widget.label,
            counterText: '',
            suffixIcon: IconButton(
              tooltip: widget.label,
              icon: const Icon(Icons.add_rounded),
              onPressed: _add,
            ),
          ),
        ),
        if (widget.values.isNotEmpty) const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final value in widget.values)
              InputChip(
                label: Text(value),
                onDeleted: () => widget.onRemove(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _VariantRowEditor extends StatelessWidget {
  const _VariantRowEditor({required this.form, required this.row, super.key});

  final ProductFormProvider form;
  final VariantRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 2, child: Text(row.label)),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextFormField(
            initialValue: _moneyText(row.price),
            keyboardType: TextInputType.number,
            inputFormatters: _digits(9),
            decoration: const InputDecoration(labelText: 'Price'),
            onChanged: (value) => form.setRowPrice(row, double.tryParse(value)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextFormField(
            initialValue: row.stock?.toString() ?? '',
            keyboardType: TextInputType.number,
            inputFormatters: _digits(6),
            decoration: const InputDecoration(labelText: 'Stock'),
            onChanged: (value) => form.setRowStock(row, int.tryParse(value)),
          ),
        ),
      ],
    );
  }
}

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({required this.form});

  final ProductFormProvider form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prices = form.hasOptions
        ? form.rows.map((row) => row.price ?? 0)
        : [form.price ?? 0];
    final lowest = prices.reduce((a, b) => a < b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final photo in form.photos) _PhotoTile(photo: photo)],
        ),
        const SizedBox(height: 12),
        Text(form.title.trim(), style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          form.hasOptions ? 'From ${formatTaka(lowest)}' : formatTaka(lowest),
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          [
            form.categoryLabel,
            form.isNew ? 'New' : 'Used',
          ].whereType<String>().join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        if (form.hasOptions) ...[
          const SizedBox(height: 8),
          for (final row in form.rows)
            Text(
              '${row.label}: ${formatTaka(row.price ?? 0)}, '
              '${row.stock ?? 0} in stock',
            ),
        ],
        const SizedBox(height: 12),
        Text(form.description.trim()),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Your price is final, including for Cash on Delivery. Browsly '
              'charges 1% commission on the listing price when an order is '
              'complete. Listings are reviewed before they go live, and may '
              'also be checked by an admin.',
            ),
          ),
        ),
      ],
    );
  }
}
