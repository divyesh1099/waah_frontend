import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/repo/inventory_repo.dart';
import 'inventory_page.dart';

class InventoryImportPage extends ConsumerStatefulWidget {
  const InventoryImportPage({super.key});

  @override
  ConsumerState<InventoryImportPage> createState() => _InventoryImportPageState();
}

class _InventoryImportPageState extends ConsumerState<InventoryImportPage> {
  bool _busy = false;
  String? _log;

  Future<String?> _pickCsvText() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.first;
    if (f.bytes != null) return utf8.decode(f.bytes!);
    if (f.path != null) return File(f.path!).readAsString();
    return null;
  }

  Future<void> _import() async {
    final csvText = await _pickCsvText();
    if (csvText == null) return;

    setState(() {
      _busy = true;
      _log = 'Importing...';
    });

    final repo = ref.read(inventoryRepoProvider);
    final branchId = ref.read(activeBranchIdProvider);
    try {
      final res = await repo.importIngredientsCsv(csvText, branchId: branchId);
      setState(() {
        _log = 'Imported: ${res['created']} new, ${res['updated']} updated';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_log!)),
        );
      }
      ref.invalidate(ingredientsProvider);
    } catch (e) {
      setState(() => _log = 'Import failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  
  Future<void> _export() async {
    setState(() {
      _busy = true;
      _log = 'Exporting...';
    });

    final repo = ref.read(inventoryRepoProvider);
    final branchId = ref.read(activeBranchIdProvider);
    try {
      final csvText = await repo.exportIngredientsCsv(branchId: branchId);
      final savePath = await FilePicker.platform.saveFile(
        fileName: 'ingredients.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (savePath != null) {
        await File(savePath).writeAsString(csvText);
        setState(() => _log = 'Exported to $savePath');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export successful')),
          );
        }
      } else {
        setState(() => _log = 'Export cancelled');
      }
    } catch (e) {
      setState(() => _log = 'Export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import / Export Inventory'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a CSV file with ingredients. Expected columns:\n'
              '- name (required)\n'
              '- uom (required)\n'
              '- min_level (optional)\n'
              '- qty_on_hand (optional)\n',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _import,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_file),
              label: const Text('Choose CSV and import'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Export Inventory',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.download),
              label: const Text('Export Ingredients CSV'),
            ),
            const SizedBox(height: 16),
            if (_log != null)
              Text(
                _log!,
                style: TextStyle(
                  color: _log!.toLowerCase().contains('fail') ? Colors.red : Colors.green,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
