import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

final databaseProvider = Provider<Database>(
      (ref) => throw UnimplementedError('DB not initialized'),
);
