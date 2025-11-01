import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import 'package:go_router/go_router.dart';

class TableSettingsPage extends ConsumerWidget {
  const TableSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(settingsRepoProvider);
    final branchId = ref.watch(activeBranchIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tables'),
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.store),
          label: const Text('Change branch'),
          onPressed: () => context.push('/branch/select'),
        ),
      ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: branchId.isEmpty ? null : () => _openEditor(context, ref, branchId),
        icon: const Icon(Icons.add),
        label: const Text('New Table'),
      ),
      body: branchId.isEmpty
          ? const Center(child: Text('Pick a branch first'))
          : StreamBuilder<List<DiningTable>>(
        stream: repo.watchTables(branchId),
        initialData: const [],
        builder: (c, snap) {
          final items = snap.data ?? const [];
          if (items.isEmpty) return const Center(child: Text('No tables yet'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final t = items[i];
              return ListTile(
                title: Text(t.code),
                subtitle: Text([
                  if ((t.zone ?? '').isNotEmpty) 'Zone: ${t.zone}',
                  if (t.seats != null) 'Seats: ${t.seats}',
                ].join(' • ')),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _openEditor(context, ref, t.branchId, initial: t),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, t.branchId, t.id!),
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

  Future<void> _openEditor(BuildContext context, WidgetRef ref, String branchId, {DiningTable? initial}) async {
    final codeCtl = TextEditingController(text: initial?.code ?? '');
    final zoneCtl = TextEditingController(text: initial?.zone ?? '');
    final seatsCtl = TextEditingController(text: (initial?.seats ?? '').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        var closing = false;
        void safePop(bool v) { if (!closing) { closing = true; Navigator.of(dialogCtx).pop(v); } }

        return AlertDialog(
          title: Text(initial == null ? 'New Table' : 'Edit Table'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeCtl, decoration: const InputDecoration(labelText: 'Code (e.g. T1)'), autofocus: true),
              TextField(controller: zoneCtl, decoration: const InputDecoration(labelText: 'Zone (optional)')),
              TextField(controller: seatsCtl, decoration: const InputDecoration(labelText: 'Seats (optional)'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => safePop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => safePop(true), child: const Text('Save')),
          ],
        );
      },
    );

    if (ok != true) return;

    int? seats;
    final seatsStr = seatsCtl.text.trim();
    if (seatsStr.isNotEmpty) {
      final v = int.tryParse(seatsStr);
      if (v != null) seats = v;
    }

    final repo = ref.read(settingsRepoProvider);
    final t = DiningTable(
      id: initial?.id ?? 'tmp-${DateTime.now().millisecondsSinceEpoch}',
      branchId: branchId,
      code: codeCtl.text.trim(),
      zone: zoneCtl.text.trim().isEmpty ? null : zoneCtl.text.trim(),
      seats: seats,
    );

    if (initial == null) {
      await repo.createTableOptimistic(branchId, t);
    } else {
      await repo.updateTableOptimistic(branchId, t);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String branchId, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Table?'),
        content: const Text('This will remove the table. Works offline (queued).'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(settingsRepoProvider).deleteTableOptimistic(branchId, id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Table deleted')));
      }
    }
  }
}
