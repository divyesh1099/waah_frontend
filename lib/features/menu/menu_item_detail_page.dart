import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/app/providers.dart';
// Import the API models with an alias
import 'package:waah_frontend/data/models.dart' as api;
// Import the local DB models
import 'package:waah_frontend/data/local/app_db.dart' as db;
import 'package:waah_frontend/data/repo/catalog_repo.dart';
import 'package:waah_frontend/features/sync/sync_controller.dart';
import 'package:waah_frontend/widgets/menu_media.dart';

// Common GST presets
const List<double> _kGstPresets = [0, 5, 12, 18, 28];

// This extension is no longer needed, we will build the API model manually

class MenuItemDetailPage extends ConsumerStatefulWidget {
  const MenuItemDetailPage({super.key, required this.item});
  // This is now the local database model
  final db.MenuItem item;

  @override
  ConsumerState<MenuItemDetailPage> createState() => _MenuItemDetailPageState();
}

class _MenuItemDetailPageState extends ConsumerState<MenuItemDetailPage> {
  late TextEditingController _nameCtl;
  late TextEditingController _descCtl;
  late TextEditingController _gstCtl;

  late bool _isActive;
  late bool _stockOut;
  late bool _taxInclusive;

  String? _imageUrl;
  double? _gstPresetValue; // null => Custom

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers from the local db.MenuItem
    _nameCtl = TextEditingController(text: widget.item.name);
    _descCtl = TextEditingController(text: widget.item.description ?? '');
    _gstCtl = TextEditingController(text: widget.item.gstRate.toStringAsFixed(2));

    _isActive = widget.item.isActive;
    _stockOut = widget.item.stockOut;
    _taxInclusive = widget.item.taxInclusive;
    _imageUrl = widget.item.imageUrl;

    final currentGst = widget.item.gstRate;
    _gstPresetValue = _kGstPresets.contains(currentGst) ? currentGst : null;
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
    // We need the remoteId to update the item
    final remoteId = widget.item.remoteId;
    if (remoteId == null || remoteId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This item hasn’t synced yet. Tap Sync, then try again.'))
        );
      }
      return;
    }

    final gstParsed = double.tryParse(_gstCtl.text.trim());
    if (gstParsed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid GST rate')));
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(catalogRepoProvider);

      // Build the API model to send the update
      final updatedDraft = api.MenuItem(
        id: remoteId,
        tenantId: ref.read(activeTenantIdProvider),
        // categoryId: (omit entirely to avoid server 400/422)
        name: _nameCtl.text.trim(),
        description: _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim(),
        isActive: _isActive,
        stockOut: _stockOut,
        taxInclusive: _taxInclusive,
        gstRate: gstParsed,
        imageUrl: _imageUrl,
      );

      await repo.updateItem(remoteId, updatedDraft);

      // Trigger a sync to pull changes
      await ref.read(syncControllerProvider.notifier).syncNow();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved ✅')));
        Navigator.of(context).pop(true);
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $err')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteItem() async {
    final remoteId = widget.item.remoteId;
    if (remoteId == null || remoteId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This item hasn’t synced yet. Tap Sync, then try again.'))
        );
      }
      return;
    }

    final ok = await _confirm(context, 'Delete "${widget.item.name}"?\n(This will sync with the server)');
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(catalogRepoProvider).deleteItem(remoteId);

      // Trigger a sync to update local DB
      await ref.read(syncControllerProvider.notifier).syncNow();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted ${widget.item.name}')));
        // Pop twice to go back to the category list
        Navigator.of(context).pop(true);
        Navigator.of(context).pop(true);
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $err')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The widget.item is already the local db.MenuItem
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
          // Image uploader
          MenuImageUploaderField(
            value: _imageUrl,
            onChanged: (v) => setState(() => _imageUrl = v),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _nameCtl,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Item name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _descCtl,
            enabled: !_saving,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          SwitchListTile.adaptive(
            title: const Text('Active in menu'),
            subtitle: const Text('If OFF, POS should hide this item'),
            value: _isActive,
            onChanged: _saving
                ? null
                : (val) {
              setState(() {
                _isActive = val;
                if (!_isActive) _stockOut = true;
              });
            },
          ),
          SwitchListTile.adaptive(
            title: const Text('Out of stock'),
            subtitle: const Text('If ON, POS should block ordering'),
            value: _stockOut,
            onChanged: _saving
                ? null
                : (val) {
              setState(() {
                _stockOut = val;
                if (!_stockOut) _isActive = true;
              });
            },
          ),
          const Divider(height: 32),

          SwitchListTile.adaptive(
            title: const Text('Tax inclusive price'),
            subtitle: const Text('If ON, menu price is GST-inclusive'),
            value: _taxInclusive,
            onChanged: _saving ? null : (val) => setState(() => _taxInclusive = val),
          ),
          const SizedBox(height: 12),

          // GST preset dropdown
          DropdownButtonFormField<double?>(
            value: _gstPresetValue,
            decoration: const InputDecoration(
              labelText: 'GST % (preset)',
              border: OutlineInputBorder(),
            ),
            items: [
              ..._kGstPresets.map(
                    (v) => DropdownMenuItem<double?>(
                  value: v,
                  child: Text('${v.toStringAsFixed(0)}%'),
                ),
              ),
              const DropdownMenuItem<double?>(
                value: null,
                child: Text('Custom'),
              ),
            ],
            onChanged: _saving
                ? null
                : (val) {
              setState(() {
                _gstPresetValue = val;
                if (val != null) {
                  _gstCtl.text = val.toStringAsFixed(2);
                }
              });
            },
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _gstCtl,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
            decoration: const InputDecoration(
              labelText: 'GST %',
              hintText: 'e.g. 5.0',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save Item'),
            onPressed: _saving ? null : _saveItem,
          ),
        ],
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
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
      ],
    ),
  );
  return res ?? false;
}