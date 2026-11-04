import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/widgets/failure_banner.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/address.dart';
import '../providers/addresses_provider.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  Future<void> _openForm(BuildContext context, {Address? address}) async {
    final provider = context.read<AddressesProvider>();
    final saved = await context.push<bool>(
      AppRoutes.addressForm,
      extra: address,
    );
    if (saved == true) await provider.load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AddressesProvider>();
    final state = provider.state;
    final addresses = state.data;
    return Scaffold(
      appBar: AppBar(title: const Text('Addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add address'),
      ),
      body: switch (state.status) {
        ViewStatus.empty => const EmptyView(
          icon: Icons.location_on_outlined,
          title: 'No addresses yet',
          message: 'Add a delivery address for your orders.',
        ),
        ViewStatus.error when addresses == null => ErrorView(
          message: state.failure!.message,
          onRetry: provider.load,
        ),
        _ when addresses == null => const LoadingView(),
        _ => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            FailureBanner(failure: provider.actionFailure ?? state.failure),
            for (final address in addresses)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AddressCard(
                  address: address,
                  onEdit: () => _openForm(context, address: address),
                ),
              ),
          ],
        ),
      },
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.onEdit});

  final Address address;
  final VoidCallback onEdit;

  Future<void> _confirmDelete(BuildContext context) async {
    final provider = context.read<AddressesProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.delete(address.id);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final provider = context.read<AddressesProvider>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    address.recipientName,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (address.isDefault)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Default',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(address.phone),
            const SizedBox(height: 2),
            Text(
              address.fullAddress,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!address.isDefault)
                  TextButton(
                    onPressed: () => provider.setDefault(address.id),
                    child: const Text('Make default'),
                  ),
                TextButton(onPressed: onEdit, child: const Text('Edit')),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  onPressed: () => _confirmDelete(context),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
