// lib/data/local/connection.dart
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:drift/native.dart' as dn;
import 'package:drift/web.dart' as dw;

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

LazyDatabase openConnection() {
  if (kIsWeb) {
    return LazyDatabase(() async => dw.WebDatabase('waah_pos'));
  }
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'waah_pos.db'));
    return dn.NativeDatabase(file);
  });
}
