// lib/features/users/user_new_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';

/// All roles for current tenant, for checkboxes in "New User" form.
final _availableRolesProvider =
FutureProvider.autoDispose<List<Role>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final auth = ref.watch(authControllerProvider);
  final tenantId = auth.me?.tenantId ?? '';
  if (tenantId.isEmpty) return <Role>[];
  return api.listRoles(tenantId: tenantId);
});

class UserCreatePage extends ConsumerStatefulWidget {
  const UserCreatePage({super.key});

  @override
  ConsumerState<UserCreatePage> createState() => _UserCreatePageState();
}

class _UserCreatePageState extends ConsumerState<UserCreatePage> {
  final _nameCtl = TextEditingController();
  final _mobileCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _pinCtl = TextEditingController();

  final Set<String> _selectedRoleCodes = {};
  bool _saving = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _mobileCtl.dispose();
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _pinCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tenantId = ref.read(authControllerProvider).me?.tenantId ?? '';
    if (tenantId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing tenantId')),
        );
      }
      return;
    }

    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name is required')),
        );
      }
      return;
    }

    setState(() => _saving = true);

    try {
      final api = ref.read(apiClientProvider);

      await api.createUser(
        tenantId: tenantId,
        name: name,
        mobile: _mobileCtl.text.trim().isEmpty
            ? null
            : _mobileCtl.text.trim(),
        email: _emailCtl.text.trim().isNotEmpty
            ? _emailCtl.text.trim()
            : null,
        password: _passwordCtl.text.trim().isNotEmpty
            ? _passwordCtl.text.trim()
            : null,
        pin: _pinCtl.text.trim().isNotEmpty
            ? _pinCtl.text.trim()
            : null,
        roles: _selectedRoleCodes.toList(),
      );

      if (!mounted) return;
      Navigator.pop(context, true); // tell caller success
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create user: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(_availableRolesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New User'),
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
            const Text(
              'Basic Info',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtl,
              decoration: const InputDecoration(
                labelText: 'Name *',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mobileCtl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Credentials',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordCtl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (optional)',
                helperText: 'Defaults to "admin" if blank',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinCtl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: false),
              decoration: const InputDecoration(
                labelText: 'PIN (optional)',
                helperText: '4-digit cashier PIN etc.',
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Assign Roles',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            rolesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
              error: (e, st) => Text(
                'Failed to load roles: $e',
                style: const TextStyle(color: Colors.red),
              ),
              data: (roles) {
                if (roles.isEmpty) {
                  return Text(
                    'No roles yet. You can create roles in Roles & Permissions.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  );
                }
                return Column(
                  children: roles.map((r) {
                    final checked = _selectedRoleCodes.contains(r.code);
                    return CheckboxListTile(
                      value: checked,
                      title: Text(r.code),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedRoleCodes.add(r.code);
                          } else {
                            _selectedRoleCodes.remove(r.code);
                          }
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 32),
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
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
