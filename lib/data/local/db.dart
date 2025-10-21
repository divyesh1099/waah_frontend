import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

Future<Database> openDb() async {
  // Enable FFI for desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final Directory appDocDir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(appDocDir.path, 'waah_pos.db');

  return await databaseFactory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 2, // ⬅️ bump
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS menu_category(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            rid TEXT,
            position INTEGER NOT NULL DEFAULT 0
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS menu_item(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            rid TEXT,
            FOREIGN KEY(category_id) REFERENCES menu_category(id)
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS item_variant(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            price_delta REAL NOT NULL DEFAULT 0,
            rid TEXT,
            FOREIGN KEY(item_id) REFERENCES menu_item(id)
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS dining_table(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            status TEXT NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS ops_journal(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          );
        ''');

        // Optional seed
        await db.insert('menu_category', {
          'name': 'Starters',
          'rid': 'cat_1',
          'position': 1,
        });
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute(
              'ALTER TABLE menu_category ADD COLUMN position INTEGER NOT NULL DEFAULT 0;');
          // Give a stable ordering to existing rows
          await db.execute(
              'UPDATE menu_category SET position = COALESCE(position, id);');
        }
      },
    ),
  );
}
