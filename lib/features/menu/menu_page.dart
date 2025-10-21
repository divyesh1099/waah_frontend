import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/collections.dart';
import '../../data/repo/catalog_repo.dart';

final categoriesStreamProvider =
StreamProvider.autoDispose<List<MenuCategoryCol>>((ref) {
  final repo = ref.watch(catalogRepoProvider);
  return repo.watchCategories();
});

class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: categories.when(
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final c = items[i];
            return ListTile(
              leading: CircleAvatar(child: Text('${c.id}')),
              title: Text(c.name),
              subtitle: Text('Position: ${c.position}'),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $e'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
        onPressed: () async {
          final name = await showDialog<String>(
            context: context,
            builder: (context) {
              final ctrl = TextEditingController();
              return AlertDialog(
                title: const Text('New Category'),
                content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Name')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
                ],
              );
            },
          );
          if (name != null && name.isNotEmpty) {
            await ref.read(catalogRepoProvider).addCategory(name);
          }
        },
      ),
    );
  }
}
