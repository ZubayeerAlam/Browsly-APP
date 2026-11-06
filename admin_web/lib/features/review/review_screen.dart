import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../core/formatters.dart';
import '../../core/state/paged_provider.dart';
import '../../core/widgets/admin_page.dart';
import 'review_data.dart';

typedef _Provider = PagedProvider<QueuedProduct, Never>;

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final repository = context.read<ReviewRepository>();
        return _Provider(
          (search, filter, next) => repository.getQueue(cursor: next),
        )..load();
      },
      child: Builder(
        builder: (context) {
          final provider = context.watch<_Provider>();
          return AdminPage(
            title: 'Product Review',
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: provider.load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
            child: PagedBody(
              provider: provider,
              emptyIcon: Icons.task_alt_rounded,
              emptyTitle: 'Nothing is waiting for review',
              builder: (context, items) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final product in items) _QueueCard(product: product),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.product});

  final QueuedProduct product;

  Future<void> _approve(BuildContext context) async {
    final provider = context.read<_Provider>();
    final repository = context.read<ReviewRepository>();
    final answer = await askToConfirm(
      context,
      title: 'Approve this listing?',
      message: 'It goes live straight away, and the seller is told.',
      confirmLabel: 'Approve',
    );
    if (answer != null) {
      await provider.act(() => repository.approve(product.id));
    }
  }

  Future<void> _reject(BuildContext context) async {
    final provider = context.read<_Provider>();
    final repository = context.read<ReviewRepository>();
    final reason = await askToConfirm(
      context,
      title: 'Reject this listing?',
      message: 'The seller sees your reason and can edit and resubmit.',
      reasonLabel: 'Reason for the seller',
      reasonRequired: true,
      confirmLabel: 'Reject',
      isDanger: true,
    );
    if (reason != null) {
      await provider.act(() => repository.reject(product.id, reason));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = product.price;
    final decision = product.aiDecision;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusPill(
                    label: switch (decision) {
                      'reject' => 'AI: Reject',
                      'suspicious' => 'AI: Suspicious',
                      'approve' => 'AI: Approve',
                      _ => 'AI unavailable',
                    },
                    isBad: decision == 'reject',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  product.shopName,
                  product.categoryName,
                  if (price != null) formatTaka(price),
                  product.isNew ? 'New' : 'Used',
                  '${product.totalStock} in stock',
                  'Waiting since ${formatDateTime(product.waitingSince)}',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  decision == null
                      ? 'The AI could not give an answer in time, so this needs '
                            'a person to decide.'
                      : [
                          ?product.reasonCode,
                          product.aiReason ?? 'No reason was given.',
                        ].join(': '),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: product.imageUrls.isEmpty
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No photos'),
                      )
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final url in product.imageUrls)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: PhotoThumb(url: url, size: 120),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              Text(product.description),
              if (product.variantNames.length > 1) ...[
                const SizedBox(height: 8),
                Text(
                  'Options: ${product.variantNames.join(', ')}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      minimumSize: const Size(120, 44),
                    ),
                    onPressed: () => _reject(context),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 44),
                    ),
                    onPressed: () => _approve(context),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
