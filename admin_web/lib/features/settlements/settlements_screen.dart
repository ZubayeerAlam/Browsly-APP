import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/state/paged_provider.dart';
import '../../core/widgets/admin_page.dart';
import 'settlements_data.dart';

typedef _OwingProvider = PagedProvider<SellerOwing, Never>;
typedef _HistoryProvider = PagedProvider<Settlement, Never>;

class SettlementsScreen extends StatelessWidget {
  const SettlementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SettlementsRepository>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => _OwingProvider(
            (search, filter, next) => repository.getSellersOwing(
              search: search,
              offset: int.tryParse(next?.key ?? '') ?? 0,
            ),
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (context) => _HistoryProvider(
            (search, filter, next) => repository.getSettlements(cursor: next),
          )..load(),
        ),
      ],
      child: DefaultTabController(
        length: 2,
        child: Builder(
          builder: (context) => AdminPage(
            title: 'Settlements',
            actions: [
              SearchBox(
                hint: 'Shop or phone',
                onChanged: context.read<_OwingProvider>().setSearch,
              ),
            ],
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabBar(
                  tabs: [
                    Tab(text: 'Sellers owing'),
                    Tab(text: 'Payments recorded'),
                  ],
                ),
                SizedBox(height: 12),
                Expanded(
                  child: TabBarView(children: [_OwingTab(), _HistoryTab()]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OwingTab extends StatelessWidget {
  const _OwingTab();

  Future<void> _record(BuildContext context, SellerOwing seller) async {
    final owing = context.read<_OwingProvider>();
    final history = context.read<_HistoryProvider>();
    final repository = context.read<SettlementsRepository>();
    final input = await showDialog<SettlementInput>(
      context: context,
      builder: (context) => _RecordDialog(seller: seller),
    );
    if (input == null) return;
    final saved = await owing.act(
      () => repository.record(seller.sellerId, input),
    );
    if (saved) await history.load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<_OwingProvider>();
    return PagedBody(
      provider: provider,
      emptyIcon: Icons.task_alt_rounded,
      emptyTitle: 'Nobody owes any commission',
      builder: (context, items) => AdminTable(
        columns: const [
          'Shop',
          'Phone',
          'bKash or payout number',
          'Charged',
          'Paid',
          'Owes',
          '',
        ],
        rows: [
          for (final seller in items)
            DataRow(
              cells: [
                DataCell(Text(seller.shopName)),
                DataCell(Text(seller.phone ?? '–')),
                DataCell(Text(seller.payoutNumber ?? '–')),
                DataCell(Text(formatTaka(seller.totalCharged))),
                DataCell(Text(formatTaka(seller.totalPaid))),
                DataCell(Text(formatTaka(seller.balance))),
                DataCell(
                  FilledButton(
                    onPressed: () => _record(context, seller),
                    child: const Text('Record payment'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<_HistoryProvider>();
    return PagedBody(
      provider: provider,
      emptyTitle: 'No payments recorded yet',
      builder: (context, items) => AdminTable(
        columns: const [
          'Date',
          'Shop',
          'Amount',
          'Method',
          'Reference',
          'Note',
          'Recorded by',
        ],
        rows: [
          for (final payment in items)
            DataRow(
              cells: [
                DataCell(Text(formatDateTime(payment.createdAt))),
                DataCell(Text(payment.shopName)),
                DataCell(Text(formatTaka(payment.amount))),
                DataCell(Text(payment.method == 'bkash' ? 'bKash' : 'Bank')),
                DataCell(Text(payment.reference)),
                DataCell(Text(payment.note ?? '–')),
                DataCell(Text(payment.recordedBy)),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecordDialog extends StatefulWidget {
  const _RecordDialog({required this.seller});

  final SellerOwing seller;

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  late final TextEditingController _amount;
  final _reference = TextEditingController();
  final _note = TextEditingController();
  String _method = 'bkash';

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: '${widget.seller.balance}');
    _amount.addListener(() => setState(() {}));
    _reference.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _parsedAmount {
    final amount = double.tryParse(_amount.text.trim());
    return amount == null || amount <= 0 || amount > widget.seller.balance
        ? null
        : amount;
  }

  @override
  Widget build(BuildContext context) {
    final amount = _parsedAmount;
    final canSave = amount != null && _reference.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text('Record payment from ${widget.seller.shopName}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('They owe ${formatTaka(widget.seller.balance)}.'),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount received (৳)',
                  errorText: _amount.text.isNotEmpty && amount == null
                      ? 'Up to ${formatTaka(widget.seller.balance)}'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Paid by'),
                items: const [
                  DropdownMenuItem(value: 'bkash', child: Text('bKash')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank')),
                ],
                onChanged: (value) =>
                    setState(() => _method = value ?? _method),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reference,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Transaction ID or reference',
                ),
              ),
              TextField(
                controller: _note,
                maxLength: 300,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
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
          onPressed: canSave
              ? () => Navigator.of(context).pop(
                  SettlementInput(
                    amount: amount,
                    method: _method,
                    reference: _reference.text.trim(),
                    note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                  ),
                )
              : null,
          child: const Text('Record payment'),
        ),
      ],
    );
  }
}
