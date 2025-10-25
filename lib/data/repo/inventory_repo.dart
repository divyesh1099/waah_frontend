import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../api_client.dart';
import '../../app/providers.dart';

final inventoryRepoProvider = Provider<InventoryRepo>((ref) {
  final api = ref.watch(apiClientProvider);
  return InventoryRepo(api);
});

class InventoryRepo {
  InventoryRepo(this.api);
  final ApiClient api;

  Future<List<Ingredient>> loadIngredients({String tenantId = ''}) {
    return api.fetchIngredients(tenantId: tenantId);
  }

  Future<Ingredient> addIngredient({
    required String tenantId,
    required String name,
    required String uom,
    required double minLevel,
  }) {
    final ing = Ingredient(
      id: null,
      tenantId: tenantId,
      name: name,
      uom: uom,
      minLevel: minLevel,
      qtyOnHand: null,
    );
    return api.createIngredient(ing);
  }

  Future<Ingredient> updateMinLevel({
    required String ingredientId,
    required double minLevel,
  }) {
    return api.updateIngredient(
      ingredientId,
      minLevel: minLevel,
    );
  }

  Future<void> recordPurchase({
    required String tenantId,
    required String supplier,
    String? note,
    required List<PurchaseLineDraft> lines,
  }) {
    final bodyLines = lines.map((l) {
      return {
        'ingredient_id': l.ingredientId,
        'qty': l.qty,
        'unit_cost': l.unitCost,
      };
    }).toList();

    return api.createPurchase(
      tenantId: tenantId,
      supplier: supplier,
      note: note ?? '',
      lines: bodyLines,
    );
  }

  // direct passthrough for recipe/BOM setting
  Future<void> saveRecipe({
    required String itemId,
    required List<RecipeLineDraft> lines,
  }) {
    final payloadLines = lines.map((l) {
      return {
        'ingredient_id': l.ingredientId,
        'qty': l.qty,
      };
    }).toList();
    return api.setRecipe(itemId: itemId, lines: payloadLines);
  }

  // optional low stock call
  Future<List<Map<String, dynamic>>> lowStock() {
    return api.lowStock();
  }
}

/// simple helper structs

class PurchaseLineDraft {
  PurchaseLineDraft({
    required this.ingredientId,
    required this.qty,
    required this.unitCost,
  });

  final String ingredientId;
  final double qty;
  final double unitCost;
}

class RecipeLineDraft {
  RecipeLineDraft({
    required this.ingredientId,
    required this.qty,
  });

  final String ingredientId;
  final double qty;
}
