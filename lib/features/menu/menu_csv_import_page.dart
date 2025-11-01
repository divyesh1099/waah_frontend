import 'dart:async';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/repo/catalog_repo.dart';
import 'package:waah_frontend/features/sync/sync_controller.dart';

class MenuCsvImportPage extends ConsumerStatefulWidget {
  const MenuCsvImportPage({super.key});

  @override
  ConsumerState<MenuCsvImportPage> createState() => _MenuCsvImportPageState();
}

class _MenuCsvImportPageState extends ConsumerState<MenuCsvImportPage> {
  PlatformFile? _csvFile;
  List<Map<String, String>> _rows = [];
  String? _parseError;
  bool _importing = false;
  int _done = 0;
  int _total = 0;

  static const _example = '''
category,name,description,gst_rate,tax_inclusive,is_active,variant_label,price,mrp,sku,hsn,image_url
Starters,Paneer Tikka,Smoky cottage cheese,5,true,true,Regular,180,,PNR-TIKKA,2106,https://picsum.photos/seed/paneer/400/300
Starters,Paneer Tikka,,5,true,true,Large,240,,PNR-TIKKA,2106,
Main Course,Butter Chicken,,5,true,true,Half,260,,BCH-001,2106,
Main Course,Butter Chicken,,5,true,true,Full,420,,BCH-001,2106,https://picsum.photos/seed/butter/400/300
''';

  Future<void> _pickCsv() async {
    setState(() {
      _rows = [];
      _parseError = null;
      _csvFile = null;
    });

    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;

    final f = res.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      setState(() => _parseError = 'Could not read CSV bytes');
      return;
    }

    try {
      final content = utf8.decode(bytes, allowMalformed: true);
      final csv = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(content);

      if (csv.isEmpty) {
        setState(() => _parseError = 'CSV is empty');
        return;
      }

      // Map headers -> index
      final header = csv.first.map((e) => (e?.toString() ?? '').trim().toLowerCase()).toList();
      int col(String name) => header.indexOf(name);

      final requiredCols = ['category', 'name', 'variant_label', 'price'];
      for (final rc in requiredCols) {
        if (!header.contains(rc)) {
          setState(() => _parseError = 'Missing required column: $rc');
          return;
        }
      }

      final rows = <Map<String, String>>[];
      for (var i = 1; i < csv.length; i++) {
        final row = csv[i];
        if (row.isEmpty) continue;
        String val(String name) {
          final idx = col(name);
          if (idx < 0 || idx >= row.length) return '';
          final v = row[idx];
          return (v == null) ? '' : v.toString().trim();
        }

        rows.add({
          'category': val('category'),
          'name': val('name'),
          'description': val('description'),
          'gst_rate': val('gst_rate'),
          'tax_inclusive': val('tax_inclusive'),
          'is_active': val('is_active'),
          'variant_label': val('variant_label'),
          'price': val('price'),
          'mrp': val('mrp'),
          'sku': val('sku'),
          'hsn': val('hsn'),
          'image_url': val('image_url'),
        });
      }

      setState(() {
        _csvFile = f;
        _rows = rows.where((r) => (r['category'] ?? '').isNotEmpty && (r['name'] ?? '').isNotEmpty).toList();
      });
    } catch (e) {
      setState(() => _parseError = 'CSV parse failed: $e');
    }
  }

  bool _truthy(String? s, {bool defaultValue = true}) {
    if (s == null) return defaultValue;
    final v = s.trim().toLowerCase();
    if (v.isEmpty) return defaultValue;
    return v == 'true' || v == '1' || v == 'yes' || v == 'y';
  }

  double _toDouble(String? s, double d) {
    if (s == null || s.trim().isEmpty) return d;
    final v = double.tryParse(s.trim());
    return v ?? d;
  }

  Future<void> _import() async {
    if (_rows.isEmpty || _importing) return;

    final repo = ref.read(catalogRepoProvider);
    final me = ref.read(authControllerProvider).me;
    final tenantId = me?.tenantId ?? '';
    final branchId = ref.read(activeBranchIdProvider);

    if (tenantId.isEmpty || branchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a branch and login first')),
      );
      return;
    }

    setState(() {
      _importing = true;
      _done = 0;
      _total = _rows.length;
    });

    // Group rows by (category,name) so we create item once and add variants
    final groups = <String, List<Map<String, String>>>{};
    for (final r in _rows) {
      final key = '${r['category']!.toLowerCase()}||${r['name']!.toLowerCase()}';
      (groups[key] ??= []).add(r);
    }

    int createdCats = 0, createdItems = 0, createdVars = 0, attachedImgs = 0;
    final errors = <String>[];

    try {
      for (final entry in groups.entries) {
        final rows = entry.value;
        final first = rows.first;

        final catName = first['category']!.trim();
        final itemName = first['name']!.trim();
        final description = (first['description'] ?? '').trim().isEmpty ? null : first['description']!.trim();
        final sku = (first['sku'] ?? '').trim().isEmpty ? null : first['sku']!.trim();
        final hsn = (first['hsn'] ?? '').trim().isEmpty ? null : first['hsn']!.trim();
        final gstRate = _toDouble(first['gst_rate'], 5.0);
        final taxInc = _truthy(first['tax_inclusive'], defaultValue: true);
        final isActive = _truthy(first['is_active'], defaultValue: true);
        final imageUrl = (first['image_url'] ?? '').trim();

        try {
          // Category
          final (localCatId, remoteCatId) = await repo.ensureCategoryByName(
            name: catName,
            tenantId: tenantId,
            branchId: branchId,
          );
          if (localCatId == 0 || remoteCatId.isEmpty) throw StateError('category create failed');
          createdCats++; // this counts attempts; OK if duplicates

          // Item
          final remoteItemId = await repo.ensureItemByName(
            itemName: itemName,
            remoteCategoryId: remoteCatId,
            tenantId: tenantId,
            description: description,
            isActive: isActive,
            taxInclusive: taxInc,
            gstRate: gstRate,
            sku: sku,
            hsn: hsn,
          );
          if (remoteItemId.isEmpty) throw StateError('item create failed');
          createdItems++;

          // Variants – each row is one variant
          for (final r in rows) {
            final label = (r['variant_label'] ?? '').trim().isEmpty ? 'Default' : r['variant_label']!.trim();
            final price = _toDouble(r['price'], 0.0);
            final mrp = (r['mrp'] ?? '').trim().isEmpty ? null : _toDouble(r['mrp'], price);

            await repo.ensureVariantByLabel(
              remoteItemId: remoteItemId,
              label: label,
              basePrice: price,
              mrp: mrp,
              isDefault: label.toLowerCase() == 'default' || label.toLowerCase() == 'regular',
            );
            createdVars++;
          }

          // Image once per (category,item) if provided
          if (imageUrl.isNotEmpty &&
              (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
            await repo.uploadItemImageFromHttpUrl(itemId: remoteItemId, imageUrl: imageUrl);
            attachedImgs++;
          }
        } catch (e) {
          errors.add('[$catName > $itemName] $e');
        }

        setState(() => _done += rows.length);
      }

      // Pull everything so UI updates
      await ref.read(syncControllerProvider.notifier).syncNow();

      if (!mounted) return;
      final msg = 'Import finished • Cats:$createdCats Items:$createdItems Variants:$createdVars Images:$attachedImgs'
          '${errors.isEmpty ? '' : '\nErrors: ${errors.length} (see console)'}';
      for (final e in errors) {
        // log to console
        // ignore: avoid_print
        print('CSV-IMPORT error: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCsv = _csvFile != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Import Menu from CSV')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'CSV Format',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Required columns: category, name, variant_label, price\n'
                  'Optional: description, gst_rate, tax_inclusive, is_active, mrp, sku, hsn, image_url (http/https)\n'
                  'Multiple variants for the same item? Add multiple rows with the same category+name and different variant_label/price.',
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              initiallyExpanded: false,
              title: const Text('See Example CSV'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.brown.shade50,
                    border: Border.all(color: Colors.brown.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(_example),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _importing ? null : _pickCsv,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Choose CSV'),
                ),
                const SizedBox(width: 12),
                if (hasCsv)
                  Text(
                    _csvFile!.name,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            if (_parseError != null) ...[
              const SizedBox(height: 8),
              Text(_parseError!, style: TextStyle(color: Colors.red.shade700)),
            ],
            if (hasCsv) ...[
              const SizedBox(height: 16),
              Text('Rows parsed: ${_rows.length}'),
              if (_importing) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
                const SizedBox(height: 4),
                Text('$_done / $_total processed'),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _importing ? null : _import,
                icon: const Icon(Icons.playlist_add),
                label: Text(_importing ? 'Importing…' : 'Import / Append'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
