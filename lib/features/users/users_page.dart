// lib/features/users/users_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';

/// all users in my tenant
final usersListProvider =
FutureProvider.autoDispose<List<UserSummary>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final authState = ref.watch(authControllerProvider);

  final me = authState.me;
  final tenantId = me?.tenantId ?? '';

  final branchId = ref.watch(activeBranchIdProvider);

  if (tenantId.isEmpty) return <UserSummary>[];

  try {
    return api.listUsers(tenantId: tenantId, branchId: branchId);
  } on ApiException catch (e) {
    throw ApiException(
      e.message.isNotEmpty ? e.message : 'Not allowed',
      e.status,
    );
  }
});

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUsers = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users & Roles'),
        actions: [
          IconButton(
            tooltip: 'Manage Roles / Permissions',
            icon: const Icon(Icons.security),
            onPressed: () {
              context.push('/roles');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await context.push<bool>('/users/new');
          if (created == true) {
            ref.invalidate(usersListProvider);
          }
        },
        child: const Icon(Icons.person_add),
      ),
      body: asyncUsers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          final msg =
          err is ApiException ? err.message : 'Failed to load users';
          return Center(
            child: Text(
              msg,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          );
        },
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: Text(
                'No users yet.\nTap + to add one.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: users.length,
            separatorBuilder: (_, __) =>
            const Divider(height: 1, thickness: 0.5),
            itemBuilder: (context, i) {
              final u = users[i];
              return _UserTile(u: u);
            },
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserSummary u;
  const _UserTile({required this.u});

  @override
  Widget build(BuildContext context) {
    final roleChips = u.roles
        .map(
          (role) => Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 4),
        child: Chip(
          label: Text(
            role,
            style: const TextStyle(fontSize: 12),
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    )
        .toList();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: u.active ? Colors.green : Colors.grey,
        child: const Icon(Icons.person, color: Colors.white),
      ),
      title: Text(
        u.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((u.mobile ?? '').isNotEmpty) Text(u.mobile!),
          if ((u.email ?? '').isNotEmpty)
            Text(
              u.email!,
              style: TextStyle(
                color:
                Theme.of(context).colorScheme.onSurface.withOpacity(.7),
                fontSize: 12,
              ),
            ),
          if (roleChips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(children: roleChips),
            ),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withOpacity(.5),
      ),
      onTap: () {
        context.push(
          '/users/${u.id}',
          extra: u, // pass summary for instant paint
        );
      },
    );
  }
}
