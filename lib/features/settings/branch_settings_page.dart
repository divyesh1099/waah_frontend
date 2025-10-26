import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';

/// Provider to load current restaurant/branch settings from backend.
/// We keep it simple for now: just fetch raw map from api.fetchRestaurantSettings.
final branchSettingsProvider =
FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final me = ref.watch(authControllerProvider).me;
  final tenantId = me?.tenantId ?? '';
  final branchId = ref.watch(activeBranchIdProvider);

  if (tenantId.isEmpty || branchId.isEmpty) {
    return <String, dynamic>{};
  }

  final data = await api.fetchRestaurantSettings(
    tenantId: tenantId,
    branchId: branchId,
  );
  return data;
});

class BranchSettingsPage extends ConsumerWidget {
  const BranchSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(authControllerProvider).me?.tenantId ?? '';
    final branchId = ref.watch(activeBranchIdProvider);

    final asyncSettings = ref.watch(branchSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branch / Restaurant Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: asyncSettings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Text(
            'Failed to load: $e',
            style: const TextStyle(color: Colors.red),
          ),
          data: (data) {
            // data is {} if not configured yet
            final name = (data['name'] ?? '').toString();
            final address = (data['address'] ?? '').toString();
            final phone = (data['phone'] ?? '').toString();
            final gstin = (data['gstin'] ?? '').toString();
            final fssai = (data['fssai'] ?? '').toString();
            final footer =
            (data['invoice_footer'] ?? 'Thank you!').toString();

            final gstInclusive =
                data['gst_inclusive_default'] == true;
            final printFssai =
                data['print_fssai_on_invoice'] == true;

            final svcMode =
            (data['service_charge_mode'] ?? 'NONE').toString();
            final svcVal =
            (data['service_charge_value'] ?? 0).toString();

            final packMode =
            (data['packing_charge_mode'] ?? 'NONE').toString();
            final packVal =
            (data['packing_charge_value'] ?? 0).toString();

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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row('Name', name),
                        _row('Phone', phone),
                        _row('Address', address),
                        _row('GSTIN', gstin),
                        _row('FSSAI', fssai),
                        _row('Invoice footer', footer),
                        _row('GST inclusive default',
                            gstInclusive ? 'Yes' : 'No'),
                        _row('Print FSSAI on invoice',
                            printFssai ? 'Yes' : 'No'),
                        _row(
                          'Service Charge',
                          '$svcMode $svcVal'
                              .replaceAll('NONE 0', 'NONE'),
                        ),
                        _row(
                          'Packing Charge',
                          '$packMode $packVal'
                              .replaceAll('NONE 0', 'NONE'),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () async {
                            final saved = await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => _BranchEditSheet(
                                tenantId: tenantId,
                                branchId: branchId,
                                initialData: data,
                              ),
                            );

                            if (saved == true && context.mounted) {
                              ref.invalidate(branchSettingsProvider);
                            }
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
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

Widget _row(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    ),
  );
}

/// Bottom sheet that lets you edit restaurant / branch profile + charges.
/// Calls POST /settings/restaurant via ApiClient.saveRestaurantSettings(...)
class _BranchEditSheet extends ConsumerStatefulWidget {
  const _BranchEditSheet({
    required this.tenantId,
    required this.branchId,
    required this.initialData,
  });

  final String tenantId;
  final String branchId;
  final Map<String, dynamic> initialData;

  @override
  ConsumerState<_BranchEditSheet> createState() => _BranchEditSheetState();
}

class _BranchEditSheetState extends ConsumerState<_BranchEditSheet> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _addrCtl;
  late final TextEditingController _gstCtl;
  late final TextEditingController _fssaiCtl;
  late final TextEditingController _footerCtl;
  late final TextEditingController _svcValCtl;
  late final TextEditingController _packValCtl;

  bool _gstInclusive = true;
  bool _printFssai = true;

  // enums from backend ChargeMode: "NONE", "FIXED", "PERCENT"
  String _svcMode = 'NONE';
  String _packMode = 'NONE';

  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;

    _nameCtl  = TextEditingController(text: (d['name'] ?? '').toString());
    _phoneCtl = TextEditingController(text: (d['phone'] ?? '').toString());
    _addrCtl  = TextEditingController(text: (d['address'] ?? '').toString());
    _gstCtl   = TextEditingController(text: (d['gstin'] ?? '').toString());
    _fssaiCtl = TextEditingController(text: (d['fssai'] ?? '').toString());
    _footerCtl = TextEditingController(
      text: (d['invoice_footer'] ?? 'Thank you!').toString(),
    );

    _gstInclusive = d['gst_inclusive_default'] == true;
    _printFssai   = d['print_fssai_on_invoice'] == true;

    _svcMode = (d['service_charge_mode'] ?? 'NONE')
        .toString()
        .toUpperCase();
    _packMode = (d['packing_charge_mode'] ?? 'NONE')
        .toString()
        .toUpperCase();

    _svcValCtl = TextEditingController(
      text: (d['service_charge_value'] ?? '0').toString(),
    );
    _packValCtl = TextEditingController(
      text: (d['packing_charge_value'] ?? '0').toString(),
    );
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _addrCtl.dispose();
    _gstCtl.dispose();
    _fssaiCtl.dispose();
    _footerCtl.dispose();
    _svcValCtl.dispose();
    _packValCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      setState(() {
        _err = 'Name is required';
      });
      return;
    }

    setState(() {
      _saving = true;
      _err = null;
    });

    try {
      final svcVal  = double.tryParse(_svcValCtl.text.trim()) ?? 0.0;
      final packVal = double.tryParse(_packValCtl.text.trim()) ?? 0.0;

      final body = <String, dynamic>{
        'tenant_id': widget.tenantId,
        'branch_id': widget.branchId,
        'name': name,
        'phone': _phoneCtl.text.trim(),
        'address': _addrCtl.text.trim(),
        'gstin': _gstCtl.text.trim(),
        'fssai': _fssaiCtl.text.trim(),
        'invoice_footer': _footerCtl.text.trim(),
        'gst_inclusive_default': _gstInclusive,
        'print_fssai_on_invoice': _printFssai,
        'service_charge_mode': _svcMode,
        'service_charge_value': svcVal,
        'packing_charge_mode': _packMode,
        'packing_charge_value': packVal,
      };

      await ref.read(apiClientProvider).saveRestaurantSettings(body);

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
            'Edit Branch / Restaurant',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),

          // Basic profile
          TextField(
            controller: _nameCtl,
            decoration: const InputDecoration(
              labelText: 'Restaurant / Branch Name *',
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
            controller: _addrCtl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Address',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _gstCtl,
            decoration: const InputDecoration(
              labelText: 'GSTIN',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fssaiCtl,
            decoration: const InputDecoration(
              labelText: 'FSSAI',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _printFssai,
            title: const Text('Print FSSAI on invoice'),
            onChanged: (v) {
              setState(() => _printFssai = v);
            },
          ),

          const Divider(height: 32),

          // tax / footer
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _gstInclusive,
            title: const Text('Prices include GST by default'),
            subtitle: const Text(
              'If ON, menu prices are tax-inclusive.',
            ),
            onChanged: (v) {
              setState(() => _gstInclusive = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _footerCtl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Invoice footer',
              helperText: 'Shown at bottom of bills/invoices',
            ),
          ),

          const Divider(height: 32),

          // service charge
          const Text(
            'Service Charge',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _svcMode,
                  decoration: const InputDecoration(
                    labelText: 'Mode',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'NONE',
                      child: Text('NONE'),
                    ),
                    DropdownMenuItem(
                      value: 'FIXED',
                      child: Text('FIXED'),
                    ),
                    DropdownMenuItem(
                      value: 'PERCENT',
                      child: Text('PERCENT'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _svcMode = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _svcValCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    helperText: '₹ or % depending on mode',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // packing charge
          const Text(
            'Packing Charge',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _packMode,
                  decoration: const InputDecoration(
                    labelText: 'Mode',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'NONE',
                      child: Text('NONE'),
                    ),
                    DropdownMenuItem(
                      value: 'FIXED',
                      child: Text('FIXED'),
                    ),
                    DropdownMenuItem(
                      value: 'PERCENT',
                      child: Text('PERCENT'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _packMode = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _packValCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    helperText: '₹ or % depending on mode',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

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
