// ==============================================
// lib/features/settings/printer_settings_page.dart
// ==============================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart'; // for DioException type checks

import 'printer_scanner.dart';

class PrinterSettingsPage extends ConsumerWidget {
  const PrinterSettingsPage({super.key});

  // ... (keep _errMsg) ...
  String _errMsg(Object e) {
    if (e is ApiException) {
      final status = e.status != null ? ' [${e.status}]' : '';
      return (e.message.isNotEmpty ? e.message : 'Failed') + status;
    }
    if (e is DioException) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) {
        return '${data['detail']}${status != null ? ' [$status]' : ''}';
      }
      if (data is Map && data['message'] != null) {
        return '${data['message']}${status != null ? ' [$status]' : ''}';
      }
      return 'Network error${status != null ? ' [$status]' : ''}';
    }
    return e.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(settingsRepoProvider);
    final tenantId = ref.watch(activeTenantIdProvider);
    final branchId = ref.watch(activeBranchIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.radar),
            tooltip: 'Scan Network',
            onPressed: () => _showScanner(context),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.store),
            label: const Text('Change branch'),
            onPressed: () => context.push('/branch/select'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: branchId.isEmpty ? null : () => _openEditor(context, ref, tenantId, branchId),
        icon: const Icon(Icons.add),
        label: const Text('Add Printer'),
      ),
      body: branchId.isEmpty
          ? const Center(child: Text('Pick a branch first'))
          : StreamBuilder<List<Printer>>(
        stream: repo.watchPrinters(tenantId, branchId),
        initialData: const [],
        builder: (c, snap) {
          final items = snap.data ?? const [];
          if (items.isEmpty) return const Center(child: Text('No printers yet'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final p = items[i];
              return ListTile(
                leading: Icon(p.type == PrinterType.BILLING ? Icons.receipt_long : Icons.restaurant),
                title: Text(p.name),
                subtitle: Text([
                  p.type.name,
                  if ((p.connectionUrl ?? '').isNotEmpty) p.connectionUrl!,
                  if (p.isDefault) 'Default',
                  if (p.cashDrawerEnabled) 'Cash Drawer: ${p.cashDrawerCode ?? "enabled"}',
                ].join(' • ')),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (p.type == PrinterType.BILLING)
                    IconButton(
                      icon: Icon(p.isDefault ? Icons.check_circle : Icons.radio_button_unchecked),
                      tooltip: 'Make Default Billing',
                      onPressed: () async {
                        final updated = p.toJson()..['is_default'] = true;
                        await ref.read(settingsRepoProvider).updatePrinterOptimistic(
                          tenantId,
                          branchId,
                          Printer.fromJson(updated),
                        );
                        try {
                          await ref.read(apiClientProvider).saveRestaurantSettings({
                            'tenant_id': tenantId,
                            'branch_id': branchId,
                            'billing_printer_id': p.id,
                          });
                        } catch (_) {}
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Default billing printer set to ${p.name}')),
                          );
                        }
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _openEditor(context, ref, tenantId, branchId, initial: p),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, tenantId, branchId, p.id!),
                    tooltip: 'Delete',
                  ),
                  IconButton(
                    icon: const Icon(Icons.print),
                    tooltip: 'Test',
                    onPressed: () async {
                      try {
                        await ref.read(apiClientProvider).testPrinter(p.id!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Test job sent to ${p.name}')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Test failed: ${_errMsg(e)}')),
                          );
                        }
                      }
                    },
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showScanner(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => const _ScannerDialog(),
    );
  }

  Future<void> _openEditor(
      BuildContext context,
      WidgetRef ref,
      String tenantId,
      String branchId, {
        Printer? initial,
        String? prefillUrl, // NEW
      }) async {
    final nameCtl = TextEditingController(text: initial?.name ?? '');
    final urlCtl = TextEditingController(text: initial?.connectionUrl ?? prefillUrl ?? '');
    final drawerCtl = TextEditingController(text: initial?.cashDrawerCode ?? '');
    var type = initial?.type ?? PrinterType.BILLING;
    var isDefault = initial?.isDefault ?? (type == PrinterType.BILLING);
    var drawer = initial?.cashDrawerEnabled ?? false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (c, setState) {
          return AlertDialog(
            title: Text(initial == null ? 'Add Printer' : 'Edit Printer'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PrinterType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: PrinterType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    type = v ?? PrinterType.BILLING;
                    if (type == PrinterType.KITCHEN) isDefault = false;
                  }),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: urlCtl,
                        decoration: const InputDecoration(
                            labelText: 'Connection URL',
                            hintText: 'http://192.168.1.x:9100'
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.radar),
                      tooltip: 'Scan',
                      onPressed: () async {
                        // Close this dialog and open scanner, then re-open this?
                        // Or just open scanner and wait for result?
                        final ip = await showDialog<String>(
                          context: context,
                          builder: (_) => const _ScannerDialog(),
                        );
                        if (ip != null) {
                          urlCtl.text = 'http://$ip:9100';
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (type == PrinterType.BILLING)
                  SwitchListTile(
                    title: const Text('Default Billing Printer'),
                    value: isDefault,
                    onChanged: (v) => setState(() => isDefault = v),
                  ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Cash Drawer Enabled'),
                  value: drawer,
                  onChanged: (v) => setState(() => drawer = v),
                ),
                if (drawer)
                  TextField(
                    controller: drawerCtl,
                    decoration: const InputDecoration(labelText: 'Cash Drawer Code (optional)'),
                  ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Save')),
            ],
          );
        });
      },
    );
    if (ok != true) return;

    final repo = ref.read(settingsRepoProvider);
    final printer = Printer(
      id: initial?.id ?? 'tmp-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: tenantId,
      branchId: branchId,
      name: nameCtl.text.trim(),
      type: type,
      connectionUrl: urlCtl.text.trim().isEmpty ? null : urlCtl.text.trim(),
      isDefault: type == PrinterType.BILLING ? isDefault : false,
      cashDrawerEnabled: drawer,
      cashDrawerCode: drawerCtl.text.trim().isEmpty ? null : drawerCtl.text.trim(),
    );

    if (initial == null) {
      await repo.createPrinterOptimistic(tenantId, branchId, printer);
    } else {
      await repo.updatePrinterOptimistic(tenantId, branchId, printer);
    }

    if (printer.type == PrinterType.BILLING && printer.isDefault) {
      try {
        await ref.read(apiClientProvider).saveRestaurantSettings({
          'tenant_id': tenantId,
          'branch_id': branchId,
          'billing_printer_id': printer.id,
        });
      } catch (_) {}
    }
  }

  Future<void> _confirmDelete(
      BuildContext context,
      WidgetRef ref,
      String tenantId,
      String branchId,
      String id,
      ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Printer?'),
        content: const Text('This will remove the printer. Works offline (queued).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(settingsRepoProvider).deletePrinterOptimistic(tenantId, branchId, id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Printer deleted')));
      }
    }
  }
}

class _ScannerDialog extends StatefulWidget {
  const _ScannerDialog();

  @override
  State<_ScannerDialog> createState() => _ScannerDialogState();
}

class _ScannerDialogState extends State<_ScannerDialog> {
  final _scanner = PrinterScanner();
  bool _scanning = true;
  double _progress = 0.0;
  List<String> _found = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    try {
      final results = await _scanner.scanForPrinters(
        onProgress: (p) => setState(() => _progress = p),
      );
      if (mounted) {
        setState(() {
          _found = results;
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _scanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scanning Network...'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_scanning) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 16),
              Text('Scanning subnet (Port 9100)... ${( _progress * 100).toInt()}%'),
            ] else if (_error != null) ...[
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () {
                setState(() {
                  _scanning = true;
                  _error = null;
                  _progress = 0;
                });
                _startScan();
              }, child: const Text('Retry'))
            ] else if (_found.isEmpty) ...[
              const Icon(Icons.search_off, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('No printers found on Port 9100.'),
            ] else ...[
              const Text('Found Printers:'),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _found.length,
                  itemBuilder: (ctx, i) {
                    final ip = _found[i];
                    return ListTile(
                      leading: const Icon(Icons.print),
                      title: Text(ip),
                      subtitle: const Text('Port 9100 Open'),
                      onTap: () => Navigator.pop(context, ip),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
