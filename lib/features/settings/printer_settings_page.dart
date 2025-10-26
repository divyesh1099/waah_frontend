import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';

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
                              final name =
                              (p['name'] ?? '').toString();
                              final type =
                              (p['type'] ?? '').toString();
                              final conn =
                              (p['connection_url'] ?? '').toString();
                              final isDefault =
                              p['is_default'] == true ? ' (default)' : '';
                              final drawerEnabled =
                                  p['cash_drawer_enabled'] == true;
                              return ListTile(
                                dense: true,
                                title: Text('$name$isDefault'),
                                subtitle: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Type: $type  ·  $conn',
                                      style: const TextStyle(
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (drawerEnabled)
                                      const Text(
                                        'Cash drawer enabled',
                                        style: TextStyle(
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
                                    // TODO: show edit printer dialog -> api.updatePrinter(...)
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            // TODO: show "Add Printer" dialog -> api.createPrinter(...)
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
                                    // TODO: show edit station dialog -> api.createStation(...) / update later
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            // TODO: show "Add Station" dialog -> api.createStation(...)
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
