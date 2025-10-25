// lib/features/users/user_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';

/// pull single user's latest data by searching listUsers
final _userDetailProvider =
FutureProvider.family.autoDispose<UserSummary?, String>((ref, userId) async {
  final api = ref.watch(apiClientProvider);
  final auth = ref.watch(authControllerProvider);
  final tenantId = auth.me?.tenantId ?? '';
  if (tenantId.isEmpty) return null;

  final all = await api.listUsers(tenantId: tenantId);
  try {
    return all.firstWhere((u) => u.id == userId);
  } catch (_) {
    return null;
  }
});

/// roles in this tenant (used in "Add Role" bottom sheet)
final _tenantRolesProvider =
FutureProvider.autoDispose<List<Role>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final auth = ref.watch(authControllerProvider);
  final tenantId = auth.me?.tenantId ?? '';
  if (tenantId.isEmpty) return <Role>[];
  return api.listRoles(tenantId: tenantId);
});

class UserDetailPage extends ConsumerWidget {
  const UserDetailPage({
    super.key,
    required this.userId,
    this.initialUser,
  });

  final String userId;
  final UserSummary? initialUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUser = ref.watch(_userDetailProvider(userId));

    // optimistic paint using initialUser if we navigated from list
    final optimistic = initialUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
      ),
      body: asyncUser.when(
        loading: () => optimistic == null
            ? const Center(child: CircularProgressIndicator())
            : _UserDetailBody(
          user: optimistic,
          userId: userId,
        ),
        error: (e, st) => Center(
          child: Text(
            'Failed to load user: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (u) {
          if (u == null) {
            return const Center(
              child: Text('User not found'),
            );
          }
          return _UserDetailBody(
            user: u,
            userId: userId,
          );
        },
      ),
    );
  }
}

class _UserDetailBody extends ConsumerWidget {
  const _UserDetailBody({
    required this.user,
    required this.userId,
  });

  final UserSummary user;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = user.roles
        .map(
          (role) => Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 6),
        child: InputChip(
          label: Text(role),
          deleteIcon: const Icon(Icons.close),
          onDeleted: () async {
            try {
              await ref
                  .read(apiClientProvider)
                  .removeUserRole(userId, role);

              ref.invalidate(_userDetailProvider(userId));

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed role $role')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to remove: $e')),
                );
              }
            }
          },
        ),
      ),
    )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                user.active ? Colors.green : Colors.grey,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if ((user.mobile ?? '').isNotEmpty) ...[
            const Text(
              'Mobile',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(user.mobile!),
            const SizedBox(height: 12),
          ],

          if ((user.email ?? '').isNotEmpty) ...[
            const Text(
              'Email',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(user.email!),
            const SizedBox(height: 12),
          ],

          const Divider(height: 32),

          Row(
            children: [
              const Text(
                'Roles',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Role'),
                onPressed: () async {
                  final added = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _AddRoleSheet(
                      userId: userId,
                      already: user.roles,
                    ),
                  );
                  if (added == true) {
                    ref.invalidate(_userDetailProvider(userId));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (chips.isEmpty)
            Text(
              'No roles yet. Tap "Add Role".',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            Wrap(children: chips),
        ],
      ),
    );
  }
}

class _AddRoleSheet extends ConsumerStatefulWidget {
  const _AddRoleSheet({
    required this.userId,
    required this.already,
  });

  final String userId;
  final List<String> already;

  @override
  ConsumerState<_AddRoleSheet> createState() => _AddRoleSheetState();
}

class _AddRoleSheetState extends ConsumerState<_AddRoleSheet> {
  final Set<String> _selected = {};
  bool _saving = false;

  Future<void> _commit() async {
    if (_selected.isEmpty) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _saving = true);

    try {
      await ref
          .read(apiClientProvider)
          .assignUserRoles(widget.userId, _selected.toList());

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign roles: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(_tenantRolesProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: rolesAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => SizedBox(
            height: 120,
            child: Center(
              child: Text(
                'Failed to load roles: $e',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
          data: (roles) {
            final filtered = roles
                .where((r) => !widget.already.contains(r.code))
                .toList();

            if (filtered.isEmpty) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No more roles to add.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add Roles',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ...filtered.map((r) {
                  final checked = _selected.contains(r.code);
                  return CheckboxListTile(
                    value: checked,
                    title: Text(r.code),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selected.add(r.code);
                        } else {
                          _selected.remove(r.code);
                        }
                      });
                    },
                  );
                }),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _commit,
                        child: _saving
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
