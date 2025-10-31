import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/app/providers.dart';
// Import the local DB models
import 'package:waah_frontend/data/local/app_db.dart';
import 'package:waah_frontend/data/repo/catalog_repo.dart';
import 'package:waah_frontend/features/menu/menu_page.dart'; // For providers
import 'package:waah_frontend/features/sync/sync_controller.dart';
import 'package:waah_frontend/widgets/menu_media.dart';
import 'menu_item_detail_page.dart';

// This provider now uses the local category ID (int)
final categoryItemsStreamProvider = StreamProvider.family
    .autoDispose<List<MenuItem>, int>((ref, localCategoryId) {
  final repo = ref.watch(catalogRepoProvider);
  if (localCategoryId == 0) {
    return Stream.value([]);
  }
  return repo.watchItems(localCategoryId);
});

class MenuItemsPage extends ConsumerWidget {
  const MenuItemsPage({super.key, required this.category});

// This is now the local DB model
  final MenuCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
// Use the local int ID
    final catId = category.id;
    final itemsAsync = ref.watch(categoryItemsStreamProvider(catId));

    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Failed to load items:\n$e'),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No items in this category'));
          }

// Sort the local data
          items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final it = items[i]; // This is now a db.MenuItem

              return ListTile(
                leading: MenuImage(path: it.imageUrl, size: 56),
                title: Text(it.name),
                subtitle: Text([
                  if (it.description != null && it.description!.trim().isNotEmpty)
                    it.description!.trim(),
                  'GST ${it.gstRate.toStringAsFixed(2)}%',
                  it.stockOut ? 'OUT OF STOCK' : 'In stock',
                ].join(' • ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit item',
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.of(context).push<bool>(
                          MaterialPageRoute(
// This now correctly passes the db.MenuItem
                            builder: (_) => MenuItemDetailPage(item: it),
                          ),
                        );
// No invalidation needed, streams will update
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete item',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: (it.remoteId == null || it.remoteId!.isEmpty) ? null : () async {
                        final ok = await _confirm(
                          context,
                          'Delete "${it.name}"?\n(This will sync with the server)',
                        );
                        if (!ok || it.remoteId == null) return;

                        try {
                          await ref.read(catalogRepoProvider).deleteItem(it.remoteId!);
// Trigger a sync to update local DB
                          await ref.read(syncControllerProvider.notifier).syncNow();

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Deleted ${it.name}')),
                            );
                          }
                        } catch (err) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Delete failed: $err')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push<bool>(
                    MaterialPageRoute(
// This now correctly passes the db.MenuItem
                      builder: (_) => MenuItemDetailPage(item: it),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

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
  return (res ?? false);
}