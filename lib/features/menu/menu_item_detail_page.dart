import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value; // <-- for Value()
import 'package:waah_frontend/app/providers.dart';
// API models
import 'package:waah_frontend/data/models.dart' as api;
// Local DB (generated types live under this alias)
import 'package:waah_frontend/data/local/app_db.dart' as db;

import 'package:waah_frontend/data/repo/catalog_repo.dart';
import 'package:waah_frontend/features/sync/sync_controller.dart';
import 'package:waah_frontend/widgets/menu_media.dart';

const List<double> _kGstPresets = [0, 5, 12, 18, 28];

class MenuItemDetailPage extends ConsumerStatefulWidget {
  const MenuItemDetailPage({super.key, required this.item});
  final db.MenuItem item; // local DB row

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
  double? _gstPresetValue; // null => custom
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.item.name);
    _descCtl = TextEditingController(text: widget.item.description ?? '');
    _gstCtl = TextEditingController(
      text: (widget.item.gstRate).toStringAsFixed(2),
    );

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

    // Need remoteId to PATCH server
    final remoteId = widget.item.remoteId;
    if (remoteId == null || remoteId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This item hasn’t synced yet. Tap Sync, then try again.'),
        ),
      );
      return;
    }

    final gstParsed = double.tryParse(_gstCtl.text.trim());
    if (gstParsed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid GST rate')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(catalogRepoProvider);

      // Build API model for update (omit categoryId to avoid 400/422)
      final updatedDraft = api.MenuItem(
        id: remoteId,
        tenantId: ref.read(activeTenantIdProvider),
        name: _nameCtl.text.trim(),
        description: _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim(),
        isActive: _isActive,
        stockOut: _stockOut,
        taxInclusive: _taxInclusive,
        gstRate: gstParsed,
        imageUrl: _imageUrl,
      );

      await repo.updateItem(remoteId, updatedDraft);

      // Pull fresh data into local DB
      await ref.read(syncControllerProvider.notifier).syncNow();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved ✅')),
      );

      // Pop safely after the current frame (prevents !_debugLocked crashes)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop(true);
      });
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $err')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteItem() async {
    final remoteId = widget.item.remoteId;
    if (remoteId == null || remoteId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This item hasn’t synced yet. Tap Sync, then try again.'),
        ),
      );
      return;
    }

    final ok = await _confirm(
      context,
      'Delete "${widget.item.name}"?\n(This will sync with the server)',
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(catalogRepoProvider).deleteItem(remoteId);
      await ref.read(localDatabaseProvider).deleteMenuItemByRemoteId(remoteId);
      await ref.read(syncControllerProvider.notifier).syncNow();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${widget.item.name}')),
      );

      // Single safe pop after frame; don’t pop twice
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop(true);
      });
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $err')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
          // Image uploader
          MenuImageUploaderField(
            value: _imageUrl,
            onChanged: (v) => setState(() => _imageUrl = v),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _nameCtl,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Item name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

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
                if (val != null) _gstCtl.text = val.toStringAsFixed(2);
              });
            },
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _gstCtl,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'GST %',
              hintText: 'e.g. 5.0',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          // 👇 Price editor for default variant
          DefaultPriceEditor(itemId: it.id),

          const SizedBox(height: 24),

          FilledButton.icon(
            icon: _saving
                ? const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save Item'),
            onPressed: _saving ? null : _saveItem,
          ),
        ],
      ),
    );
  }
}

class DefaultPriceEditor extends ConsumerStatefulWidget {
  final int itemId; // local menu_items.id
  const DefaultPriceEditor({super.key, required this.itemId});

  @override
  ConsumerState<DefaultPriceEditor> createState() => _DefaultPriceEditorState();
}

class _DefaultPriceEditorState extends ConsumerState<DefaultPriceEditor> {
  final _ctrl = TextEditingController();
  db.ItemVariant? _variant; // generated row

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final database = ref.read(localDatabaseProvider);

    // Combine conditions by chaining .where(...) (AND)
    final existing = await (database.select(database.itemVariants)
      ..where((t) => t.itemId.equals(widget.itemId))
      ..where((t) => t.isDefault.equals(true)))
        .getSingleOrNull();

    if (!mounted) return;
    setState(() {
      _variant = existing;
      _ctrl.text = (existing?.basePrice ?? 0).toString();
    });
  }

  Future<void> _save() async {
    final database = ref.read(localDatabaseProvider);
    final parsed = double.tryParse(_ctrl.text.trim()) ?? 0.0;

    if (_variant == null) {
      // create default variant
      await database.upsertItemVariant(
        db.ItemVariantsCompanion(
          itemId: Value(widget.itemId),
          label: const Value('Default'),
          isDefault: const Value(true),
          basePrice: Value(parsed),
        ),
      );
    } else {
      await database.upsertItemVariant(
        db.ItemVariantsCompanion(
          remoteId: Value(_variant!.remoteId), // can be null for local-only
          itemId: Value(widget.itemId),
          label: Value(_variant!.label),
          isDefault: const Value(true),
          basePrice: Value(parsed),
        ),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Price saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Price'),
        const SizedBox(width: 12),
        SizedBox(
          width: 140,
          child: TextField(
            controller: _ctrl,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: false),
            decoration: const InputDecoration(
              hintText: '0.00',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: _save, child: const Text('Update')),
      ],
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
