// lib/data/repo/catalog_repo.dart
import 'dart:io' as io;

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/local/app_db.dart';
import 'package:waah_frontend/data/models.dart' as api;
import 'package:dio/dio.dart' as dio;

class CatalogRepo {
  CatalogRepo(this._client, this._db);
  final ApiClient _client;
  final AppDatabase _db;

  // ------------------ Streams (UI reads) ------------------

  Stream<List<MenuCategory>> watchCategories() => _db.watchCategories();

  Stream<List<MenuItem>> watchItems(int localCategoryId) =>
      _db.watchItemsInCategory(localCategoryId);

  Stream<List<ItemVariant>> watchVariants(int localItemId) =>
      _db.watchVariantsForItem(localItemId);

  // ------------------ Helpers: map API -> local ------------------

  Future<void> _upsertLocalCategoryFromApi(api.MenuCategory c) async {
    await _db.upsertCategory(MenuCategoriesCompanion(
      remoteId: Value(c.id ?? ''),
      name: Value(c.name),
      position: Value(c.position),
    ));
  }

  Future<void> _upsertLocalItemFromApi(api.MenuItem it) async {
    final rid = it.id ?? '';
    if (rid.isEmpty) return;

    // Map remote category_id -> local category.id
    final remoteCatId = it.categoryId;
    if (remoteCatId == null || remoteCatId.isEmpty) return;
    final localCatId = await _db.localCategoryIdForRid(remoteCatId);
    if (localCatId == null) return;

    await _db.upsertMenuItem(MenuItemsCompanion(
      remoteId: Value(rid),
      categoryId: Value(localCatId),
      name: Value(it.name),
      description: Value(it.description),
      sku: Value(it.sku),
      hsn: Value(it.hsn),
      isActive: Value(it.isActive),
      stockOut: Value(it.stockOut),
      taxInclusive: Value(it.taxInclusive),
      gstRate: Value(it.gstRate),
      kitchenStationId: Value(it.kitchenStationId),
      imageUrl: Value(it.imageUrl),
    ));
  }

  Future<void> _upsertLocalVariantFromApi(api.ItemVariant v) async {
    final rid = v.id ?? '';
    if (rid.isEmpty) return;

    // Map remote item_id -> local item.id
    final localItemId = await _db.localItemIdForRid(v.itemId);
    if (localItemId == null) return;

    await _db.upsertItemVariant(ItemVariantsCompanion(
      remoteId: Value(rid),
      itemId: Value(localItemId),
      label: Value(v.label),
      mrp: Value(v.mrp),
      basePrice: Value(v.basePrice),
      isDefault: Value(v.isDefault),
      imageUrl: Value(v.imageUrl),
    ));
  }

  // ------------------ Categories (instant writes) ------------------

  Future<api.MenuCategory> createCategory(api.MenuCategory data) async {
    final out = await _client.createCategory(data);
    await _upsertLocalCategoryFromApi(out);
    return out;
  }

  Future<api.MenuCategory> updateCategory(String id, api.MenuCategory data) async {
    final out = await _client.updateCategory(id, data);
    await _upsertLocalCategoryFromApi(out);
    return out;
  }

  Future<void> deleteCategory(String id) async {
    await _client.deleteCategory(id);
    await _db.deleteCategoryByRid(id);
  }

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

  // ------------------ Items (instant writes) ------------------

  Future<api.MenuItem> createItem(api.MenuItem data) async {
    final out = await _client.createItem(data);
    await _upsertLocalItemFromApi(out);
    return out;
  }

  Future<api.MenuItem> updateItem(String id, api.MenuItem data) async {
    final out = await _client.updateItem(id, data);
    await _upsertLocalItemFromApi(out);
    return out;
  }

  Future<void> deleteItem(String id) async {
    await _client.deleteItem(id);
    await _db.deleteItemByRid(id);
  }

  Future<void> updateItemTax(
      String itemId, {
        required double gstRate,
        required bool taxInclusive,
      }) async {
    await _client.updateItemTax(itemId, gstRate: gstRate, taxInclusive: taxInclusive);
    // reflect locally if we have the row
    final localId = await _db.localItemIdForRid(itemId);
    if (localId != null) {
      await _db.upsertMenuItem(MenuItemsCompanion(
        id: Value(localId),
        gstRate: Value(gstRate),
        taxInclusive: Value(taxInclusive),
      ));
    }
  }

  Future<String> uploadMedia(PlatformFile file) {
    return _client.uploadMedia(file);
  }

  // ------------------ Variants (instant writes) ------------------

  Future<api.ItemVariant> createVariant(String itemId, api.ItemVariant data) async {
    final out = await _client.createVariant(itemId, data);
    await _upsertLocalVariantFromApi(out);
    return out;
  }

  Future<api.ItemVariant> updateVariant(api.ItemVariant data) async {
    final id = data.id;
    if (id == null || id.isEmpty) {
      throw ArgumentError('updateVariant requires variant id');
    }
    final out = await _client.updateVariant(id, data);
    await _upsertLocalVariantFromApi(out);
    return out;
  }

  Future<void> deleteVariant(String variantId) async {
    await _client.deleteVariant(variantId);
    await _db.deleteVariantByRid(variantId);
  }

  Future<String> uploadItemImage({
    required String itemId,        // remote item id
    required PlatformFile file,
  }) async {
    // Read bytes (supports web/desktop)
    final bytes = file.bytes ?? await io.File(file.path!).readAsBytes();

    String _inferMime(String name) {
      final lower = name.toLowerCase();
      if (lower.endsWith('.png')) return 'image/png';
      if (lower.endsWith('.webp')) return 'image/webp';
      if (lower.endsWith('.gif')) return 'image/gif';
      return 'image/jpeg';
    }

    // Upload via ApiClient (single source of truth)
    final url = await _client.uploadItemImage(
      itemId: itemId,
      bytes: bytes,
      filename: file.name,
      contentType: _inferMime(file.name),
    );

    // Update-only local write; do NOT insert partial rows
    // (Requires the helper in AppDatabase: setItemImageByRemoteId)
    try {
      await _db.setItemImageByRemoteId(itemId, url);
    } catch (_) {
      // Non-fatal; next sync will reconcile anyway
    }

    return url;
  }

  // ------------------ Full pull (on cold start / branch change) ------------------

  Future<void> syncDownMenu(String tenantId, String branchId) async {
    final cats = await _client.fetchCategories(tenantId: tenantId, branchId: branchId);
    final items = await _client.fetchItems(tenantId: tenantId);

    final byItem = <String, List<api.ItemVariant>>{};
    for (final it in items) {
      final rid = it.id;
      if (rid != null && rid.isNotEmpty) {
        byItem[rid] = await _client.fetchVariants(rid);
      }
    }

    await _db.transaction(() async {
      await _db.clearMenu();

      for (final c in cats) {
        await _upsertLocalCategoryFromApi(c);
      }

      // Build category rid -> local id map
      final catRows = await _db.select(_db.menuCategories).get();
      final catRidToLocal = <String, int>{};
      for (final r in catRows) {
        final rid = r.remoteId;
        if (rid != null && rid.isNotEmpty) catRidToLocal[rid] = r.id;
      }

      for (final it in items) {
        final remoteCat = it.categoryId;
        if (remoteCat == null || remoteCat.isEmpty) continue;
        final localCatId = catRidToLocal[remoteCat];
        if (localCatId == null) continue;

        await _db.upsertMenuItem(MenuItemsCompanion(
          remoteId: Value(it.id ?? ''),
          categoryId: Value(localCatId),
          name: Value(it.name),
          description: Value(it.description),
          sku: Value(it.sku),
          hsn: Value(it.hsn),
          isActive: Value(it.isActive),
          stockOut: Value(it.stockOut),
          taxInclusive: Value(it.taxInclusive),
          gstRate: Value(it.gstRate),
          kitchenStationId: Value(it.kitchenStationId),
          imageUrl: Value(it.imageUrl),
        ));
      }

      final itemRows = await _db.select(_db.menuItems).get();
      final itemRidToLocal = <String, int>{};
      for (final r in itemRows) {
        final rid = r.remoteId;
        if (rid != null && rid.isNotEmpty) itemRidToLocal[rid] = r.id;
      }

      for (final entry in byItem.entries) {
        final remoteItemId = entry.key;
        final localItemId = itemRidToLocal[remoteItemId];
        if (localItemId == null) continue;

        for (final v in entry.value) {
          await _db.upsertItemVariant(ItemVariantsCompanion(
            remoteId: Value(v.id ?? ''),
            itemId: Value(localItemId),
            label: Value(v.label),
            mrp: Value(v.mrp),
            basePrice: Value(v.basePrice),
            isDefault: Value(v.isDefault),
            imageUrl: Value(v.imageUrl),
          ));
        }
      }
    });

    // settings (non-fatal)
    try {
      final rsMap = await _client.fetchRestaurantSettings(
        tenantId: tenantId,
        branchId: branchId,
      );
      if (rsMap.isNotEmpty) {
        final rs = api.RestaurantSettings.fromJson(rsMap);
        await _db.upsertSettings(RestaurantSettingsCompanion(
          id: const Value(1),
          remoteId: Value(rs.id ?? ''),
          tenantId: Value(rs.tenantId),
          branchId: Value(rs.branchId),
          name: Value(rs.name),
          logoUrl: Value(rs.logoUrl),
          address: Value(rs.address),
          phone: Value(rs.phone),
          gstin: Value(rs.gstin),
          fssai: Value(rs.fssai),
          printFssaiOnInvoice: Value(rs.printFssaiOnInvoice),
          gstInclusiveDefault: Value(rs.gstInclusiveDefault),
          serviceChargeMode: Value(rs.serviceChargeMode.name),
          serviceChargeValue: Value(rs.serviceChargeValue),
          packingChargeMode: Value(rs.packingChargeMode.name),
          packingChargeValue: Value(rs.packingChargeValue),
          billingPrinterId: Value(rs.billingPrinterId),
          invoiceFooter: Value(rs.invoiceFooter),
        ));
      }
    } catch (_) {}
  }

  // --------- CSV Import helpers (idempotent “find-or-create”) ---------

  Future<MenuCategory?> _findLocalCategoryByNameCI(String name) async {
    final rows = await _db.select(_db.menuCategories).get();
    final n = name.trim().toLowerCase();
    for (final r in rows) {
      if (r.name.trim().toLowerCase() == n) return r;
    }
    return null;
  }

  Future<MenuItem?> _findLocalItemByNameCI(int localCategoryId, String name) async {
    final rows = await (_db.select(_db.menuItems)
      ..where((t) => t.categoryId.equals(localCategoryId)))
        .get();
    final n = name.trim().toLowerCase();
    for (final r in rows) {
      if (r.name.trim().toLowerCase() == n) return r;
    }
    return null;
  }

  Future<ItemVariant?> _findLocalVariantByLabelCI(int localItemId, String label) async {
    final rows = await (_db.select(_db.itemVariants)
      ..where((t) => t.itemId.equals(localItemId)))
        .get();
    final n = label.trim().toLowerCase();
    for (final r in rows) {
      if (r.label.trim().toLowerCase() == n) return r;
    }
    return null;
  }

  /// Returns (localCategoryId, remoteCategoryId)
  Future<(int, String)> ensureCategoryByName({
    required String name,
    required String tenantId,
    required String branchId,
  }) async {
    final existing = await _findLocalCategoryByNameCI(name);
    if (existing != null && (existing.remoteId ?? '').isNotEmpty) {
      return (existing.id, existing.remoteId!);
    }

    // create on server (this upserts locally via createCategory-> _upsertLocalCategoryFromApi)
    final out = await addCategory(
      name,
      tenantId: tenantId,
      branchId: branchId,
      position: existing?.position ?? 0,
    );

    final after = await _findLocalCategoryByNameCI(name);
    if (after == null || (after.remoteId ?? '').isEmpty) {
      throw StateError('Category "$name" not created properly');
    }
    return (after.id, after.remoteId!);
  }

  /// Returns remoteItemId
  Future<String> ensureItemByName({
    required String itemName,
    required String remoteCategoryId,
    required String tenantId,
    String? description,
    bool isActive = true,
    bool stockOut = false,
    bool taxInclusive = true,
    double gstRate = 5.0,
    String? sku,
    String? hsn,
  }) async {
    // map remote category -> local id
    final localCatId = await _db.localCategoryIdForRid(remoteCategoryId);
    if (localCatId != null) {
      final existingLocal = await _findLocalItemByNameCI(localCatId, itemName);
      if (existingLocal != null && (existingLocal.remoteId ?? '').isNotEmpty) {
        return existingLocal.remoteId!;
      }
    }

    // Create on server; local upsert occurs via createItem->_upsertLocalItemFromApi
    final created = await createItem(api.MenuItem(
      id: null,
      tenantId: tenantId,
      categoryId: remoteCategoryId,
      name: itemName,
      description: description,
      isActive: isActive,
      stockOut: stockOut,
      taxInclusive: taxInclusive,
      gstRate: gstRate,
      sku: sku,
      hsn: hsn,
    ));
    final rid = created.id ?? '';
    if (rid.isEmpty) throw StateError('Item "$itemName" did not return id');

    return rid;
  }

  Future<void> ensureVariantByLabel({
    required String remoteItemId,
    required String label,
    required double basePrice,
    double? mrp,
    bool isDefault = false,
  }) async {
    final localItemId = await _db.localItemIdForRid(remoteItemId);
    if (localItemId != null) {
      final existing = await _findLocalVariantByLabelCI(localItemId, label);
      if (existing != null) {
        // Update if needed
        await updateVariant(api.ItemVariant(
          id: existing.remoteId, // might be null; server will ignore if missing
          itemId: remoteItemId,
          label: label,
          mrp: mrp ?? basePrice,
          basePrice: basePrice,
          isDefault: isDefault,
        ));
        return;
      }
    }

    // Create
    await createVariant(
      remoteItemId,
      api.ItemVariant(
        id: null,
        itemId: remoteItemId,
        label: label,
        mrp: mrp ?? basePrice,
        basePrice: basePrice,
        isDefault: isDefault,
      ),
    );
  }

  /// Download an image from a public HTTP/HTTPS URL and attach to item
  Future<void> uploadItemImageFromHttpUrl({
    required String itemId, // remote id
    required String imageUrl,
  }) async {
    final u = imageUrl.trim();
    if (!(u.startsWith('http://') || u.startsWith('https://'))) return;

    final d = dio.Dio();
    final resp = await d.get<List<int>>(
      u,
      options: dio.Options(responseType: dio.ResponseType.bytes),
    );
    if (resp.data == null) return;

    String _inferMime(String name) {
      final lower = name.toLowerCase();
      if (lower.endsWith('.png')) return 'image/png';
      if (lower.endsWith('.webp')) return 'image/webp';
      if (lower.endsWith('.gif')) return 'image/gif';
      return 'image/jpeg';
    }

    final filename = Uri.parse(u).pathSegments.isNotEmpty
        ? Uri.parse(u).pathSegments.last
        : 'image.jpg';

    final url = await _client.uploadItemImage(
      itemId: itemId,
      bytes: resp.data!,
      filename: filename,
      contentType: _inferMime(filename),
    );

    // update-only locally
    try {
      await _db.setItemImageByRemoteId(itemId, url);
    } catch (_) {}
  }

}

final catalogRepoProvider = Provider<CatalogRepo>((ref) {
  final client = ref.watch(apiClientProvider);
  final db = ref.watch(localDatabaseProvider);
  return CatalogRepo(client, db);
});
