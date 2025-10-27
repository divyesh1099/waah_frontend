import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/models.dart';
import 'package:waah_frontend/data/repo/catalog_repo.dart';
import 'package:waah_frontend/widgets/menu_media.dart';

import 'menu_item_detail_page.dart';

/// Items for a given category, scoped to current tenant/branch.
final categoryItemsProvider = FutureProvider.family
    .autoDispose<List<MenuItem>, String>((ref, categoryId) async {
  final repo = ref.watch(catalogRepoProvider);

  final me = ref.watch(authControllerProvider).me;
  final tenantId = me?.tenantId ?? '';
  final branchId = ref.watch(activeBranchIdProvider);

  if (tenantId.isEmpty || branchId.isEmpty || categoryId.isEmpty) {
    return <MenuItem>[];
  }

  final list = await repo.loadItems(
    categoryId: categoryId,
    tenantId: tenantId,
  );

  final sorted = [...list]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return sorted;
});

class MenuItemsPage extends ConsumerWidget {
  const MenuItemsPage({super.key, required this.category});

  final MenuCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catId = category.id;

    if (catId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(category.name)),
        body: const Center(child: Text('Category not saved yet')),
      );
    }

    final itemsAsync = ref.watch(categoryItemsProvider(catId));

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

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final it = items[i];

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
                      onPressed: () async {
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => MenuItemDetailPage(item: it),
                          ),
                        );
                        if (changed == true) {
                          ref.invalidate(categoryItemsProvider(catId));
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete item',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await _confirm(
                          context,
                          'Delete "${it.name}"?\n(Soft delete, hides in POS)',
                        );
                        if (!ok || it.id == null) return;

                        try {
                          await ref.read(catalogRepoProvider).deleteItem(it.id!);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Deleted ${it.name}')),
                            );
                          }
                          ref.invalidate(categoryItemsProvider(catId));
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
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => MenuItemDetailPage(item: it),
                    ),
                  );
                  if (changed == true) {
                    ref.invalidate(categoryItemsProvider(catId));
                  }
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