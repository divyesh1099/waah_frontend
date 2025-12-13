import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/app/providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(tenantBranchBootstrapperProvider);
    final tenantId = ref.watch(activeTenantIdProvider);
    final branchId = ref.watch(activeBranchIdProvider);

    if (tenantId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Please sign in so we can load your menu.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (branchId.isEmpty) {
      final branchesAsync = ref.watch(branchesProvider);
      return Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: branchesAsync.when(
          data: (branches) {
            if (branches.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No branches found for this tenant. Please create one in Settings.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (branches.length == 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(activeBranchIdProvider.notifier).set(branches.first.id);
              });
              return const Center(child: CircularProgressIndicator());
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: branches.length,
              itemBuilder: (_, i) {
                final b = branches[i];
                return Card(
                  child: ListTile(
                    title: Text(b.name),
                    subtitle: b.address == null ? null : Text(b.address!),
                    onTap: () => ref.read(activeBranchIdProvider.notifier).set(b.id),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Failed to load branches: $e'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => ref.invalidate(branchesProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final rs = ref.watch(restaurantSettingsProvider).valueOrNull;
    final brand = (rs != null && rs.name.isNotEmpty) ? rs.name : 'Restaurant';
    return Center(
      child: Text('Welcome to $brand - Windows & Android ready.'),
    );
  }
}
