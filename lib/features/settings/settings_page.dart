// ================================
// lib/features/settings/settings_page.dart
// ================================
// NOTE: Only change is: repo.watchPrinters(tenantId, branchId)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../data/repo/settings_repo.dart';
import '../../data/models.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;
    final canEdit = me?.permissions.contains('SETTINGS_EDIT') ?? false;

    final repo = ref.watch(settingsRepoProvider);
    final tenantId = ref.watch(activeTenantIdProvider);
    final branchId = ref.watch(activeBranchIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _Card(
                title: 'Branches',
                subtitleStream: repo.watchBranches().map((l) => '\${l.length} branches'),
                icon: Icons.store_mall_directory,
                onTap: () => context.push('/settings/branch'),
              ),
              _Card(
                title: 'Tables',
                subtitleStream: repo.watchTables(branchId).map((l) => '\${l.length} tables'),
                icon: Icons.table_restaurant,
                onTap: () => context.push('/settings/tables'),
                disabled: branchId.isEmpty,
              ),
              _Card(
                title: 'Printers',
                subtitleStream: repo.watchPrinters(tenantId, branchId).map((l) => '\${l.length} printers'),
                icon: Icons.print,
                onTap: () => context.push('/settings/printers'),
                disabled: branchId.isEmpty,
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.sync),
            label: const Text('Sync now'),
            onPressed: () async {
              if (tenantId.isNotEmpty) await repo.refreshBranches(tenantId);
              if (branchId.isNotEmpty) {
                await repo.refreshTables(branchId);
                await repo.refreshPrinters(tenantId: tenantId, branchId: branchId);
              }
              await repo.autoFlushOps();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Synced')),
                );
              }
            },
          ),
          if (!canEdit) const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('You have read-only access. Ask admin for SETTINGS_EDIT permission.',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.subtitleStream,
    required this.icon,
    required this.onTap,
    this.disabled = false,
  });

  final String title;
  final Stream<String> subtitleStream;
  final IconData icon;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        elevation: 1,
        child: InkWell(
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      StreamBuilder<String>(
                        stream: subtitleStream,
                        initialData: '—',
                        builder: (c, s) => Text(
                          s.data ?? '—',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
