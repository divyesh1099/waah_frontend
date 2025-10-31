import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Import API models with an alias
import 'package:waah_frontend/data/models.dart' as api;
// Import local DB models
import 'package:waah_frontend/data/local/app_db.dart';
import 'package:waah_frontend/data/repo/catalog_repo.dart';
import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/features/menu/menu_page.dart'; // For providers
import 'package:waah_frontend/features/sync/sync_controller.dart';


/// Provider: load items for a *local* category ID.
final categoryItemsStreamProvider = StreamProvider.family
    .autoDispose<List<MenuItem>, int>((ref, localCategoryId) {
  final repo = ref.watch(catalogRepoProvider);
  if (localCategoryId == 0) {
    return Stream.value([]);
  }
  return repo.watchItems(localCategoryId);
});

class CategoryItemsPage extends ConsumerWidget {
  const CategoryItemsPage({super.key, required this.category});
// This is now the local DB model
  final MenuCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catId = category.id;
    final asyncItems = ref.watch(categoryItemsStreamProvider(catId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Items • ${category.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add item',
            onPressed: () async {
              if (category.remoteId == null) return;

              final newData = await _promptNewItem(context);
              if (newData == null) return;

              try {
// Build an API MenuItem model for creation
                final draft = api.MenuItem(
                  id: null, // backend will assign
                  tenantId: ref.read(activeTenantIdProvider),
                  name: newData.name,
                  description: newData.description,
                  categoryId: category.remoteId!, // Use remote ID for API
                  isActive: true,
                  gstRate: 5.0,
                );

                await ref.read(catalogRepoProvider).createItem(draft);

// Trigger sync to pull the new item
                await ref.read(syncControllerProvider.notifier).syncNow();

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added "${newData.name}"'),
                    duration: const Duration(milliseconds: 900),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to add item: $e'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: asyncItems.when(
        loading: () =>
        const Center(child: CircularProgressIndicator()),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Failed to load items:\n$e'),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('No items in this category yet'),
            );
          }

// Sort local data
          items.sort((a, b) {
            final aActive = (a.isActive && !a.stockOut) ? 0 : 1;
            final bActive = (b.isActive && !b.stockOut) ? 0 : 1;
            final cmpActive = aActive.compareTo(bActive);
            if (cmpActive != 0) return cmpActive;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) =>
            const Divider(height: 1),
            itemBuilder: (context, index) {
              final it = items[index];

              final isLive = it.isActive && !it.stockOut;
              final badge = isLive ? 'ACTIVE' : 'INACTIVE';

              return ListTile(
                title: Text(it.name),
                subtitle: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    if (it.description != null &&
                        it.description!.trim().isNotEmpty)
                      Text(
                        it.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      badge,
                      style: TextStyle(
                        fontSize: 12,
                        color: isLive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: (it.remoteId == null || it.remoteId!.isEmpty) ? null : () async {
                    final ok = await _confirm(
                      context,
                      'Delete "${it.name}"?',
                    );
                    if (!ok || it.remoteId == null) return;

                    try {
                      await ref
                          .read(catalogRepoProvider)
                          .deleteItem(it.remoteId!);

// Trigger sync
                      await ref.read(syncControllerProvider.notifier).syncNow();

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            'Deleted "${it.name}"',
                          ),
                          duration: const Duration(
                            milliseconds: 900,
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            'Could not delete "${it.name}": $e',
                          ),
                        ),
                      );
                    }
                  },
                ),
                onTap: () {
// TODO: push an ItemEditPage for variants/price/tax.
// Navigator.push(...);
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Simple data class for "new item" dialog result
class _NewItemData {
  final String name;
  final String? description;
  _NewItemData({required this.name, this.description});
}

/// Dialog: ask for name + optional description
Future<_NewItemData?> _promptNewItem(BuildContext context) async {
  final nameCtl = TextEditingController();
  final descCtl = TextEditingController();

  return showDialog<_NewItemData>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('New item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                  labelText: 'Item name',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = nameCtl.text.trim();
              if (n.isEmpty) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(
                ctx,
                _NewItemData(
                  name: n,
                  description: descCtl.text.trim().isEmpty
                      ? null
                      : descCtl.text.trim(),
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      );
    },
  );
}

/// yes/no confirm reuse
Future<bool> _confirm(BuildContext context, String message) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );
  return res ?? false;
}