import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/data/models.dart';
import 'package:waah_frontend/data/repo/inventory_repo.dart';

/// Provider to load all ingredients (with qty_on_hand + min_level).
final ingredientsProvider =
FutureProvider.autoDispose<List<Ingredient>>((ref) async {
  final repo = ref.watch(inventoryRepoProvider);
  final list = await repo.loadIngredients(tenantId: '');
  // sort: low stock first
  list.sort((a, b) {
    final aLow = (a.qtyOnHand ?? 0) < a.minLevel ? 0 : 1;
    final bLow = (b.qtyOnHand ?? 0) < b.minLevel ? 0 : 1;
    final cmpLow = aLow.compareTo(bLow);
    if (cmpLow != 0) return cmpLow;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return list;
});

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncIngs = ref.watch(ingredientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            tooltip: 'Record Purchase',
            icon: const Icon(Icons.shopping_cart_checkout),
            onPressed: () async {
              final repo = ref.read(inventoryRepoProvider);
              final ingList = await repo.loadIngredients(
                tenantId: '',
              );

              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => _PurchaseDialog(ingredients: ingList),
              );

              if (ok == true) {
                ref.invalidate(ingredientsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Purchase recorded'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Ingredient'),
        onPressed: () async {
          final created = await showDialog<bool>(
            context: context,
            builder: (_) => const _AddIngredientDialog(),
          );
          if (created == true) {
            ref.invalidate(ingredientsProvider);
          }
        },
      ),
      body: asyncIngs.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (e, st) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Failed to load ingredients:\n$e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (ings) {
          if (ings.isEmpty) {
            return const Center(
              child: Text(
                'No ingredients yet.\nTap "Ingredient" to add.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.separated(
            itemCount: ings.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final ing = ings[i];
              final onHand = ing.qtyOnHand ?? 0;
              final min = ing.minLevel;
              final low = onHand < min;

              return ListTile(
                title: Text(
                  ing.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: low ? Colors.red : null,
                  ),
                ),
                subtitle: Text(
                  'On hand: ${onHand.toStringAsFixed(3)} ${ing.uom} • Min: ${min.toStringAsFixed(3)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: low ? Colors.red : Colors.grey.shade700,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit min level',
                  onPressed: () async {
                    final changed = await showDialog<bool>(
                      context: context,
                      builder: (_) => _MinLevelDialog(
                        ingredient: ing,
                      ),
                    );
                    if (changed == true) {
                      ref.invalidate(ingredientsProvider);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Add Ingredient dialog
class _AddIngredientDialog extends ConsumerStatefulWidget {
  const _AddIngredientDialog();

  @override
  ConsumerState<_AddIngredientDialog> createState() =>
      _AddIngredientDialogState();
}

class _AddIngredientDialogState
    extends ConsumerState<_AddIngredientDialog> {
  final _nameCtl = TextEditingController();
  final _uomCtl = TextEditingController();
  final _minCtl = TextEditingController(text: '0');
  bool _busy = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _uomCtl.dispose();
    _minCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    final uom = _uomCtl.text.trim();
    final minLevel =
        double.tryParse(_minCtl.text.trim()) ?? 0.0;
    if (name.isEmpty || uom.isEmpty) return;

    setState(() => _busy = true);

    try {
      final repo = ref.read(inventoryRepoProvider);
      await repo.addIngredient(
        tenantId: '',
        name: name,
        uom: uom,
        minLevel: minLevel,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add ingredient: $e'),
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
      title: const Text('New Ingredient'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtl,
            decoration: const InputDecoration(
              labelText: 'Name *',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _uomCtl,
            decoration: const InputDecoration(
              labelText: 'Unit of measure *',
              helperText: 'g, kg, ml, l, pcs...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minCtl,
            keyboardType:
            const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Minimum level',
              helperText: 'Alert if below this stock',
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

/// Edit minimum level dialog
class _MinLevelDialog extends ConsumerStatefulWidget {
  const _MinLevelDialog({required this.ingredient});
  final Ingredient ingredient;

  @override
  ConsumerState<_MinLevelDialog> createState() =>
      _MinLevelDialogState();
}

class _MinLevelDialogState
    extends ConsumerState<_MinLevelDialog> {
  late TextEditingController _minCtl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _minCtl = TextEditingController(
      text: widget.ingredient.minLevel
          .toStringAsFixed(3),
    );
  }

  @override
  void dispose() {
    _minCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed =
    double.tryParse(_minCtl.text.trim());
    if (parsed == null) return;

    setState(() => _busy = true);

    try {
      await ref
          .read(inventoryRepoProvider)
          .updateMinLevel(
        ingredientId: widget.ingredient.id!,
        minLevel: parsed,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Failed to update level: $e'),
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
      title:
      Text('Min level for ${widget.ingredient.name}'),
      content: TextField(
        controller: _minCtl,
        enabled: !_busy,
        keyboardType:
        const TextInputType.numberWithOptions(
          decimal: true,
        ),
        decoration: const InputDecoration(
          labelText: 'Minimum stock level',
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

/// Simple purchase dialog: pick ingredient, qty, and supplier.
/// For v1 we'll just support 1-line purchase.
class _PurchaseDialog extends ConsumerStatefulWidget {
  const _PurchaseDialog({required this.ingredients});
  final List<Ingredient> ingredients;

  @override
  ConsumerState<_PurchaseDialog> createState() =>
      _PurchaseDialogState();
}

class _PurchaseDialogState
    extends ConsumerState<_PurchaseDialog> {
  Ingredient? _selected;
  final _qtyCtl = TextEditingController();
  final _costCtl = TextEditingController();
  final _suppCtl = TextEditingController();
  final _noteCtl = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _qtyCtl.dispose();
    _costCtl.dispose();
    _suppCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selected == null) return;
    final qty =
        double.tryParse(_qtyCtl.text.trim()) ?? 0.0;
    final cost =
        double.tryParse(_costCtl.text.trim()) ?? 0.0;

    setState(() => _busy = true);

    try {
      final repo = ref.read(inventoryRepoProvider);
      await repo.recordPurchase(
        tenantId: '',
        supplier: _suppCtl.text.trim(),
        note: _noteCtl.text.trim().isEmpty
            ? null
            : _noteCtl.text.trim(),
        lines: [
          PurchaseLineDraft(
            ingredientId: _selected!.id!,
            qty: qty,
            unitCost: cost,
          ),
        ],
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Failed to record purchase: $e'),
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
      title:
      const Text('Record Purchase (1 line quick add)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Ingredient>(
              initialValue: _selected,
              items: widget.ingredients
                  .map(
                    (i) => DropdownMenuItem(
                  value: i,
                  child: Text(i.name),
                ),
              )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (val) {
                setState(() {
                  _selected = val;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Ingredient',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyCtl,
              enabled: !_busy,
              keyboardType:
              const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Quantity received',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _costCtl,
              enabled: !_busy,
              keyboardType:
              const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Unit cost (₹)',
              ),
            ),
            const Divider(height: 24),
            TextField(
              controller: _suppCtl,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Supplier',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtl,
              enabled: !_busy,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
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
            child:
            CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : const Text('Save'),
        ),
      ],
    );
  }
}
