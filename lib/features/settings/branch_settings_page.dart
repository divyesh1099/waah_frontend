import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

class BranchSettingsPage extends ConsumerWidget {
  const BranchSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(settingsRepoProvider);
    final tenantId = ref.watch(activeTenantIdProvider);
    final branches$ = repo.watchBranches();

    return Scaffold(
      appBar: AppBar(title: const Text('Branches')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: tenantId.isEmpty ? null : () => _openEditor(context, ref, tenantId),
        icon: const Icon(Icons.add),
        label: const Text('New Branch'),
      ),
      body: StreamBuilder<List<BranchInfo>>(
        stream: branches$,
        initialData: const [],
        builder: (c, snap) {
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No branches yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final b = items[i];
              return ListTile(
                title: Text(b.name),
                subtitle: Text([b.phone, b.gstin, b.address].where((s) => (s ?? '').isNotEmpty).join(' • ')),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _openEditor(context, ref, b.tenantId, initial: b),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, b.id),
                    tooltip: 'Delete',
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, String tenantId, {BranchInfo? initial}) async {
    final nameCtl = TextEditingController(text: initial?.name ?? '');
    final phoneCtl = TextEditingController(text: initial?.phone ?? '');
    final gstCtl = TextEditingController(text: initial?.gstin ?? '');
    final addrCtl = TextEditingController(text: initial?.address ?? '');
    final stateCtl = TextEditingController(text: initial?.stateCode ?? '');

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        var closing = false;
        void safePop(bool value) {
          if (closing) return;
          closing = true;
          Navigator.of(dialogCtx).pop(value);
        }

        return AlertDialog(
          title: Text(initial == null ? 'New Branch' : 'Edit Branch'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtl,  decoration: const InputDecoration(labelText: 'Name'), autofocus: true),
                TextField(controller: phoneCtl, decoration: const InputDecoration(labelText: 'Phone')),
                TextField(controller: gstCtl,   decoration: const InputDecoration(labelText: 'GSTIN')),
                TextField(controller: stateCtl, decoration: const InputDecoration(labelText: 'State Code')),
                TextField(controller: addrCtl,  decoration: const InputDecoration(labelText: 'Address')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => safePop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => safePop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    final repo = ref.read(settingsRepoProvider);

    final b = BranchInfo(
      id: initial?.id ?? 'tmp-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: tenantId,
      name: nameCtl.text.trim(),
      phone: phoneCtl.text.trim().isEmpty ? null : phoneCtl.text.trim(),
      gstin: gstCtl.text.trim().isEmpty ? null : gstCtl.text.trim(),
      address: addrCtl.text.trim().isEmpty ? null : addrCtl.text.trim(),
      stateCode: stateCtl.text.trim().isEmpty ? null : stateCtl.text.trim(),
    );

    if (initial == null) {
      await repo.createBranchOptimistic(b);
    } else {
      await repo.updateBranchOptimistic(b);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Branch?'),
        content: const Text('This will remove the branch. This change is queued if you are offline.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(settingsRepoProvider).deleteBranchOptimistic(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Branch deleted (offline-safe)')));
      }
    }
  }
}
