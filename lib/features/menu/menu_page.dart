// lib/features/menu/menu_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/data/models.dart';
import 'package:waah_frontend/data/repo/catalog_repo.dart';

/// Loads categories once via HTTP (no local DB stream anymore).
final categoriesProvider = FutureProvider<List<MenuCategory>>((ref) async {
  final repo = ref.watch(catalogRepoProvider);
  final list = await repo.loadCategories();
  // Keep UI stable: sort by position if present.
  list.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
  return list;
});

class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          IconButton(
            tooltip: 'Add category',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final name = await _promptForName(context, title: 'New category');
              if (name == null || name.trim().isEmpty) return;

              await ref.read(catalogRepoProvider).addCategory(name.trim());
              ref.invalidate(categoriesProvider); // refresh the list
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
                subtitle: Text('Position ${c.position ?? 0}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await _confirm(context, 'Delete "${c.name}"?');
                    if (!ok) return;
                    if (c.id == null) return;
                    await ref.read(catalogRepoProvider).deleteCategory(c.id!);
                    ref.invalidate(categoriesProvider);
                  },
                ),
                onTap: () {
                  // TODO: navigate to items in this category
                },
              );
            },
          );
        },
      ),
    );
  }
}

Future<String?> _promptForName(BuildContext context, {required String title}) async {
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, ctl.text.trim()), child: const Text('Save')),
      ],
    ),
  );
}

Future<bool> _confirm(BuildContext context, String message) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
      ],
    ),
  );
  return res ?? false;
}
