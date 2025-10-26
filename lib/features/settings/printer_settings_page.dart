import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';

/// bundle printers + stations in one async load for this branch
final printerAndStationProvider =
FutureProvider.autoDispose<_PrinterStationBundle>((ref) async {
  final api = ref.watch(apiClientProvider);
  final me = ref.watch(authControllerProvider).me;
  final tenantId = me?.tenantId ?? '';
  final branchId = ref.watch(activeBranchIdProvider);

  if (tenantId.isEmpty || branchId.isEmpty) {
    return const _PrinterStationBundle(
      printers: [],
      stations: [],
    );
  }

  final printers = await api.listPrinters(
    tenantId: tenantId,
    branchId: branchId,
  );

  final stations = await api.listStations(
    tenantId: tenantId,
    branchId: branchId,
  );

  return _PrinterStationBundle(
    printers: printers,
    stations: stations,
  );
});

class _PrinterStationBundle {
  final List<Map<String, dynamic>> printers;
  final List<Map<String, dynamic>> stations;
  const _PrinterStationBundle({
    required this.printers,
    required this.stations,
  });
}

class PrinterSettingsPage extends ConsumerWidget {
  const PrinterSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(authControllerProvider).me?.tenantId ?? '';
    final branchId = ref.watch(activeBranchIdProvider);

    final asyncData = ref.watch(printerAndStationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printers & Stations'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Text(
            'Failed to load: $e',
            style: const TextStyle(color: Colors.red),
          ),
          data: (bundle) {
            return ListView(
              children: [
                Text(
                  'Tenant: $tenantId',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Branch: $branchId',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),

                // Printers card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Printers',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (bundle.printers.isEmpty)
                          Text(
                            'No printers configured.\nAdd at least one BILLING printer so invoices & cash drawer work.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          )
                        else
                          Column(
                            children: bundle.printers.map((p) {
                              final name = (p['name'] ?? '').toString();
                              final type = (p['type'] ?? '').toString();
                              final conn =
                              (p['connection_url'] ?? '').toString();
                              final isDefault =
                              p['is_default'] == true ? ' (default)' : '';
                              final drawerEnabled =
                                  p['cash_drawer_enabled'] == true;
                              final drawerCode =
                              (p['cash_drawer_code'] ?? '').toString();
                              return ListTile(
                                dense: true,
                                title: Text('$name$isDefault'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Type: $type  ·  $conn',
                                      style: const TextStyle(
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (drawerEnabled)
                                      Text(
                                        drawerCode.isEmpty
                                            ? 'Cash drawer enabled'
                                            : 'Cash drawer: $drawerCode',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.brown,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    // Optional future:
                                    // showModalBottomSheet(...) with prefilled _AddPrinterSheet in "edit mode"
                                    // then call api.updatePrinter(...)
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () async {
                            final added =
                            await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => const _AddPrinterSheet(),
                            );

                            if (added == true && context.mounted) {
                              ref.invalidate(printerAndStationProvider);
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Printer'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Kitchen Stations card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kitchen Stations',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (bundle.stations.isEmpty)
                          Text(
                            'No stations yet.\nAdd Tandoor / Chinese / Billing etc so KOT routing works.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          )
                        else
                          Column(
                            children: bundle.stations.map((st) {
                              final name =
                              (st['name'] ?? '').toString();
                              final printerId =
                              (st['printer_id'] ?? '').toString();
                              return ListTile(
                                dense: true,
                                title: Text(name),
                                subtitle: Text(
                                  printerId.isEmpty
                                      ? 'No printer linked'
                                      : 'Printer: $printerId',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    // Optional future:
                                    // show bottom sheet with station edit
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () async {
                            final added =
                            await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => _AddStationSheet(
                                printers: bundle.printers,
                              ),
                            );

                            if (added == true && context.mounted) {
                              ref.invalidate(printerAndStationProvider);
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Station'),
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

/// Bottom sheet to CREATE a printer.
/// Calls POST /settings/printers via ApiClient.createPrinter(...)
class _AddPrinterSheet extends ConsumerStatefulWidget {
  const _AddPrinterSheet();

  @override
  ConsumerState<_AddPrinterSheet> createState() => _AddPrinterSheetState();
}

class _AddPrinterSheetState extends ConsumerState<_AddPrinterSheet> {
  final _nameCtl = TextEditingController();
  final _urlCtl = TextEditingController();
  final _drawerCodeCtl = TextEditingController();

  String _type = 'BILLING'; // BILLING or KITCHEN
  bool _drawerEnabled = false;

  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _nameCtl.dispose();
    _urlCtl.dispose();
    _drawerCodeCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tenantId =
        ref.read(authControllerProvider).me?.tenantId ?? '';
    final branchId = ref.read(activeBranchIdProvider);

    final name = _nameCtl.text.trim();
    final url = _urlCtl.text.trim();

    if (tenantId.isEmpty || branchId.isEmpty) {
      setState(() {
        _err = 'Missing tenant/branch';
      });
      return;
    }
    if (name.isEmpty || url.isEmpty) {
      setState(() {
        _err = 'Name and connection URL are required';
      });
      return;
    }

    setState(() {
      _saving = true;
      _err = null;
    });

    try {
      await ref.read(apiClientProvider).createPrinter(
        tenantId: tenantId,
        branchId: branchId,
        name: name,
        type: _type,
        connectionUrl: url,
        cashDrawerEnabled:
        _type == 'BILLING' ? _drawerEnabled : false,
        cashDrawerCode: _type == 'BILLING' && _drawerEnabled
            ? _drawerCodeCtl.text.trim()
            : null,
      );

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

    // Only show drawer options when type == BILLING
    final showDrawerStuff = _type == 'BILLING';

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
            'Add Printer',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtl,
            decoration: const InputDecoration(
              labelText: 'Printer Name *',
              helperText: 'Example: Billing Printer, Kitchen Printer',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            items: const [
              DropdownMenuItem(
                value: 'BILLING',
                child: Text('BILLING (Invoices / Cash drawer)'),
              ),
              DropdownMenuItem(
                value: 'KITCHEN',
                child: Text('KITCHEN (KOT / Station)'),
              ),
            ],
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _type = val;
                if (_type != 'BILLING') {
                  _drawerEnabled = false;
                  _drawerCodeCtl.clear();
                }
              });
            },
            decoration: const InputDecoration(
              labelText: 'Type',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlCtl,
            decoration: const InputDecoration(
              labelText: 'Connection URL *',
              helperText:
              'Example: http://192.168.0.50:9100/agent (your local print agent)',
            ),
          ),
          const SizedBox(height: 12),

          if (showDrawerStuff) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _drawerEnabled,
              title: const Text('Cash drawer enabled'),
              onChanged: (v) {
                setState(() {
                  _drawerEnabled = v;
                });
              },
            ),
            const SizedBox(height: 8),
            if (_drawerEnabled)
              TextField(
                controller: _drawerCodeCtl,
                decoration: const InputDecoration(
                  labelText: 'Drawer Kick Code',
                  helperText: 'Example: PULSE_2_100',
                ),
              ),
            const SizedBox(height: 12),
          ],

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

/// Bottom sheet to CREATE a kitchen station (like "Tandoor", "Chinese")
/// Calls POST /settings/stations via ApiClient.createStation(...)
class _AddStationSheet extends ConsumerStatefulWidget {
  const _AddStationSheet({
    required this.printers,
  });

  final List<Map<String, dynamic>> printers;

  @override
  ConsumerState<_AddStationSheet> createState() =>
      _AddStationSheetState();
}

class _AddStationSheetState extends ConsumerState<_AddStationSheet> {
  final _nameCtl = TextEditingController();
  String? _printerId;

  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    // default to first printer (usually kitchen printer)
    if (widget.printers.isNotEmpty) {
      _printerId = widget.printers.first['id']?.toString();
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tenantId =
        ref.read(authControllerProvider).me?.tenantId ?? '';
    final branchId = ref.read(activeBranchIdProvider);

    final name = _nameCtl.text.trim();
    final printerId = _printerId;

    if (tenantId.isEmpty || branchId.isEmpty) {
      setState(() {
        _err = 'Missing tenant/branch';
      });
      return;
    }
    if (name.isEmpty) {
      setState(() {
        _err = 'Station name is required';
      });
      return;
    }

    setState(() {
      _saving = true;
      _err = null;
    });

    try {
      // Build a KitchenStation model for createStation(...)
      // Assumes KitchenStation has named params:
      //   tenantId, branchId, name, printerId
      // and toJson() maps them to the backend keys.
      final station = KitchenStation(
        tenantId: tenantId,
        branchId: branchId,
        name: name,
        printerId: (printerId == null || printerId.isEmpty)
            ? null
            : printerId,
      );

      await ref.read(apiClientProvider).createStation(station);

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
            'Add Station',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtl,
            decoration: const InputDecoration(
              labelText: 'Station Name *',
              helperText:
              'Examples: Billing, Tandoor, Chinese, Bar',
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _printerId,
            items: widget.printers.map((p) {
              final pid = (p['id'] ?? '').toString();
              final pname = (p['name'] ?? '').toString();
              final ptype = (p['type'] ?? '').toString();
              return DropdownMenuItem<String>(
                value: pid,
                child: Text('$pname ($ptype)'),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _printerId = val;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Printer to send KOTs',
              helperText: 'Optional but recommended',
            ),
          ),
          const SizedBox(height: 12),

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
