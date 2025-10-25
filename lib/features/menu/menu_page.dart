import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/data/models.dart';
import 'package:waah_frontend/data/repo/catalog_repo.dart';
import 'package:waah_frontend/features/menu/category_items_page.dart';

/// Loads all categories via HTTP.
/// We currently pass '' for tenant/branch because that's how the rest
/// of the app is talking to the backend.
final categoriesProvider = FutureProvider<List<MenuCategory>>((ref) async {
  final repo = ref.watch(catalogRepoProvider);

  // actually hit backend
  final cats = await repo.loadCategories(
    tenantId: '',
    branchId: '',
  );

  // keep UI stable: sort by position
  cats.sort((a, b) => a.position.compareTo(b.position));

  return cats;
});

class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Setup'),
        actions: [
          IconButton(
            tooltip: 'Add category',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final name =
              await _promptForName(context, title: 'New category');
              if (name == null || name.trim().isEmpty) return;

              try {
                await ref.read(catalogRepoProvider).addCategory(
                  name.trim(),
                  tenantId: '',
                  branchId: '',
                  position: 0,
                );

                // refresh list after creating
                ref.invalidate(categoriesProvider);
              } catch (e) {
                // show failure
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to add: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Failed to load categories:\n$e'),
        ),
        data: (cats) {
          if (cats.isEmpty) {
            return const Center(child: Text('No categories yet'));
          }
          return ListView.separated(
            itemCount: cats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = cats[i];
              return ListTile(
                title: Text(c.name),
                subtitle: Text('Position ${c.position}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await _confirm(
                      context,
                      'Delete "${c.name}"?',
                    );
                    if (!ok) return;
                    if (c.id == null) return;

                    try {
                      await ref
                          .read(catalogRepoProvider)
                          .deleteCategory(c.id!);

                      ref.invalidate(categoriesProvider);

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                          Text('Deleted category "${c.name}"'),
                          duration:
                          const Duration(milliseconds: 900),
                        ),
                      );
                    } catch (e) {
                      // e.g. backend refuses because category still has items
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Could not delete "${c.name}": $e',
                          ),
                          duration:
                          const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                onTap: () {
                  // drill into items for this category
                  if (c.id == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CategoryItemsPage(category: c),
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

/// Ask user for a category name
Future<String?> _promptForName(
    BuildContext context, {
      required String title,
    }) async {
  final ctl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctl,
        decoration: const InputDecoration(labelText: 'Name'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, ctl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// simple yes/no confirm dialog
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
