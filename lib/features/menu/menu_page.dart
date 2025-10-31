import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/repo/catalog_repo.dart';
// Import the API models with an alias
import 'package:waah_frontend/data/models.dart' as api;
// Import the local DB models
import 'package:waah_frontend/data/local/app_db.dart';
// Import the sync controller
import 'package:waah_frontend/features/sync/sync_controller.dart';
import 'package:waah_frontend/features/menu/menu_item_detail_page.dart';
import 'package:waah_frontend/widgets/menu_media.dart';
import 'dart:async';

/// ---------------------------------------------------------------------------
/// PROVIDERS (Refactored for Offline-First)
/// ---------------------------------------------------------------------------

/// All categories from the local database
final menuCategoriesProvider =
StreamProvider.autoDispose<List<MenuCategory>>((ref) {
  final repo = ref.watch(catalogRepoProvider);
  // This now watches the local database
  return repo.watchCategories();
});

/// Items for a given *local* category ID
final categoryItemsProvider =
StreamProvider.family.autoDispose<List<MenuItem>, int>((ref, localCategoryId) {
  final repo = ref.watch(catalogRepoProvider);

  // Keep the stream alive for a short period after last listener detaches
  final link = ref.keepAlive();
  Timer? timer;
  ref.onCancel(() {
    timer = Timer(const Duration(seconds: 30), link.close);
  });
  ref.onResume(() {
    timer?.cancel();
  });

  return repo.watchItems(localCategoryId);
});

/// Variants for a given *local* item ID
final itemVariantsProvider = StreamProvider.family
    .autoDispose<List<ItemVariant>, int>((ref, localItemId) {
  final repo = ref.watch(catalogRepoProvider);
  if (localItemId == 0) {
    return Stream.value([]);
  }
  // This watches the local database
  return repo.watchVariants(localItemId);
});

/// ---------------------------------------------------------------------------
/// MAIN PAGE
/// ---------------------------------------------------------------------------

class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(menuCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Categories'),
        actions: [
          // Add a manual sync button
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Menu',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing...')),
              );
              await ref.read(syncControllerProvider.notifier).syncNow();
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sync complete!'), duration: Duration(seconds: 1)),
                );
              }
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog<bool>(
            context: context,
            builder: (_) => const _AddCategoryDialog(),
          );
          // No invalidation needed, dialog will trigger sync
        },
        tooltip: 'Add Category',
        child: const Icon(Icons.add),
      ),
      body: catsAsync.when(
        data: (cats) {
          if (cats.isEmpty) {
            return Center(
              child: Text(
                'No categories yet.\nTap + to add one, or tap Sync.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          // Sort local data
          cats.sort((a, b) => a.position.compareTo(b.position));

          return ListView.builder(
            itemCount: cats.length,
            itemBuilder: (context, i) {
              final cat = cats[i];
              final catId = cat.id; // Use the local int ID

              final itemsAsync = ref.watch(categoryItemsProvider(catId));

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ExpansionTile(
                  tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  childrenPadding:
                  const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  title: Text(
                    cat.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Add Item',
                        icon: const Icon(Icons.add_box_outlined),
                        onPressed: () {
                          showDialog<bool>(
                            context: context,
                            builder: (_) => _AddItemDialog(category: cat),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Edit Category',
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          showDialog<bool>(
                            context: context,
                            builder: (_) => _EditCategoryDialog(category: cat),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Delete Category',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: (cat.remoteId == null || cat.remoteId!.isEmpty)
                            ? null
                            : () async {
                          // TODO: Implement offline-first delete
                          // For now, we call the API and then sync
                          final ok = await _confirmYesNo(
                              context,
                              'Delete "${cat.name}" and all its items?');
                          if (ok != true) return;

                          try {
                            final repo = ref.read(catalogRepoProvider);
                            await repo.deleteCategory(cat.remoteId!);
                            await ref.read(syncControllerProvider.notifier).syncNow();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Could not delete "${cat.name}": $e'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  children: [
                    itemsAsync.when(
                      data: (items) {
                        // Sort local data
                        items.sort((a, b) =>
                            a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'No items under "${cat.name}". Add one with the + button.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: items.map((it) {
                            final itemId = it.id;
                            final varsAsync =
                            ref.watch(itemVariantsProvider(itemId));

                            return ListTile(
                              contentPadding:
                              const EdgeInsets.only(left: 0, right: 0),
                              leading: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: MenuImage(path: it.imageUrl ?? '', size: 56),
                              ),
                              title: Text(
                                it.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (it.description != null &&
                                      it.description!.trim().isNotEmpty)
                                    Text(
                                      it.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  varsAsync.when(
                                    data: (vars) {
                                      if (vars.isEmpty) {
                                        return Text(
                                          'No variants yet',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        );
                                      }
                                      // Sort local data
                                      vars.sort((a, b) {
                                        if (a.isDefault && !b.isDefault) return -1;
                                        if (!a.isDefault && b.isDefault) return 1;
                                        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
                                      });

                                      final def = vars.firstWhere(
                                            (v) => v.isDefault,
                                        orElse: () => vars.first,
                                      );
                                      return Text(
                                        _variantSummary(def),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade800,
                                        ),
                                      );
                                    },
                                    loading: () => Text(
                                      'Loading price…',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    error: (e, st) => Text(
                                      'Variant load failed: $e',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Variants / Prices',
                                    icon: const Icon(Icons.price_change),
                                    onPressed: it.remoteId == null
                                        ? null
                                        : () {
                                      showModalBottomSheet<bool>(
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (_) =>
                                            _ManageVariantsSheet(
                                              localItemId: it.id,
                                              remoteItemId: it.remoteId!,
                                              itemName: it.name,
                                            ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Delete Item',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: it.remoteId == null
                                        ? null
                                        : () async {
                                      final ok = await _confirmYesNo(
                                        context,
                                        'Delete "${it.name}"?',
                                      );
                                      if (ok != true) return;

                                      try {
                                        final repo =
                                        ref.read(catalogRepoProvider);
                                        await repo.deleteItem(it.remoteId!);
                                        await ref.read(localDatabaseProvider).deleteMenuItemByRemoteId(it.remoteId!);
                                        await ref.read(syncControllerProvider.notifier).syncNow();
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Could not delete "${it.name}": $e'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                // Navigate to detail page, passing the local DB object
                                Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => MenuItemDetailPage(item: it),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, st) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Failed to load items: $e',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Failed to load categories:\n$e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}

/// small helper confirm dialog
Future<bool?> _confirmYesNo(BuildContext context, String msg) {
  return showDialog<bool>(
    context: context,
    builder: (dialogCtx) {
      return AlertDialog(
        title: const Text('Are you sure?'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
}

// Updated to use the local DB model
String _variantSummary(ItemVariant v) {
  final price = v.basePrice.toStringAsFixed(2);
  final lbl = v.label.isEmpty ? 'Default' : v.label;
  return v.isDefault ? '$lbl • ₹$price (default)' : '$lbl • ₹$price';
}

/// ---------------------------------------------------------------------------
/// ADD CATEGORY DIALOG
/// ---------------------------------------------------------------------------

class _AddCategoryDialog extends ConsumerStatefulWidget {
  const _AddCategoryDialog();

  @override
  ConsumerState<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<_AddCategoryDialog> {
  final _nameCtl = TextEditingController();
  final _posCtl = TextEditingController(text: '0');
  bool _busy = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _posCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    final pos = int.tryParse(_posCtl.text.trim()) ?? 0;
    if (name.isEmpty) return;

    final me = ref.read(authControllerProvider).me;
    final tenantId = me?.tenantId ?? '';
    final branchId = ref.read(activeBranchIdProvider);

    if (tenantId.isEmpty || branchId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a branch first')),
        );
      }
      return;
    }

    setState(() => _busy = true);

    try {
      final repo = ref.read(catalogRepoProvider);
      // We still call the API for writes.
      // TODO: Change this to write to OpsJournal for offline
      await repo.addCategory(
        name,
        tenantId: tenantId,
        branchId: branchId,
        position: pos,
      );

      // Manually trigger a sync to pull the new data
      await ref.read(syncControllerProvider.notifier).syncNow();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add category: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtl,
            decoration: const InputDecoration(labelText: 'Category name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _posCtl,
            keyboardType: const TextInputType.numberWithOptions(
              signed: false,
              decimal: false,
            ),
            decoration:
            const InputDecoration(labelText: 'Display position (0,1,2...)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _EditCategoryDialog extends ConsumerStatefulWidget {
  const _EditCategoryDialog({required this.category});
  final MenuCategory category; // Now a db.MenuCategory

  @override
  ConsumerState<_EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends ConsumerState<_EditCategoryDialog> {
  late TextEditingController _nameCtl;
  late TextEditingController _posCtl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.category.name);
    _posCtl = TextEditingController(text: widget.category.position.toString());
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _posCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    final pos = int.tryParse(_posCtl.text.trim()) ?? 0;
    if (name.isEmpty) return;

    if (widget.category.remoteId == null || widget.category.remoteId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This category hasn’t synced yet. Tap Sync, then try edit.'))
        );
      }
      return;
    }

    setState(() => _busy = true);

    try {
      final repo = ref.read(catalogRepoProvider);
      // We still call the API for writes
      // TODO: Change this to write to OpsJournal for offline
      await repo.updateCategory(
        widget.category.remoteId!,
        api.MenuCategory(
          // We build the API model for the update
          id: widget.category.remoteId,
          tenantId: ref.read(activeTenantIdProvider),
          branchId: ref.read(activeBranchIdProvider),
          name: name,
          position: pos,
        ),
      );

      // Manually trigger a sync to pull the new data
      await ref.read(syncControllerProvider.notifier).syncNow();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update category: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtl,
            decoration: const InputDecoration(labelText: 'Category name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _posCtl,
            keyboardType: const TextInputType.numberWithOptions(
              signed: false,
              decimal: false,
            ),
            decoration: const InputDecoration(labelText: 'Display position'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// ADD ITEM DIALOG
/// ---------------------------------------------------------------------------

class _AddItemDialog extends ConsumerStatefulWidget {
  const _AddItemDialog({required this.category});
  final MenuCategory category; // Now a db.MenuCategory

  @override
  ConsumerState<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends ConsumerState<_AddItemDialog> {
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _gstCtl = TextEditingController(text: '5.0');
  final _variantLabelCtl = TextEditingController(text: 'Regular');
  final _priceCtl = TextEditingController();
  PlatformFile? _pickedFile;
  Uint8List? _previewBytes;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    _gstCtl.dispose();
    _variantLabelCtl.dispose();
    _priceCtl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted) return;
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _pickedFile = file;
        _previewBytes = file.bytes;
      });
    }
  }

  void _clearImage() {
    setState(() {
      _pickedFile = null;
      _previewBytes = null;
    });
  }

  Future<void> _save() async {
    final repo = ref.read(catalogRepoProvider);
    final name = _nameCtl.text.trim();
    if (name.isEmpty) return;

    final desc = _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim();
    final gstRate = double.tryParse(_gstCtl.text.trim()) ?? 5.0;
    final variantLabel = _variantLabelCtl.text.trim();
    final priceVal = double.tryParse(_priceCtl.text.trim()) ?? 0.0;

    final me = ref.read(authControllerProvider).me;
    final tenantId = me?.tenantId ?? '';

    setState(() => _busy = true);

    try {
      // 1) Create item on server
      final catRid = widget.category.remoteId ?? '';
      if (catRid.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please Sync first — this category isn’t linked to the server yet.')),
          );
        }
        setState(() => _busy = false);
        return;
      }

      final newItem = api.MenuItem(
        id: null,
        tenantId: tenantId,
        categoryId: catRid,
        name: name,
        description: desc,
        isActive: true,
        gstRate: gstRate,
      );

      final createdItem = await repo.createItem(newItem);
      final newItemRemoteId = createdItem.id ?? '';

      // 1.5) Pull it so the local row exists before any local-only updates
      await ref.read(syncControllerProvider.notifier).syncNow();

      // 2) Create default variant (server; local comes via sync)
      final newVar = api.ItemVariant(
        id: null,
        itemId: newItemRemoteId,
        label: variantLabel,
        mrp: priceVal,
        basePrice: priceVal,
        isDefault: true,
      );
      await repo.createVariant(newItemRemoteId, newVar);

      // 3) Upload image (repo will update-only locally)
      if (_pickedFile != null) {
        await repo.uploadItemImage(
          itemId: newItemRemoteId,
          file: _pickedFile!,
        );
      }

      // 4) Final sync so UI reflects variant + image
      await ref.read(syncControllerProvider.notifier).syncNow();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" added under ${widget.category.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add item: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('New Item in ${widget.category.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtl,
              decoration: const InputDecoration(labelText: 'Item name *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gstCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'GST %',
                helperText: 'ex: 5.0',
              ),
            ),
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Item Photo (optional)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.brown.shade700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade100,
                  ),
                  child: _previewBytes != null
                      ? Image.memory(
                    _previewBytes!,
                    fit: BoxFit.cover,
                  )
                      : const Icon(
                    Icons.image,
                    size: 32,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _pickImage,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Choose Image'),
                      ),
                      if (_pickedFile != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _pickedFile!.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        TextButton.icon(
                          onPressed: _busy ? null : _clearImage,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Remove'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Default Variant / Price',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.brown.shade700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _variantLabelCtl,
              decoration: const InputDecoration(
                labelText: 'Variant label',
                helperText: 'e.g. Regular / Large / Plate',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration:
              const InputDecoration(labelText: 'Base price (₹) *'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// MANAGE VARIANTS SHEET
/// ---------------------------------------------------------------------------

class _ManageVariantsSheet extends ConsumerStatefulWidget {
  const _ManageVariantsSheet({
    required this.localItemId,
    required this.remoteItemId,
    required this.itemName,
  });

  final int localItemId;
  final String remoteItemId;
  final String itemName;

  @override
  ConsumerState<_ManageVariantsSheet> createState() =>
      _ManageVariantsSheetState();
}

class _ManageVariantsSheetState
    extends ConsumerState<_ManageVariantsSheet> {
  final _labelCtl = TextEditingController();
  final _priceCtl = TextEditingController();
  final _mrpCtl = TextEditingController();
  bool _isDefault = false;
  bool _saving = false;

  @override
  void dispose() {
    _labelCtl.dispose();
    _priceCtl.dispose();
    _mrpCtl.dispose();
    super.dispose();
  }

  Future<void> _addVariant() async {
    final label = _labelCtl.text.trim();
    final price = double.tryParse(_priceCtl.text.trim()) ?? 0.0;
    final mrp = double.tryParse(_mrpCtl.text.trim());

    setState(() => _saving = true);

    try {
      final repo = ref.read(catalogRepoProvider);

      // Create using the API model
      final newVar = api.ItemVariant(
        id: null,
        itemId: widget.remoteItemId,
        label: label,
        mrp: mrp ?? price,
        basePrice: price,
        isDefault: _isDefault,
      );

      await repo.createVariant(widget.remoteItemId, newVar);

      // Trigger sync to pull changes
      await ref.read(syncControllerProvider.notifier).syncNow();

      // clear form
      _labelCtl.clear();
      _priceCtl.clear();
      _mrpCtl.clear();
      _isDefault = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Variant added to ${widget.itemName}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add variant: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editVariantDialog(ItemVariant v) async {
    final lblCtl = TextEditingController(text: v.label);
    final priceCtl =
    TextEditingController(text: v.basePrice.toStringAsFixed(2));
    final mrpCtl = TextEditingController(text: v.mrp?.toStringAsFixed(2) ?? '');
    bool isDef = v.isDefault;
    bool savingLocal = false;

    final changed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            Future<void> save() async {
              setSt(() => savingLocal = true);
              try {
                final repo = ref.read(catalogRepoProvider);

                final parsedPrice =
                    double.tryParse(priceCtl.text.trim()) ?? 0.0;
                final parsedMrp = double.tryParse(mrpCtl.text.trim());

                // Build API model for update
                final updated = api.ItemVariant(
                  id: v.remoteId, // Use remote ID
                  itemId: widget.remoteItemId,
                  label: lblCtl.text.trim(),
                  mrp: parsedMrp ?? parsedPrice,
                  basePrice: parsedPrice,
                  isDefault: isDef,
                );

                await repo.updateVariant(updated);

                // Trigger sync
                await ref.read(syncControllerProvider.notifier).syncNow();

                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Update failed: $e')),
                  );
                }
              } finally {
                if (ctx.mounted) setSt(() => savingLocal = false);
              }
            }

            return AlertDialog(
              title: Text('Edit "${v.label}"'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: lblCtl,
                      decoration:
                      const InputDecoration(labelText: 'Variant label'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtl,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                      const InputDecoration(labelText: 'Base price (₹)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mrpCtl,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                      const InputDecoration(labelText: 'MRP (optional)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: isDef,
                          onChanged: (val) {
                            setSt(() {
                              isDef = val ?? false;
                            });
                          },
                        ),
                        const Text('Default variant'),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                  savingLocal ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: savingLocal ? null : save,
                  child: savingLocal
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (changed == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Variant updated')));
    }
  }

  Future<void> _deleteVariant(ItemVariant v) async {
    if (v.remoteId == null) return;
    final ok = await _confirmYesNo(context, 'Delete variant "${v.label}"?');
    if (ok != true) return;

    try {
      await ref.read(catalogRepoProvider).deleteVariant(v.remoteId!);
      // Trigger sync
      await ref.read(syncControllerProvider.notifier).syncNow();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${v.label}')),
        );
      }
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $err')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the local item ID to watch variants
    final varsAsync = ref.watch(itemVariantsProvider(widget.localItemId));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Variants for "${widget.itemName}"',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // existing variants list
              varsAsync.when(
                data: (vars) {
                  // Sort local data
                  vars.sort((a, b) {
                    if (a.isDefault && !b.isDefault) return -1;
                    if (!a.isDefault && b.isDefault) return 1;
                    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
                  });

                  if (vars.isEmpty) {
                    return Text(
                      'No variants yet.',
                      style: TextStyle(color: Colors.grey.shade600),
                    );
                  }
                  return Column(
                    children: vars.map((v) {
                      final price = v.basePrice.toStringAsFixed(2);
                      final mrp = v.mrp?.toStringAsFixed(2);
                      final txt = v.isDefault
                          ? '₹$price (default)'
                          : '₹$price${mrp != null ? ' MRP ₹$mrp' : ''}';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          v.label.isEmpty ? '(no label)' : v.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(txt),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Edit',
                              onPressed: () => _editVariantDialog(v),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () => _deleteVariant(v),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, st) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Failed to load variants: $e',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),

              const Divider(height: 32),

              Text(
                'Add new variant',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.brown.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _labelCtl,
                decoration: const InputDecoration(
                  labelText: 'Variant label',
                  helperText: 'e.g. Regular / Large / Half Plate',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceCtl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Base price (₹)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mrpCtl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'MRP (optional)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _isDefault,
                    onChanged: (val) {
                      setState(() {
                        _isDefault = val ?? false;
                      });
                    },
                  ),
                  const Text('Default variant'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context, true),
                      child: const Text('Done'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _addVariant,
                      child: _saving
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Add'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}