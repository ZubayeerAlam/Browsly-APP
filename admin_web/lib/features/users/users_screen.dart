import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/state/paged_provider.dart';
import '../../core/widgets/admin_page.dart';
import 'users_data.dart';

typedef _Provider = PagedProvider<AdminUser, Never>;

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  Future<void> _toggle(BuildContext context, AdminUser user) async {
    final provider = context.read<_Provider>();
    final repository = context.read<UsersRepository>();
    if (user.isSuspended) {
      final answer = await askToConfirm(
        context,
        title: 'Lift this suspension?',
        message: user.shopName == null
            ? null
            : 'Their shop and its live products come back.',
        confirmLabel: 'Lift suspension',
      );
      if (answer != null) {
        await provider.act(() => repository.setSuspended(user.id, false));
      }
      return;
    }
    final reason = await askToConfirm(
      context,
      title: 'Suspend this user?',
      message: user.shopName == null
          ? 'They will not be able to buy or chat.'
          : 'They will not be able to buy, chat or post. Their shop and all '
                'of its products disappear from the marketplace.',
      reasonLabel: 'Reason (kept in the admin record)',
      reasonRequired: true,
      confirmLabel: 'Suspend',
      isDanger: true,
    );
    if (reason != null) {
      await provider.act(
        () => repository.setSuspended(user.id, true, reason: reason),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final repository = context.read<UsersRepository>();
        return _Provider(
          (search, filter, next) =>
              repository.getUsers(search: search, cursor: next),
        )..load();
      },
      child: Builder(
        builder: (context) {
          final provider = context.watch<_Provider>();
          return AdminPage(
            title: 'Users',
            actions: [
              SearchBox(
                hint: 'Name, email, phone or shop',
                onChanged: context.read<_Provider>().setSearch,
              ),
            ],
            child: PagedBody(
              provider: provider,
              emptyTitle: 'No users found',
              builder: (context, items) => AdminTable(
                columns: const [
                  'Name',
                  'Contact',
                  'Shop',
                  'Owes',
                  'Joined',
                  'Status',
                  '',
                ],
                rows: [
                  for (final user in items)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(user.name.isEmpty ? 'No name' : user.name),
                        ),
                        DataCell(Text([?user.email, ?user.phone].join('\n'))),
                        DataCell(Text(user.shopName ?? '–')),
                        DataCell(Text(formatTaka(user.commissionOwed))),
                        DataCell(Text(formatDate(user.joinedAt))),
                        DataCell(
                          StatusPill(
                            label: user.isAdmin
                                ? 'Admin'
                                : user.isSuspended
                                ? 'Suspended'
                                : 'Active',
                            isBad: user.isSuspended,
                          ),
                        ),
                        DataCell(
                          user.isAdmin
                              ? const SizedBox.shrink()
                              : TextButton(
                                  onPressed: () => _toggle(context, user),
                                  child: Text(
                                    user.isSuspended
                                        ? 'Lift suspension'
                                        : 'Suspend',
                                  ),
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
