import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/repo/catalog_repo.dart';
import 'package:waah_frontend/data/models.dart';

/// ---------------------------------------------------------------------------
/// PROVIDERS
/// ---------------------------------------------------------------------------

/// All categories for tenant/branch (right now we send "")
final menuCategoriesProvider =
FutureProvider<List<MenuCategory>>((ref) async {
  final repo = ref.watch(catalogRepoProvider);
  final cats =
  await repo.loadCategories(tenantId: '', branchId: '');
  cats.sort((a, b) => a.position.compareTo(b.position));
  return cats;
});

/// Items for a given category
final categoryItemsProvider = FutureProvider.family<
    List<MenuItem>,
    String>((ref, categoryId) async {
  final repo = ref.watch(catalogRepoProvider);
  final items = await repo.loadItems(
    categoryId: categoryId,
    tenantId: '',
  );
  items.sort((a, b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return items;
});

/// Variants for a given item (used to show/manage prices)
final itemVariantsProvider = FutureProvider.family<
    List<ItemVariant>,
    String>((ref, itemId) async {
  final repo = ref.watch(catalogRepoProvider);
  final vars = await repo.loadVariants(itemId);
  vars.sort((a, b) {
    // default first, then label
    if (a.isDefault && !b.isDefault) return -1;
    if (!a.isDefault && b.isDefault) return 1;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });
  return vars;
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
          IconButton(
            tooltip: 'Add Category',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final saved = await showDialog<bool>(
                context: context,
                builder: (_) => const _AddCategoryDialog(),
              );
              if (saved == true) {
                ref.invalidate(menuCategoriesProvider);
              }
            },
          ),
        ],
      ),
      body: catsAsync.when(
        data: (cats) {
          if (cats.isEmpty) {
            return const Center(
              child: Text(
                'No categories yet.\nTap + to add one.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: cats.length,
            itemBuilder: (context, i) {
              final cat = cats[i];
              final catId = cat.id ?? '';

              final itemsAsync =
              ref.watch(categoryItemsProvider(catId));

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  childrenPadding: const EdgeInsets.only(
                      left: 16, right: 16, bottom: 12),
                  title: Text(
                    cat.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Position ${cat.position}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Add Item',
                        icon: const Icon(Icons.add_box_outlined),
                        onPressed: () async {
                          final created = await showDialog<bool>(
                            context: context,
                            builder: (_) => _AddItemDialog(category: cat),
                          );
                          if (created == true) {
                            ref.invalidate(categoryItemsProvider(catId));
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Edit Category',
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final updated = await showDialog<bool>(
                            context: context,
                            builder: (_) => _EditCategoryDialog(category: cat),
                          );
                          if (updated == true) {
                            ref.invalidate(menuCategoriesProvider);
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Delete Category',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: cat.id == null
                            ? null
                            : () async {
                          final ok = await _confirmYesNo(
                              context,
                              'Delete "${cat.name}" and all its items?');
                          if (ok != true) return;

                          try {
                            final repo = ref.read(catalogRepoProvider);
                            await repo.deleteCategory(cat.id!);
                            ref.invalidate(menuCategoriesProvider);
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
                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8.0),
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
                            final itemId = it.id ?? '';
                            final varsAsync = ref.watch(
                              itemVariantsProvider(itemId),
                            );

                            return ListTile(
                              contentPadding:
                              const EdgeInsets.only(left: 0, right: 0),
                              title: Text(
                                it.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  if (it.description != null &&
                                      it.description!
                                          .trim()
                                          .isNotEmpty)
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
                                            color:
                                            Colors.grey.shade600,
                                          ),
                                        );
                                      }
                                      final def = vars.firstWhere(
                                            (v) => v.isDefault,
                                        orElse: () => vars.first,
                                      );
                                      return Text(
                                        _variantSummary(def),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                          Colors.grey.shade800,
                                        ),
                                      );
                                    },
                                    loading: () => Text(
                                      'Loading price…',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors
                                            .grey.shade600,
                                      ),
                                    ),
                                    error: (e, st) => Text(
                                      'Variant load failed: $e',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                        Colors.red.shade700,
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
                                    icon: const Icon(
                                        Icons.price_change),
                                    onPressed: it.id == null
                                        ? null
                                        : () async {
                                      final updated =
                                      await showModalBottomSheet<
                                          bool>(
                                        context: context,
                                        isScrollControlled:
                                        true,
                                        builder: (_) =>
                                            _ManageVariantsSheet(
                                              itemId: it.id!,
                                              itemName:
                                              it.name,
                                            ),
                                      );
                                      if (updated ==
                                          true) {
                                        ref.invalidate(
                                          itemVariantsProvider(
                                              it.id!),
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Delete Item',
                                    icon: const Icon(
                                        Icons.delete_outline),
                                    onPressed: it.id == null
                                        ? null
                                        : () async {
                                      final ok =
                                      await _confirmYesNo(
                                        context,
                                        'Delete "${it.name}"?',
                                      );
                                      if (ok != true)
                                        return;

                                      try {
                                        final repo = ref.read(
                                            catalogRepoProvider);
                                        await repo
                                            .deleteItem(
                                            it.id!);

                                        ref.invalidate(
                                          categoryItemsProvider(
                                              catId),
                                        );
                                      } catch (e) {
                                        if (context
                                            .mounted) {
                                          ScaffoldMessenger.of(
                                              context)
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
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
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
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
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
            // POP THE DIALOG, not the page
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

/// nice variant summary like "Regular • ₹120.00 (default)"
String _variantSummary(ItemVariant v) {
  final price = v.basePrice.toStringAsFixed(2);
  final lbl = v.label.isEmpty ? 'Default' : v.label;
  if (v.isDefault) {
    return '$lbl • ₹$price (default)';
  }
  return '$lbl • ₹$price';
}

/// ---------------------------------------------------------------------------
/// ADD CATEGORY DIALOG
/// ---------------------------------------------------------------------------

class _AddCategoryDialog extends ConsumerStatefulWidget {
  const _AddCategoryDialog();

  @override
  ConsumerState<_AddCategoryDialog> createState() =>
      _AddCategoryDialogState();
}

class _AddCategoryDialogState
    extends ConsumerState<_AddCategoryDialog> {
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

    setState(() => _busy = true);

    try {
      final repo = ref.read(catalogRepoProvider);
      await repo.addCategory(
        name,
        tenantId: '',
        branchId: '',
        position: pos,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add category: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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
            decoration: const InputDecoration(
              labelText: 'Category name',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _posCtl,
            keyboardType:
            const TextInputType.numberWithOptions(
                signed: false, decimal: false),
            decoration: const InputDecoration(
              labelText: 'Display position (0,1,2...)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : const Text('Save'),
        ),
      ],
    );
  }
}
class _EditCategoryDialog extends ConsumerStatefulWidget {
  const _EditCategoryDialog({required this.category});
  final MenuCategory category;

  @override
  ConsumerState<_EditCategoryDialog> createState() =>
      _EditCategoryDialogState();
}

class _EditCategoryDialogState
    extends ConsumerState<_EditCategoryDialog> {
  late TextEditingController _nameCtl;
  late TextEditingController _posCtl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.category.name);
    _posCtl = TextEditingController(
      text: widget.category.position.toString(),
    );
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

    setState(() => _busy = true);

    try {
      final repo = ref.read(catalogRepoProvider);
      await repo.editCategory(
        widget.category.id!,
        name: name,
        position: pos,
        tenantId: widget.category.tenantId,
        branchId: widget.category.branchId,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update category: $e'),
          ),
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
            decoration: const InputDecoration(
              labelText: 'Category name',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _posCtl,
            keyboardType: const TextInputType.numberWithOptions(
              signed: false,
              decimal: false,
            ),
            decoration: const InputDecoration(
              labelText: 'Display position',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed:
          _busy ? null : () => Navigator.pop(context, false),
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
/// Creates MenuItem AND its first/default Variant (with price).
/// ---------------------------------------------------------------------------

class _AddItemDialog extends ConsumerStatefulWidget {
  const _AddItemDialog({required this.category});
  final MenuCategory category;

  @override
  ConsumerState<_AddItemDialog> createState() =>
      _AddItemDialogState();
}

class _AddItemDialogState
    extends ConsumerState<_AddItemDialog> {
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _gstCtl = TextEditingController(text: '5.0');

  // default variant info
  final _variantLabelCtl =
  TextEditingController(text: 'Regular');
  final _priceCtl = TextEditingController();

  // future enhancement: image URL (not wired to backend yet)
  final _imageCtl = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    _gstCtl.dispose();
    _variantLabelCtl.dispose();
    _priceCtl.dispose();
    _imageCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(catalogRepoProvider);

    final name = _nameCtl.text.trim();
    if (name.isEmpty) return;

    final desc =
    _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim();

    final gstRate =
        double.tryParse(_gstCtl.text.trim()) ?? 5.0;

    final variantLabel =
    _variantLabelCtl.text.trim();
    final priceVal =
        double.tryParse(_priceCtl.text.trim()) ?? 0.0;

    // NOTE: _imageCtl.text is ignored for now because backend
    // doesn't expose an image field on MenuItem yet.
    // We'll store/use it later once backend supports item images.

    setState(() => _busy = true);

    try {
      // 1. create the menu item
      final newItem = MenuItem(
        id: null,
        tenantId: '',
        name: name,
        description: desc,
        categoryId: widget.category.id ?? '',
        sku: null,
        hsn: null,
        isActive: true,
        stockOut: false,
        taxInclusive: true,
        gstRate: gstRate,
        kitchenStationId: null,
        createdAt: null,
        updatedAt: null,
      );

      final createdItem = await repo.createItem(newItem);
      final newItemId = createdItem.id ?? '';

      // 2. create the default variant with a price
      final newVar = ItemVariant(
        id: null,
        itemId: newItemId,
        label: variantLabel,
        mrp: priceVal,
        basePrice: priceVal,
        isDefault: true,
      );

      await repo.createVariant(newItemId, newVar);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${createdItem.name}" added under ${widget.category.name}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('New Item in ${widget.category.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtl,
              decoration: const InputDecoration(
                labelText: 'Item name *',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtl,
              decoration: const InputDecoration(
                labelText: 'Description',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gstCtl,
              keyboardType:
              const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'GST %',
                helperText: 'ex: 5.0',
              ),
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
              const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Base price (₹) *',
              ),
            ),
            const Divider(height: 24),
            TextField(
              controller: _imageCtl,
              decoration: const InputDecoration(
                labelText: 'Image URL (optional)',
                helperText:
                'Not sent to backend yet, placeholder for future.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
          _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// MANAGE VARIANTS SHEET
/// Lets you view all variants of an item and add a new one.
/// ---------------------------------------------------------------------------

class _ManageVariantsSheet extends ConsumerStatefulWidget {
  const _ManageVariantsSheet({
    required this.itemId,
    required this.itemName,
  });

  final String itemId;
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

      final newVar = ItemVariant(
        id: null,
        itemId: widget.itemId,
        label: label,
        mrp: mrp ?? price,
        basePrice: price,
        isDefault: _isDefault,
      );

      await repo.createVariant(widget.itemId, newVar);

      // clear form
      _labelCtl.clear();
      _priceCtl.clear();
      _mrpCtl.clear();
      _isDefault = false;

      // refresh list
      ref.invalidate(itemVariantsProvider(widget.itemId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Variant added to ${widget.itemName}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add variant: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _editVariantDialog(ItemVariant v) async {
    final lblCtl = TextEditingController(text: v.label);
    final priceCtl =
    TextEditingController(text: v.basePrice.toStringAsFixed(2));
    final mrpCtl = TextEditingController(
      text: v.mrp?.toStringAsFixed(2) ?? '',
    );
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

                final updated = ItemVariant(
                  id: v.id,
                  itemId: v.itemId,
                  label: lblCtl.text.trim(),
                  mrp: parsedMrp ?? parsedPrice,
                  basePrice: parsedPrice,
                  isDefault: isDef,
                );

                await repo.updateVariant(updated);

                // refresh main list
                ref.invalidate(
                  itemVariantsProvider(widget.itemId),
                );

                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Update failed: $e'),
                    ),
                  );
                }
              } finally {
                if (ctx.mounted) {
                  setSt(() => savingLocal = false);
                }
              }
            }

            return AlertDialog(
              title: Text('Edit "${v.label}"'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: lblCtl,
                      decoration: const InputDecoration(
                        labelText: 'Variant label',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtl,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Base price (₹)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mrpCtl,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'MRP (optional)',
                      ),
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
                  onPressed: savingLocal
                      ? null
                      : () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: savingLocal ? null : save,
                  child: savingLocal
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Variant updated')),
      );
    }
  }

  Future<void> _deleteVariant(ItemVariant v) async {
    final ok = await _confirmYesNo(
      context,
      'Delete variant "${v.label}"?',
    );
    if (ok != true) return;

    try {
      await ref.read(catalogRepoProvider).deleteVariant(v.id!);
      ref.invalidate(itemVariantsProvider(widget.itemId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${v.label}'),
          ),
        );
      }
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $err'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final varsAsync =
    ref.watch(itemVariantsProvider(widget.itemId));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom:
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Variants for "${widget.itemName}"',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // existing variants list
              varsAsync.when(
                data: (vars) {
                  if (vars.isEmpty) {
                    return Text(
                      'No variants yet.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    );
                  }
                  return Column(
                    children: vars.map((v) {
                      final price =
                      v.basePrice.toStringAsFixed(2);
                      final mrp =
                      v.mrp?.toStringAsFixed(2);
                      final txt = v.isDefault
                          ? '₹$price (default)'
                          : '₹$price${mrp != null ? ' MRP ₹$mrp' : ''}';
                      return ListTile(
                        dense: true,
                        contentPadding:
                        EdgeInsets.zero,
                        title: Text(
                          v.label.isEmpty
                              ? '(no label)'
                              : v.label,
                          style: const TextStyle(
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(txt),
                        trailing: Row(
                          mainAxisSize:
                          MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                  Icons.edit),
                              tooltip: 'Edit',
                              onPressed: () =>
                                  _editVariantDialog(
                                      v),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons
                                    .delete_outline,
                                color:
                                Colors.red,
                              ),
                              tooltip: 'Delete',
                              onPressed: () =>
                                  _deleteVariant(v),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Padding(
                  padding:
                  EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child:
                    CircularProgressIndicator(),
                  ),
                ),
                error: (e, st) => Padding(
                  padding:
                  const EdgeInsets.symmetric(
                      vertical: 8),
                  child: Text(
                    'Failed to load variants: $e',
                    style: const TextStyle(
                      color: Colors.red,
                    ),
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
                  helperText:
                  'e.g. Regular / Large / Half Plate',
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _priceCtl,
                keyboardType:
                const TextInputType
                    .numberWithOptions(
                  decimal: true,
                ),
                decoration:
                const InputDecoration(
                  labelText: 'Base price (₹)',
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _mrpCtl,
                keyboardType:
                const TextInputType
                    .numberWithOptions(
                  decimal: true,
                ),
                decoration:
                const InputDecoration(
                  labelText: 'MRP (optional)',
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Checkbox(
                    value: _isDefault,
                    onChanged: (val) {
                      setState(() {
                        _isDefault =
                            val ?? false;
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
                      onPressed: _saving
                          ? null
                          : () {
                        Navigator.pop(
                            context,
                            true);
                      },
                      child: const Text('Done'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                      _saving ? null : _addVariant,
                      child: _saving
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
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
