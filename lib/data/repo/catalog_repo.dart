import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/app/providers.dart'; // apiClientProvider
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/local/app_db.dart'; // Import Drift DB
import 'package:waah_frontend/data/models.dart' as api; // Use alias for API models
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;
import 'package:drift/drift.dart' show Value;

import '../local/app_db.dart';

class CatalogRepo {
  CatalogRepo(this._client, this._db); // Needs both
  final ApiClient _client;
  final AppDatabase _db; // Local database instance

  // ------------------ Categories ------------------

  // OFFLINE READ: Watch local DB for changes
  Stream<List<MenuCategory>> watchCategories() {
    // Note: This returns the Drift-generated MenuCategory,
    // not the api.MenuCategory from models.dart
    return _db.watchCategories();
  }

  // ONLINE WRITE: Still hits the API.
  // (We will route this to OpsJournal in a later step)
  Future<api.MenuCategory> createCategory(api.MenuCategory data) {
    return _client.createCategory(data);
  }

  Future<api.MenuCategory> updateCategory(String id, api.MenuCategory data) {
    return _client.updateCategory(id, data);
  }

  Future<void> deleteCategory(String id) {
    return _client.deleteCategory(id);
  }

  /// Convenience helper for UI
  Future<api.MenuCategory> addCategory(
      String name, {
        String? tenantId,
        String? branchId,
        int position = 0,
      }) {
    final c = api.MenuCategory(
      id: null,
      tenantId: tenantId ?? '',
      branchId: branchId ?? '',
      name: name,
      position: position,
      createdAt: null,
      updatedAt: null,
    );
    return createCategory(c);
  }

  Future<api.MenuCategory> editCategory(
      String id, {
        required String name,
        required int position,
        String? tenantId,
        String? branchId,
      }) {
    final patch = api.MenuCategory(
      id: id,
      tenantId: tenantId ?? '',
      branchId: branchId ?? '',
      name: name,
      position: position,
      createdAt: null,
      updatedAt: null,
    );
    return updateCategory(id, patch);
  }

  // ------------------ Items ------------------

  // OFFLINE READ: Watch local DB for changes
  // This watches items for a *specific local category ID*
  Stream<List<MenuItem>> watchItems(int localCategoryId) {
    return _db.watchItemsInCategory(localCategoryId);
  }

  // ONLINE WRITE:
  Future<api.MenuItem> createItem(api.MenuItem data) {
    return _client.createItem(data);
  }

  Future<api.MenuItem> updateItem(String id, api.MenuItem data) {
    return _client.updateItem(id, data);
  }

  Future<void> deleteItem(String id) {
    return _client.deleteItem(id);
  }

  Future<void> updateItemTax(
      String itemId, {
        required double gstRate,
        required bool taxInclusive,
      }) {
    return _client.updateItemTax(
      itemId,
      gstRate: gstRate,
      taxInclusive: taxInclusive,
    );
  }

  Future<String> uploadMedia(PlatformFile file) {
    return _client.uploadMedia(file);
  }

  // ------------------ Variants ------------------

  // OFFLINE READ:
  Stream<List<ItemVariant>> watchVariants(int localItemId) {
    return _db.watchVariantsForItem(localItemId);
  }

  // ONLINE WRITE:
  Future<api.ItemVariant> createVariant(String itemId, api.ItemVariant data) {
    return _client.createVariant(itemId, data);
  }

  Future<api.ItemVariant> updateVariant(api.ItemVariant data) {
    final id = data.id;
    if (id == null) {
      throw ArgumentError('updateVariant requires variant id');
    }
    return _client.updateVariant(id, data);
  }

  Future<void> deleteVariant(String variantId) {
    return _client.deleteVariant(variantId);
  }

  // ------------------ Modifiers (keep as-is for now) ------------------

  Future<api.ModifierGroup> createModifierGroup(api.ModifierGroup g) {
    return _client.createModifierGroup(g);
  }

  Future<api.Modifier> createModifier(api.Modifier m) {
    return _client.createModifier(m);
  }

  Future<void> linkItemModifierGroup(String itemId, String groupId) {
    return _client.linkItemModifierGroup(itemId, groupId);
  }

  Future<String> uploadItemImage({
    required String itemId,
    required PlatformFile file,
  }) async {
    final bytes = file.bytes ?? await io.File(file.path!).readAsBytes();
    String _inferMime(String name) {
      final lower = name.toLowerCase();
      if (lower.endsWith('.png')) return 'image/png';
      if (lower.endsWith('.webp')) return 'image/webp';
      if (lower.endsWith('.gif')) return 'image/gif';
      return 'image/jpeg';
    }

    final contentType = _inferMime(file.name);
    final url = await _client.uploadItemImage(
      itemId: itemId,
      bytes: bytes,
      filename: file.name,
      contentType: contentType,
    );
    return url;
  }


// Pull categories/items/variants from server and write into Drift.
  Future<void> syncDownMenu(String tenantId, String branchId) async {
    // 1) fetch everything from API
    final cats   = await _client.fetchCategories(tenantId: tenantId, branchId: branchId);
    final items  = await _client.fetchItems(tenantId: tenantId);
    final byItem = <String, List<api.ItemVariant>>{};

    for (final it in items) {
      final rid = it.id;
      if (rid != null && rid.isNotEmpty) {
        byItem[rid] = await _client.fetchVariants(rid);
      }
    }

    // 2) write to local DB in a single transaction
    await _db.transaction(() async {
      await _db.clearMenu();

      // 2a) categories
      for (final c in cats) {
        await _db.upsertCategory(MenuCategoriesCompanion(
          remoteId: Value(c.id ?? ''),
          name:     Value(c.name),
          position: Value(c.position),
        ));
      }

      // map remote category id -> local id
      final catRows = await _db.select(_db.menuCategories).get();
      final catRidToLocal = <String, int>{};
      for (final r in catRows) {
        final rid = r.remoteId;
        if (rid != null && rid.isNotEmpty) {
          catRidToLocal[rid] = r.id;
        }
      }

      // 2b) items
      for (final it in items) {
        final remoteCatId = it.categoryId;
        if (remoteCatId == null || remoteCatId.isEmpty) continue;

        final localCatId = catRidToLocal[remoteCatId];
        if (localCatId == null) continue; // category not in this branch => skip

        await _db.upsertMenuItem(MenuItemsCompanion(
          remoteId:         Value(it.id ?? ''),
          categoryId:       Value(localCatId),
          name:             Value(it.name),
          description:      Value(it.description),
          sku:              Value(it.sku),
          hsn:              Value(it.hsn),
          isActive:         Value(it.isActive),
          stockOut:         Value(it.stockOut),
          taxInclusive:     Value(it.taxInclusive),
          gstRate:          Value(it.gstRate),
          kitchenStationId: Value(it.kitchenStationId),
          imageUrl:         Value(it.imageUrl),
        ));
      }

      // map remote item id -> local id
      final itemRows = await _db.select(_db.menuItems).get();
      final itemRidToLocal = <String, int>{};
      for (final r in itemRows) {
        final rid = r.remoteId;
        if (rid != null && rid.isNotEmpty) {
          itemRidToLocal[rid] = r.id;
        }
      }


      // 2c) variants
      for (final entry in byItem.entries) {
        final remoteItemId = entry.key;
        final localItemId  = itemRidToLocal[remoteItemId];
        if (localItemId == null) continue;

        for (final v in entry.value) {
          await _db.upsertItemVariant(ItemVariantsCompanion(
            remoteId:  Value(v.id ?? ''),
            itemId:    Value(localItemId),
            label:     Value(v.label),
            mrp:       Value(v.mrp),
            basePrice: Value(v.basePrice),
            isDefault: Value(v.isDefault),
            imageUrl:  Value(v.imageUrl),
          ));
        }
      }
    });

    // 3) settings down-sync (so brand/logo appear offline)
    try {
      final rsMap = await _client.fetchRestaurantSettings(
        tenantId: tenantId,
        branchId: branchId,
      );
      if (rsMap.isNotEmpty) {
        final rs = api.RestaurantSettings.fromJson(rsMap);
        await _db.upsertSettings(RestaurantSettingsCompanion(
          id:                   const Value(1),
          remoteId:             Value(rs.id ?? ''),
          tenantId:             Value(rs.tenantId),
          branchId:             Value(rs.branchId),
          name:                 Value(rs.name),
          logoUrl:              Value(rs.logoUrl),
          address:              Value(rs.address),
          phone:                Value(rs.phone),
          gstin:                Value(rs.gstin),
          fssai:                Value(rs.fssai),
          printFssaiOnInvoice:  Value(rs.printFssaiOnInvoice),
          gstInclusiveDefault:  Value(rs.gstInclusiveDefault),
          serviceChargeMode:    Value(rs.serviceChargeMode.name),
          serviceChargeValue:   Value(rs.serviceChargeValue),
          packingChargeMode:    Value(rs.packingChargeMode.name),
          packingChargeValue:   Value(rs.packingChargeValue),
          billingPrinterId:     Value(rs.billingPrinterId),
          invoiceFooter:        Value(rs.invoiceFooter),
        ));
      }
    } catch (_) {/* non-fatal */}
  }
}

// Update the provider to inject the new DB dependency
final catalogRepoProvider = Provider<CatalogRepo>((ref) {
  final client = ref.watch(apiClientProvider);
  final db = ref.watch(localDatabaseProvider); // <-- Add this
  return CatalogRepo(client, db); // <-- Pass it in
});