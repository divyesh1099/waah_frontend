import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/data/models.dart';
import 'package:waah_frontend/data/repo/catalog_repo.dart';

class MenuItemDetailPage extends ConsumerStatefulWidget {
  const MenuItemDetailPage({
    super.key,
    required this.item,
  });

  final MenuItem item;

  @override
  ConsumerState<MenuItemDetailPage> createState() => _MenuItemDetailPageState();
}

class _MenuItemDetailPageState extends ConsumerState<MenuItemDetailPage> {
  late TextEditingController _gstCtl;
  late bool _taxInclusive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _gstCtl = TextEditingController(
      text: widget.item.gstRate.toStringAsFixed(2),
    );
    _taxInclusive = widget.item.taxInclusive;
  }

  @override
  void dispose() {
    _gstCtl.dispose();
    super.dispose();
  }

  Future<void> _saveTax() async {
    if (_saving) return;
    final id = widget.item.id;
    if (id == null) return;

    final parsed = double.tryParse(_gstCtl.text.trim());
    if (parsed == null) {
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
      await ref.read(catalogRepoProvider).updateItemTax(
        id,
        gstRate: parsed,
        taxInclusive: _taxInclusive,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved ✅')),
        );
        // pop back, signal change = true so list can refresh
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
          SnackBar(content: Text('Deleted ${widget.item.name}')),
        );
        // pop back, signal change so parent can refresh
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
          // Basic info preview
          Text(
            it.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          if (it.description != null && it.description!.trim().isNotEmpty)
            Text(
              it.description!.trim(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: 8),
          Text(
            it.stockOut ? 'OUT OF STOCK' : 'In stock',
            style: TextStyle(
              color: it.stockOut ? Colors.red : Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Tax Inclusive toggle
          SwitchListTile.adaptive(
            title: const Text('Tax inclusive price'),
            subtitle:
            const Text('If ON, your menu price is GST-inclusive'),
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
            keyboardType: TextInputType.numberWithOptions(
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
            label: Text(_saving ? 'Saving...' : 'Save Tax'),
            onPressed: _saving ? null : _saveTax,
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
