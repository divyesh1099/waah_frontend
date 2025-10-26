import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';

/// Fetch a specific role (including permissions list)
final roleDetailProvider =
FutureProvider.autoDispose
    .family<RoleInfo, String>((ref, roleId) async {
  final api = ref.watch(apiClientProvider);
  return api.fetchRole(roleId); // ApiClient.fetchRole -> RoleInfo
});

/// Fetch all possible permissions
final allPermissionsProvider =
FutureProvider.autoDispose<List<PermissionInfo>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.listPermissions(); // ApiClient.listPermissions -> List<PermissionInfo>
});

class RoleDetailPage extends ConsumerWidget {
  final String roleId;
  final RoleInfo? initialRole;

  const RoleDetailPage({
    super.key,
    required this.roleId,
    this.initialRole,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Optimistic initial data: if we navigated with extra:role
    final asyncRole = ref.watch(roleDetailProvider(roleId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Role: ${initialRole?.code ?? roleId}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await showDialog<bool>(
            context: context,
            builder: (_) => _AddPermDialog(roleId: roleId),
          );
          if (added == true && context.mounted) {
            ref.invalidate(roleDetailProvider(roleId));
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: asyncRole.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Text(
            'Failed to load role: $e',
            style: const TextStyle(color: Colors.red),
          ),
          data: (role) {
            final perms = role.permissions;

            return ListView(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.code,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${role.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Permissions',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (perms.isEmpty)
                          Text(
                            'No permissions yet.\nTap + to grant.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          )
                        else
                          Column(
                            children: perms.map((p) {
                              return _PermTile(
                                roleId: role.id,
                                permCode: p,
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One permission row with a trash icon to revoke.
class _PermTile extends ConsumerStatefulWidget {
  final String roleId;
  final String permCode;
  const _PermTile({
    required this.roleId,
    required this.permCode,
  });

  @override
  ConsumerState<_PermTile> createState() => _PermTileState();
}

class _PermTileState extends ConsumerState<_PermTile> {
  bool _busy = false;

  Future<void> _revoke() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .revokeRolePermission(widget.roleId, widget.permCode);
      // after successful revoke, refresh parent role detail provider
      ref.invalidate(roleDetailProvider(widget.roleId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.lock),
      title: Text(
        widget.permCode,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: IconButton(
        icon: _busy
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.delete_forever),
        onPressed: _busy ? null : _revoke,
      ),
    );
  }
}

/// Dialog to GRANT new permissions to this role.
class _AddPermDialog extends ConsumerStatefulWidget {
  final String roleId;
  const _AddPermDialog({required this.roleId});

  @override
  ConsumerState<_AddPermDialog> createState() => _AddPermDialogState();
}

class _AddPermDialogState extends ConsumerState<_AddPermDialog> {
  String? _selectedPerm;
  bool _busy = false;
  String? _err;

  Future<void> _save() async {
    final perm = _selectedPerm;
    if (perm == null || perm.isEmpty) {
      setState(() {
        _err = 'Pick a permission first';
      });
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      await ref
          .read(apiClientProvider)
          .grantRolePermissions(widget.roleId, [perm]);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // We need both the full list of permissions in system,
    // and the current role's permissions so we can filter out duplicates.
    final asyncAllPerms = ref.watch(allPermissionsProvider);
    final asyncRole = ref.watch(roleDetailProvider(widget.roleId));

    return AlertDialog(
      title: const Text('Grant Permission'),
      content: asyncAllPerms.when(
        loading: () => const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, st) => Text(
          'Failed to load permissions: $e',
          style: const TextStyle(color: Colors.red),
        ),
        data: (allPermInfos) {
          final allPermCodes =
          allPermInfos.map((p) => p.code).toList();

          return asyncRole.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Text(
              'Failed to load role: $e',
              style: const TextStyle(color: Colors.red),
            ),
            data: (roleInfo) {
              final already = roleInfo.permissions.toSet();
              final available = allPermCodes
                  .where((code) => !already.contains(code))
                  .toList();

              if (available.isEmpty) {
                return const Text(
                  'All permissions already granted.',
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedPerm,
                    items: available
                        .map(
                          (code) => DropdownMenuItem<String>(
                        value: code,
                        child: Text(code),
                      ),
                    )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedPerm = val;
                        _err = null;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Permission',
                      helperText: 'Example: SETTINGS_EDIT',
                    ),
                  ),
                  if (_err != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _err!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Grant'),
        ),
      ],
    );
  }
}
