import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';

class BranchSelectPage extends ConsumerWidget {
  const BranchSelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBranches = ref.watch(branchesProvider);
    final currentBranchId = ref.watch(activeBranchIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Branch'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Branch'),
        onPressed: () async {
          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => const _BranchCreateSheet(),
          );
          // If a branch was created we already updated providers in sheet,
          // so just rebuild list.
          if (created == true && context.mounted) {
            ref.invalidate(branchesProvider);
          }
        },
      ),
      body: asyncBranches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'Failed to load branches: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (branches) {
          if (branches.isEmpty) {
            return const Center(
              child: Text('No branches yet. Add one.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) {
              final b = branches[i];
              final isActive = b.id == currentBranchId;
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                  ),
                ),
                title: Text(
                  b.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((b.address ?? '').isNotEmpty)
                      Text(
                        b.address!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    if ((b.phone ?? '').isNotEmpty)
                      Text(
                        '📞 ${b.phone!}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    if ((b.gstin ?? '').isNotEmpty)
                      Text(
                        'GSTIN: ${b.gstin!}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                trailing: isActive
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  // Switch active branch (fires all side-effects wired in the notifier)
                ref.read(activeBranchIdProvider.notifier).set(b.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Branch switched')),
                );

                // Close the picker; caller decides where to land next
                context.pop();
              },
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: branches.length,
          );
        },
      ),
    );
  }
}

class _BranchCreateSheet extends ConsumerStatefulWidget {
  const _BranchCreateSheet();

  @override
  ConsumerState<_BranchCreateSheet> createState() =>
      _BranchCreateSheetState();
}

class _BranchCreateSheetState
    extends ConsumerState<_BranchCreateSheet> {
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _gstinCtl = TextEditingController();
  final _stateCtl = TextEditingController();
  final _addrCtl = TextEditingController();

  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _gstinCtl.dispose();
    _stateCtl.dispose();
    _addrCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tenantId =
        ref.read(authControllerProvider).me?.tenantId ?? '';

    final name = _nameCtl.text.trim();
    if (tenantId.isEmpty) {
      setState(() {
        _err = 'Missing tenant';
      });
      return;
    }
    if (name.isEmpty) {
      setState(() {
        _err = 'Branch name is required';
      });
      return;
    }

    setState(() {
      _saving = true;
      _err = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final newId = await api.createBranch(
        tenantId: tenantId,
        name: name,
        phone: _phoneCtl.text.trim(),
        gstin: _gstinCtl.text.trim(),
        stateCode: _stateCtl.text.trim(),
        address: _addrCtl.text.trim(),
      );

      // make the newly created branch active right away
      ref.read(activeBranchIdProvider.notifier).set(newId);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomInset + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Branch',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _nameCtl,
            decoration: const InputDecoration(
              labelText: 'Branch Name *',
              helperText: 'Eg. Main Outlet / Andheri / Koramangala',
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _phoneCtl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _gstinCtl,
            decoration: const InputDecoration(
              labelText: 'GSTIN',
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _stateCtl,
            decoration: const InputDecoration(
              labelText: 'State code',
              helperText: 'Eg. MH, KA, TN...',
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _addrCtl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Address',
            ),
          ),
          const SizedBox(height: 16),

          if (_err != null) ...[
            Text(
              _err!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.pop(context, false),
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
