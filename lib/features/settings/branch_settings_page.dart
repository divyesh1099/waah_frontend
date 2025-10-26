import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';

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

  // api.fetchRestaurantSettings() already exists in your ApiClient.
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
                        const SizedBox(height: 12),
                        Text(
                          'Edit form coming next:\n- logo upload\n- gst_inclusive_default\n- service charge / packing charge\n- print_fssai_on_invoice toggle',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            // TODO: show edit dialog, call api.saveRestaurantSettings()
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
          width: 120,
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
