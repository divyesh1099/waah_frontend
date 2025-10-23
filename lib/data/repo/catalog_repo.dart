// lib/data/repo/catalog_repo.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/app/providers.dart'; // apiClientProvider
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';

class CatalogRepo {
  CatalogRepo(this._client);
  final ApiClient _client;

  // ------------------ Categories ------------------
  Future<List<MenuCategory>> loadCategories({String? tenantId, String? branchId}) =>
      _client.fetchCategories(tenantId: tenantId ?? '', branchId: branchId ?? '');

  Future<MenuCategory> createCategory(MenuCategory data) {
    return _client.createCategory(data);
  }

  Future<MenuCategory> updateCategory(String id, MenuCategory data) {
    return _client.updateCategory(id, data);
  }

  Future<void> deleteCategory(String id) {
    return _client.deleteCategory(id);
  }

  /// Legacy shim kept for UI compatibility. Returns the same as `loadCategories`.
  Future<List<MenuCategory>> watchCategories({String? tenantId, String? branchId}) =>
      loadCategories(tenantId: tenantId, branchId: branchId);

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

  // ------------------ Items ------------------
  Future<List<MenuItem>> loadItems({
    String? categoryId,
    String? tenantId,
  }) {
    return _client.fetchItems(categoryId: categoryId, tenantId: tenantId);
  }

  Future<MenuItem> createItem(MenuItem data) {
    return _client.createItem(data);
  }

  Future<MenuItem> updateItem(String id, MenuItem data) {
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

  // ------------------ Variants ------------------
  Future<List<ItemVariant>> loadVariants(String itemId) {
    return _client.fetchVariants(itemId);
  }

  Future<ItemVariant> createVariant(String itemId, ItemVariant data) {
    return _client.createVariant(itemId, data);
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
