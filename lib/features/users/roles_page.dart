// lib/features/users/roles_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';

/// List all roles for the current tenant
final rolesListProvider =
FutureProvider.autoDispose<List<Role>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final auth = ref.watch(authControllerProvider);
  final tenantId = auth.me?.tenantId ?? '';
  if (tenantId.isEmpty) return <Role>[];
  return api.listRoles(tenantId: tenantId);
});

class RolesPage extends ConsumerWidget {
  const RolesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoles = ref.watch(rolesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roles & Permissions'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await showDialog<bool>(
            context: context,
            builder: (_) => const _CreateRoleDialog(),
          );
          if (created == true) {
            ref.invalidate(rolesListProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: asyncRoles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'Failed to load roles: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (roles) {
          if (roles.isEmpty) {
            return const Center(
              child: Text(
                'No roles yet.\nTap + to add one.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.separated(
            itemCount: roles.length,
            separatorBuilder: (_, __) =>
            const Divider(height: 1, thickness: 0.5),
            itemBuilder: (context, i) {
              final r = roles[i];
              return ListTile(
                leading: const Icon(Icons.badge),
                title: Text(
                  r.code,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Tenant ${r.tenantId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(.6),
                  ),
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
                    '/roles/${r.id}',
                    extra: r,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Dialog to create a role code for this tenant
class _CreateRoleDialog extends ConsumerStatefulWidget {
  const _CreateRoleDialog();

  @override
  ConsumerState<_CreateRoleDialog> createState() => _CreateRoleDialogState();
}

class _CreateRoleDialogState extends ConsumerState<_CreateRoleDialog> {
  final _codeCtl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _codeCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tenantId = ref.read(authControllerProvider).me?.tenantId ?? '';
    if (tenantId.isEmpty) {
      Navigator.pop(context, false);
      return;
    }

    final code = _codeCtl.text.trim();
    if (code.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).createRole(
        tenantId: tenantId,
        code: code,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create role: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Role'),
      content: TextField(
        controller: _codeCtl,
        decoration: const InputDecoration(
          labelText: 'Role code *',
          helperText: 'Example: CASHIER, WAITER, MANAGER',
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// Detail page for a single role: grant or revoke permissions
class RoleDetailPage extends ConsumerStatefulWidget {
  const RoleDetailPage({
    super.key,
    required this.roleId,
    this.initialRole,
  });

  final String roleId;
  final Role? initialRole;

  @override
  ConsumerState<RoleDetailPage> createState() => _RoleDetailPageState();
}

class _RoleDetailPageState extends ConsumerState<RoleDetailPage> {
  final _grantCtl = TextEditingController();
  final _revokeCtl = TextEditingController();
  bool _busyGrant = false;
  bool _busyRevoke = false;

  @override
  void dispose() {
    _grantCtl.dispose();
    _revokeCtl.dispose();
    super.dispose();
  }

  Future<void> _grant() async {
    final code = _grantCtl.text.trim();
    if (code.isEmpty) return;
    setState(() => _busyGrant = true);
    try {
      await ref
          .read(apiClientProvider)
          .grantRolePermissions(widget.roleId, [code]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Granted $code')),
        );
        _grantCtl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Grant failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyGrant = false);
    }
  }

  Future<void> _revoke() async {
    final code = _revokeCtl.text.trim();
    if (code.isEmpty) return;
    setState(() => _busyRevoke = true);
    try {
      await ref
          .read(apiClientProvider)
          .revokeRolePermission(widget.roleId, code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revoked $code')),
        );
        _revokeCtl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revoke failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyRevoke = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.initialRole;

    return Scaffold(
      appBar: AppBar(
        title: Text(role == null ? 'Role' : role.code),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (role != null) ...[
              const Text(
                'Role Code',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                role.code,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
            ],

            const Text(
              'Grant Permission',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _grantCtl,
              decoration: const InputDecoration(
                labelText: 'Permission code',
                helperText: 'e.g. SETTINGS_EDIT, REPRINT, CLOSE_SHIFT',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busyGrant ? null : _grant,
              icon: _busyGrant
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.add),
              label: const Text('Grant'),
            ),
            const Divider(height: 32),

            const Text(
              'Revoke Permission',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _revokeCtl,
              decoration: const InputDecoration(
                labelText: 'Permission code',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busyRevoke ? null : _revoke,
              icon: _busyRevoke
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.remove_circle_outline),
              label: const Text('Revoke'),
            ),
            const SizedBox(height: 24),

            Text(
              'Note: backend does not (yet) return the list of permissions '
                  'per role in one call, so we manage them here by code.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
