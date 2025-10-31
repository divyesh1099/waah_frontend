// lib/data/local/app_db.dart
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'app_db.g.dart';

@DataClassName('MenuCategory')
class MenuCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().unique().named('rid').nullable()();
  TextColumn get name => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
}

@DataClassName('MenuItem')
class MenuItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().unique().named('rid').nullable()();
  IntColumn get categoryId =>
      integer().references(MenuCategories, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get sku => text().nullable()();
  TextColumn get hsn => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get stockOut => boolean().withDefault(const Constant(false))();
  BoolColumn get taxInclusive =>
      boolean().withDefault(const Constant(true))();
  RealColumn get gstRate => real().withDefault(const Constant(5.0))();
  TextColumn get kitchenStationId => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
}

@DataClassName('ItemVariant')
class ItemVariants extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().unique().named('rid').nullable()();
  IntColumn get itemId =>
      integer().references(MenuItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  RealColumn get mrp => real().nullable()();
  RealColumn get basePrice => real()();
  BoolColumn get isDefault =>
      boolean().withDefault(const Constant(false))();
  TextColumn get imageUrl => text().nullable()();
}

@DataClassName('DiningTable')
class DiningTables extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().unique().named('rid').nullable()();
  TextColumn get name => text()();
  TextColumn get status => text().withDefault(const Constant('free'))();
}

@DataClassName('OpsJournalEntry')
class OpsJournal extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('RestaurantSetting')
class RestaurantSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get remoteId => text().unique().named('rid').nullable()();
  TextColumn get tenantId => text().nullable()();
  TextColumn get branchId => text().nullable()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get gstin => text().nullable()();
  TextColumn get fssai => text().nullable()();
  BoolColumn get printFssaiOnInvoice =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get gstInclusiveDefault =>
      boolean().withDefault(const Constant(true))();
  TextColumn get serviceChargeMode =>
      text().withDefault(const Constant('NONE'))();
  RealColumn get serviceChargeValue =>
      real().withDefault(const Constant(0.0))();
  TextColumn get packingChargeMode =>
      text().withDefault(const Constant('NONE'))();
  RealColumn get packingChargeValue =>
      real().withDefault(const Constant(0.0))();
  TextColumn get billingPrinterId => text().nullable()();
  TextColumn get invoiceFooter => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  MenuCategories,
  MenuItems,
  ItemVariants,
  DiningTables,
  OpsJournal,
  RestaurantSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  // NEW: public, callable from other files
  factory AppDatabase.open() => AppDatabase(_openConnection());

  @override
  int get schemaVersion => 3;

  Future<void> _dropTableIfExists(Migrator m, String tableName) async {
    try {
      await m.issueCustomQuery('DROP TABLE IF EXISTS $tableName;');
    } catch (_) {}
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 3) {
        await _dropTableIfExists(m, 'menu_categories');
        await _dropTableIfExists(m, 'menu_items');
        await _dropTableIfExists(m, 'item_variants');
        await _dropTableIfExists(m, 'dining_tables');
        await _dropTableIfExists(m, 'ops_journal');
        await _dropTableIfExists(m, 'restaurant_settings');
        await m.createAll();
      }
    },
  );

  // ---------- Streams (sorted & fast) ----------
  Stream<List<MenuCategory>> watchCategories() =>
      (select(menuCategories)
        ..orderBy([
              (t) => OrderingTerm(expression: t.position, mode: OrderingMode.asc),
              (t) => OrderingTerm(expression: t.id, mode: OrderingMode.asc),
        ]))
          .watch();

  Stream<List<MenuItem>> watchItemsInCategory(int catId) =>
      (select(menuItems)
        ..where((t) => t.categoryId.equals(catId))
        ..orderBy([
              (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
              (t) => OrderingTerm(expression: t.id, mode: OrderingMode.asc),
        ]))
          .watch();

  Stream<List<ItemVariant>> watchVariantsForItem(int itemId) =>
      (select(itemVariants)
        ..where((t) => t.itemId.equals(itemId))
        ..orderBy([
              (t) => OrderingTerm(expression: t.isDefault, mode: OrderingMode.desc),
              (t) => OrderingTerm(expression: t.basePrice, mode: OrderingMode.asc),
              (t) => OrderingTerm(expression: t.id, mode: OrderingMode.asc),
        ]))
          .watch();

  Stream<List<DiningTable>> watchDiningTables() =>
      select(diningTables).watch();

  Stream<RestaurantSetting?> watchSettings() =>
      (select(restaurantSettings)..where((t) => t.id.equals(1)))
          .watchSingleOrNull();

  // ---------- CRUD helpers ----------
  Future<void> upsertCategory(MenuCategoriesCompanion companion) =>
      into(menuCategories).insertOnConflictUpdate(companion);

  // MENU ITEMS
  Future<void> upsertMenuItem(MenuItemsCompanion c) async {
    final String? rid =
    c.remoteId.present ? c.remoteId.value : null; // 'rid' column
    if (rid == null || rid.isEmpty) {
      // brand-new local item (no remote yet)
      await into(menuItems).insert(c);
      return;
    }
    final existing = await (select(menuItems)..where((t) => t.remoteId.equals(rid))).getSingleOrNull();
    if (existing == null) {
      await into(menuItems).insert(c);
    } else {
      await (update(menuItems)..where((t) => t.id.equals(existing.id))).write(c);
    }
  }

  // VARIANTS
  Future<void> upsertItemVariant(ItemVariantsCompanion c) async {
    final String? rid =
    c.remoteId.present ? c.remoteId.value : null;
    if (rid == null || rid.isEmpty) {
      await into(itemVariants).insert(c);
      return;
    }
    final existing = await (select(itemVariants)..where((t) => t.remoteId.equals(rid))).getSingleOrNull();
    if (existing == null) {
      await into(itemVariants).insert(c);
    } else {
      await (update(itemVariants)..where((t) => t.id.equals(existing.id))).write(c);
    }
  }

  Future<void> upsertSettings(RestaurantSettingsCompanion companion) =>
      into(restaurantSettings).insertOnConflictUpdate(companion);

  Future<void> addPendingOp(OpsJournalCompanion op) =>
      into(opsJournal).insert(op);

  Future<List<OpsJournalEntry>> getPendingOps() =>
      select(opsJournal).get();

  Future<void> clearPendingOps(List<int> ids) =>
      (delete(opsJournal)..where((t) => t.id.isIn(ids))).go();

  Future<void> clearMenu() async {
    await transaction(() async {
      await delete(itemVariants).go();
      await delete(menuItems).go();
      await delete(menuCategories).go();
    });
  }

  Future<MenuCategory?> findCategoryByRid(String rid) {
    return (select(menuCategories)..where((t) => t.remoteId.equals(rid)))
        .getSingleOrNull();
  }

  Future<MenuItem?> findItemByRid(String rid) {
    return (select(menuItems)..where((t) => t.remoteId.equals(rid)))
        .getSingleOrNull();
  }

  Future<int?> localCategoryIdForRid(String rid) async {
    final row = await findCategoryByRid(rid);
    return row?.id;
  }

  Future<int?> localItemIdForRid(String rid) async {
    final row = await findItemByRid(rid);
    return row?.id;
  }

  Future<void> deleteCategoryByRid(String rid) async {
    final row =
    await (select(menuCategories)..where((t) => t.remoteId.equals(rid)))
        .getSingleOrNull();
    if (row != null) {
      await (delete(menuCategories)..where((t) => t.id.equals(row.id))).go();
    }
  }

  Future<void> deleteItemByRid(String rid) async {
    final row =
    await (select(menuItems)..where((t) => t.remoteId.equals(rid)))
        .getSingleOrNull();
    if (row != null) {
      await (delete(menuItems)..where((t) => t.id.equals(row.id))).go();
    }
  }

  Future<void> deleteVariantByRid(String rid) async {
    final row =
    await (select(itemVariants)..where((t) => t.remoteId.equals(rid)))
        .getSingleOrNull();
    if (row != null) {
      await (delete(itemVariants)..where((t) => t.id.equals(row.id))).go();
    }
  }


  Future<void> upsertDiningTable(DiningTablesCompanion c) async {
    final String? rid = c.remoteId.present ? c.remoteId.value : null;

    if (rid == null || rid.isEmpty) {
      // Fall back to a plain insert if no remote id yet
      await into(diningTables).insert(c);
      return;
    }

    final existing = await (select(diningTables)
      ..where((t) => t.remoteId.equals(rid)))
        .getSingleOrNull();

    if (existing == null) {
      await into(diningTables).insert(c);
    } else {
      await (update(diningTables)..where((t) => t.id.equals(existing.id))).write(c);
    }
  }
}

// Keep your provider here or in providers.dart (you already expose one there)
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'waah_pos.db'));
    return NativeDatabase(file);
  });
}
