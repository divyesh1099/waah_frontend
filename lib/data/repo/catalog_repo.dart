import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/app/providers.dart'; // apiClientProvider
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';
import 'package:file_picker/file_picker.dart';

class CatalogRepo {
  CatalogRepo(this._client);
  final ApiClient _client;

  // ------------------ Categories ------------------

  Future<List<MenuCategory>> loadCategories({
    String? tenantId,
    String? branchId,
  }) {
    return _client.fetchCategories(
      tenantId: tenantId ?? '',
      branchId: branchId ?? '',
    );
  }

  Future<MenuCategory> createCategory(MenuCategory data) {
    return _client.createCategory(data);
  }

  /// Low-level "PATCH /menu/categories/{id}" style update.
  Future<MenuCategory> updateCategory(String id, MenuCategory data) {
    return _client.updateCategory(id, data);
  }

  Future<void> deleteCategory(String id) {
    return _client.deleteCategory(id);
  }

  /// Convenience, returns same thing as loadCategories.
  Future<List<MenuCategory>> watchCategories({
    String? tenantId,
    String? branchId,
  }) {
    return loadCategories(
      tenantId: tenantId,
      branchId: branchId,
    );
  }

  /// Convenience helper used by UI: builds and creates a category from just a name.
  Future<MenuCategory> addCategory(
      String name, {
        String? tenantId,
        String? branchId,
        int position = 0,
      }) {
    final c = MenuCategory(
      id: null, // backend assigns
      tenantId: tenantId ?? '',
      branchId: branchId ?? '',
      name: name,
      position: position,
      createdAt: null,
      updatedAt: null,
    );
    return createCategory(c);
  }

  /// Convenience for the Edit Category dialog.
  /// We take raw fields (name/position/etc), build a MenuCategory, and forward to updateCategory().
  Future<MenuCategory> editCategory(
      String id, {
        required String name,
        required int position,
        String? tenantId,
        String? branchId,
      }) {
    final patch = MenuCategory(
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

  Future<List<MenuItem>> loadItems({
    String? categoryId,
    String? tenantId,
  }) {
    return _client.fetchItems(
      categoryId: categoryId,
      tenantId: tenantId,
    );
  }

  Future<MenuItem> createItem(MenuItem data) {
    return _client.createItem(data);
  }

  /// Update an item (PATCH /menu/items/{id}).
  /// You pass the current item's id and the draft with new values.
  Future<MenuItem> updateItem(String id, MenuItem data) {
    return _client.updateItem(id, data);
  }

  Future<void> deleteItem(String id) {
    return _client.deleteItem(id);
  }

  /// Older UI path that posts /items/{id}/update_tax.
  /// (Newer UI can just call updateItem with gstRate+taxInclusive.)
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

  // NOTE: We intentionally REMOVED setStockOut() and assignKitchenStation()
  // because ApiClient doesn't have them and current UI doesn't use them.

  /// Upload an image file to the backend and get back the server path
  /// (e.g. "/media/items/xyz.jpg").
  ///
  /// NOTE: You must also add a matching `uploadMedia` method in ApiClient
  /// that actually does the multipart/form-data POST.
  Future<String> uploadMedia(PlatformFile file) {
    return _client.uploadMedia(file);
  }

  // ------------------ Variants ------------------

  Future<List<ItemVariant>> loadVariants(String itemId) {
    return _client.fetchVariants(itemId);
  }

  /// Create a new variant (POST /menu/variants).
  Future<ItemVariant> createVariant(String itemId, ItemVariant data) {
    return _client.createVariant(itemId, data);
  }

  /// Edit a variant (PATCH /menu/variants/{variantId}).
  Future<ItemVariant> updateVariant(ItemVariant data) {
    final id = data.id;
    if (id == null) {
      throw ArgumentError('updateVariant requires variant id');
    }
    return _client.updateVariant(id, data);
  }

  /// Delete a variant (DELETE /menu/variants/{variantId}).
  Future<void> deleteVariant(String variantId) {
    return _client.deleteVariant(variantId);
  }

  // ------------------ Modifiers ------------------

  Future<ModifierGroup> createModifierGroup(ModifierGroup g) {
    return _client.createModifierGroup(g);
  }

  Future<Modifier> createModifier(Modifier m) {
    return _client.createModifier(m);
  }

  Future<void> linkItemModifierGroup(String itemId, String groupId) {
    return _client.linkItemModifierGroup(itemId, groupId);
  }
}

final catalogRepoProvider = Provider<CatalogRepo>((ref) {
  final client = ref.watch(apiClientProvider);
  return CatalogRepo(client);
});

