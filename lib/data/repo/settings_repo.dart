// lib/data/repo/settings_repo.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/data/local/app_db.dart';

// Provider to access this repository
final settingsRepoProvider = Provider<SettingsRepo>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return SettingsRepo(db);
});

class SettingsRepo {
  SettingsRepo(this._db);
  final AppDatabase _db;

  // This is now an OFFLINE-FIRST stream.
  // The UI will read from this.
  Stream<RestaurantSetting?> watchRestaurantSettings() {
    return _db.watchSettings();
  }
}