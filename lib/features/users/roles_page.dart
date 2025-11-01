import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:waah_frontend/app/providers.dart';
// no direct import of api_client.dart needed here
import 'package:waah_frontend/data/models.dart';

/// Load all roles for my tenant.
final rolesListProvider =
FutureProvider.autoDispose<List<RoleInfo>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final auth = ref.watch(authControllerProvider);
  final tenantId = auth.me?.tenantId ?? '';

  if (tenantId.isEmpty) {
    return <RoleInfo>[];
  }

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
            builder: (_) => const _NewRoleDialog(),
          );

          if (created == true && context.mounted) {
            ref.invalidate(rolesListProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: asyncRoles.when(
        loading: () =>
        const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'Failed to load roles: $err',
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        data: (roles) {
          if (roles.isEmpty) {
            return const Center(
              child: Text(
                'No roles yet.\nTap + to create one.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 16,
            ),
            itemCount: roles.length,
            separatorBuilder: (_, __) =>
            const Divider(height: 1, thickness: 0.5),
            itemBuilder: (context, i) {
              final r = roles[i];
              return ListTile(
                leading: const Icon(Icons.badge),
                title: Text(
                  r.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  r.permissions.isEmpty
                      ? 'No permissions'
                      : r.permissions.take(3).join(', ') +
                      (r.permissions.length > 3 ? '…' : ''),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(.7),
                  ),
                ),
                onTap: () {
                  context.push(
                    '/roles/${r.id}',
                    extra: r, // passes RoleInfo to RoleDetailPage
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

/// Dialog to create a new role code in this tenant.
class _NewRoleDialog extends ConsumerStatefulWidget {
  const _NewRoleDialog();

  @override
  ConsumerState<_NewRoleDialog> createState() => _NewRoleDialogState();
}

class _NewRoleDialogState extends ConsumerState<_NewRoleDialog> {
  final _codeCtl = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _codeCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final code = _codeCtl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _err = 'Enter a role code, e.g. CASHIER');
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final me = ref.read(authControllerProvider).me;
      final tenantId = me?.tenantId ?? '';

      if (tenantId.isEmpty) {
        throw Exception('No tenant');
      }

      await api.createRole(
        tenantId: tenantId,
        code: code,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Role'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _codeCtl,
            decoration: const InputDecoration(
              labelText: 'Role Code',
              helperText: 'Example: CASHIER, MANAGER, WAITER',
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
            child:
            CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Create'),
        ),
      ],
    );
  }
}
