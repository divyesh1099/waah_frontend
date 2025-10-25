import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/data/models.dart';
import 'package:waah_frontend/data/repo/catalog_repo.dart';

extension MenuItemCopy on MenuItem {
  MenuItem copyWith({
    String? name,
    String? description,
    bool? isActive,
    bool? stockOut,
    bool? taxInclusive,
    double? gstRate,
  }) {
    return MenuItem(
      id: id,
      tenantId: tenantId,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId,
      sku: sku,
      hsn: hsn,
      isActive: isActive ?? this.isActive,
      stockOut: stockOut ?? this.stockOut,
      taxInclusive: taxInclusive ?? this.taxInclusive,
      gstRate: gstRate ?? this.gstRate,
      kitchenStationId: kitchenStationId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class MenuItemDetailPage extends ConsumerStatefulWidget {
  const MenuItemDetailPage({
    super.key,
    required this.item,
  });

  final MenuItem item;

  @override
  ConsumerState<MenuItemDetailPage> createState() =>
      _MenuItemDetailPageState();
}

class _MenuItemDetailPageState
    extends ConsumerState<MenuItemDetailPage> {
  late TextEditingController _nameCtl;
  late TextEditingController _descCtl;
  late TextEditingController _gstCtl;

  late bool _isActive;
  late bool _stockOut;
  late bool _taxInclusive;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameCtl = TextEditingController(text: widget.item.name);
    _descCtl =
        TextEditingController(text: widget.item.description ?? '');
    _gstCtl = TextEditingController(
      text: widget.item.gstRate.toStringAsFixed(2),
    );

    _isActive = widget.item.isActive;
    _stockOut = widget.item.stockOut;
    _taxInclusive = widget.item.taxInclusive;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    _gstCtl.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (_saving) return;
    final id = widget.item.id;
    if (id == null) return;

    final gstParsed = double.tryParse(_gstCtl.text.trim());
    if (gstParsed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid GST rate')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final repo = ref.read(catalogRepoProvider);

      final updatedDraft = widget.item.copyWith(
        name: _nameCtl.text.trim(),
        description: _descCtl.text.trim().isEmpty
            ? null
            : _descCtl.text.trim(),
        isActive: _isActive,
        stockOut: _stockOut,
        taxInclusive: _taxInclusive,
        gstRate: gstParsed,
      );

      // IMPORTANT: pass id + draft, to match CatalogRepo.updateItem(String id, MenuItem data)
      await repo.updateItem(id, updatedDraft);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved ✅')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $err')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _deleteItem() async {
    final id = widget.item.id;
    if (id == null) return;

    final ok = await _confirm(
      context,
      'Delete "${widget.item.name}"?\n(Soft delete, hides in POS)',
    );
    if (!ok) return;

    setState(() {
      _saving = true;
    });

    try {
      await ref.read(catalogRepoProvider).deleteItem(id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${widget.item.name}'),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $err')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(it.name),
        actions: [
          IconButton(
            tooltip: 'Delete item',
            icon: const Icon(Icons.delete_outline),
            onPressed: _saving ? null : _deleteItem,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Item name
          TextField(
            controller: _nameCtl,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Item name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          TextField(
            controller: _descCtl,
            enabled: !_saving,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Active / Stock Out toggles
          SwitchListTile.adaptive(
            title: const Text('Active in menu'),
            subtitle:
            const Text('If OFF, POS should hide this item'),
            value: _isActive,
            onChanged: _saving
                ? null
                : (val) {
              setState(() {
                _isActive = val;
                // If inactive -> force stockOut true for clarity
                if (!_isActive) _stockOut = true;
              });
            },
          ),
          SwitchListTile.adaptive(
            title: const Text('Out of stock'),
            subtitle: const Text(
              'If ON, POS should block ordering',
            ),
            value: _stockOut,
            onChanged: _saving
                ? null
                : (val) {
              setState(() {
                _stockOut = val;
                // If NOT out of stock -> force active true
                if (!_stockOut) _isActive = true;
              });
            },
          ),
          const Divider(height: 32),

          // Tax Inclusive toggle
          SwitchListTile.adaptive(
            title: const Text('Tax inclusive price'),
            subtitle: const Text(
                'If ON, menu price is GST-inclusive'),
            value: _taxInclusive,
            onChanged: _saving
                ? null
                : (val) {
              setState(() {
                _taxInclusive = val;
              });
            },
          ),
          const SizedBox(height: 12),

          // GST rate field
          TextField(
            controller: _gstCtl,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: false,
            ),
            decoration: const InputDecoration(
              labelText: 'GST %',
              hintText: 'e.g. 5.0',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            icon: _saving
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save Item'),
            onPressed: _saving ? null : _saveItem,
          ),
        ],
      ),
    );
  }
}

/// local confirm helper
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
