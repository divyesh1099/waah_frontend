import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../local/collections.dart';

class CatalogRepo {
  final Database db;
  CatalogRepo(this.db);

  Future<List<MenuCategoryCol>> getCategories() async {
    final rows = await db.query(
      'menu_category',
      orderBy: 'position ASC, name ASC',
    );
    return rows.map((r) => MenuCategoryCol(
      id: r['id'] as int?,
      name: r['name'] as String,
      rid: r['rid'] as String?,
      position: (r['position'] as int?) ?? 0,
    )).toList();
  }

  // ✅ Replaces the old Isar watch stream (uses polling)
  Stream<List<MenuCategoryCol>> watchCategories({Duration interval = const Duration(seconds: 1)}) async* {
    while (true) {
      yield await getCategories();
      await Future.delayed(interval);
    }
  }

  // ✅ Simple insert; also assigns next position
  Future<int> addCategory(String name, {String? rid}) async {
    final maxPosRow = await db.rawQuery('SELECT COALESCE(MAX(position),0) AS maxp FROM menu_category');
    final nextPos = (maxPosRow.first['maxp'] as int) + 1;
    return await db.insert('menu_category', {
      'name': name,
      'rid': rid,
      'position': nextPos,
    });
  }

  Future<List<MenuItemCol>> getItemsByCategory(int categoryId) async {
    final rows = await db.query(
      'menu_item',
      where: 'category_id=?',
      whereArgs: [categoryId],
      orderBy: 'name ASC',
    );
    return rows.map((r) => MenuItemCol(
      id: r['id'] as int?,
      categoryId: r['category_id'] as int,
      name: r['name'] as String,
      price: (r['price'] as num).toDouble(),
      rid: r['rid'] as String?,
    )).toList();
  }
}

final catalogRepoProvider = Provider<CatalogRepo>((ref) {
  final db = ref.watch(databaseProvider);
  return CatalogRepo(db);
});
