import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/repo/catalog_repo.dart';

class DangerSettingsPage extends ConsumerStatefulWidget {
  const DangerSettingsPage({super.key});

  @override
  ConsumerState<DangerSettingsPage> createState() => _DangerSettingsPageState();
}

class _DangerSettingsPageState extends ConsumerState<DangerSettingsPage> {
  final _pwdCtl = TextEditingController();
  final _pinCtl = TextEditingController();
  bool _obscure = true;
  bool _obscurePin = true;
  bool _busyDelete = false;
  bool _busyDebug = false;
  bool _debugDesired = false;

  @override
  void initState() {
    super.initState();
    _debugDesired = ref.read(menuDebugEnabledProvider);
  }

  @override
  void dispose() {
    _pwdCtl.dispose();
    _pinCtl.dispose();
    super.dispose();
  }

  String get _password => _pwdCtl.text.trim();
  String get _pin => _pinCtl.text.trim();

  Future<bool> _verifyCredentials() async {
    if (_password.isEmpty && _pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter password or PIN to continue')),
      );
      return false;
    }
    try {
      await ref.read(apiClientProvider).verifyPassword(password: _password, pin: _pin);
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credential check failed: $e')),
      );
      return false;
    }
  }

  Future<void> _deleteWholeMenu() async {
    if (_busyDelete) return;
    final tenantId = ref.read(activeTenantIdProvider);
    final branchId = ref.read(activeBranchIdProvider);
    if (tenantId.isEmpty || branchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a branch first')),
      );
      return;
    }

    if (!await _verifyCredentials()) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete ALL menu data?'),
        content: const Text(
          'This will delete every category, item, and variant for this branch. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busyDelete = true);
    try {
      final resp = await ref.read(apiClientProvider).clearMenuDanger(
            tenantId: tenantId,
            branchId: branchId,
            password: _password.isEmpty ? null : _password,
            pin: _pin.isEmpty ? null : _pin,
          );
      // Clear local cache too.
      await ref.read(localDatabaseProvider).clearMenu();
      // Pull fresh (empty) state
      await ref.read(catalogRepoProvider).syncDownMenu(tenantId, branchId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deleted menu: ${resp['deleted_categories']} cats, ${resp['deleted_items']} items, ${resp['deleted_variants']} variants.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyDelete = false);
    }
  }

  Future<void> _applyDebugSetting() async {
    if (_busyDebug) return;
    if (!await _verifyCredentials()) return;

    setState(() => _busyDebug = true);
    try {
      ref.read(menuDebugEnabledProvider.notifier).setEnabled(_debugDesired);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_debugDesired ? 'Menu debug enabled' : 'Menu debug disabled')),
      );
    } finally {
      if (mounted) setState(() => _busyDebug = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchId = ref.watch(activeBranchIdProvider);
    final canRun = branchId.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danger zone'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Credentials', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  const Text('Enter password or PIN before running destructive actions.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pwdCtl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinCtl,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                    labelText: 'PIN (optional)',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePin = !_obscurePin),
                    ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delete menu (danger)', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red.shade700)),
                  const SizedBox(height: 8),
                  const Text(
                    'Deletes ALL categories, items, and variants for the current branch after verifying your credentials.',
                    style: TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      disabledBackgroundColor: Colors.red.shade200,
                    ),
                    onPressed: (!canRun || _busyDelete) ? null : _deleteWholeMenu,
                    icon: _busyDelete
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.delete_forever),
                    label: const Text('Delete ALL menu data for this branch'),
                  ),
                  if (!canRun)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Select a branch first.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Developer debug', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Show/hide the menu debug banner. Requires password each time.',
                  ),
                  SwitchListTile(
                    value: _debugDesired,
                    onChanged: (v) => setState(() => _debugDesired = v),
                    title: const Text('Enable menu debug UI'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busyDebug ? null : _applyDebugSetting,
                    child: _busyDebug
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Apply'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
