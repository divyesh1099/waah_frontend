import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' show Value;
import 'dart:convert'; // Import json.decode

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/local/app_db.dart';

class SyncState {
  final bool syncing;
  final int lastSeq;
  final String? lastMessage;
  final String? error;
  const SyncState({
    this.syncing = false,
    this.lastSeq = 0,
    this.lastMessage,
    this.error,
  });

  SyncState copyWith({
    bool? syncing,
    int? lastSeq,
    String? lastMessage,
    String? error,
  }) {
    return SyncState(
      syncing: syncing ?? this.syncing,
      lastSeq: lastSeq ?? this.lastSeq,
      lastMessage: lastMessage,
      error: error,
    );
  }
}

class SyncController extends StateNotifier<SyncState> {
  SyncController(this._ref, this._prefs)
      : super(SyncState(lastSeq: _prefs.getInt(_kLastSeqKey) ?? 0));

  final Ref _ref;
  final SharedPreferences _prefs;

  static const _kLastSeqKey = 'sync_last_seq';

  /// Helper to safely cast payload values with defaults
  T _cast<T>(dynamic val, T defaultValue) {
    if (val == null) return defaultValue;
    if (val is T) return val;
    // Handle number-to-double
    if (T == double && val is num) {
      return val.toDouble() as T;
    }
    // Handle number-to-int
    if (T == int && val is num) {
      return val.toInt() as T;
    }
    return defaultValue;
  }

  Future<void> syncNow() async {
    if (state.syncing) return;
    state = state.copyWith(syncing: true, error: null, lastMessage: null);

    try {
      final client = _ref.read(apiClientProvider);
      final db = _ref.read(localDatabaseProvider);
      final since = _prefs.getInt(_kLastSeqKey) ?? 0;

      final res = await client.syncPull(since: since, limit: 200);
      final events =
          (res['events'] as List?) ?? (res['items'] as List?) ?? const [];
      final last = (res['last_seq'] is int)
          ? res['last_seq'] as int
          : (events.isNotEmpty ? (res['max_seq'] ?? since + events.length) : since);

      await db.transaction(() async {
        for (final ev in events) {
          if (ev is! Map<String, dynamic>) continue;
          final entity = ev['entity'] as String?;

          // --- THIS IS THE FIX ---
          // The payload from the API is a JSON *string*. We must parse it.
          final payloadString = ev['payload'] as String?;
          if (payloadString == null || payloadString.isEmpty) continue;

          final Map<String, dynamic> payload;
          try {
            payload = json.decode(payloadString) as Map<String, dynamic>;
          } catch (e) {
            print('Failed to decode sync payload: $e');
            continue;
          }
          // --- END FIX ---

          final op = ev['op'] as String?;

          if (entity == null || op == null) continue;
          final remoteId = payload['id'] as String?;
          if (remoteId == null) continue;

          if (op == 'DELETE') {
            switch (entity) {
              case 'restaurant_settings':
                await db.deleteRestaurantSettingsByRemoteId(remoteId);
                break;

              case 'menu_category':
                await db.deleteMenuCategoryByRemoteId(remoteId); // cascades items+variants
                break;

              case 'dining_table':
                await db.deleteDiningTableByRemoteId(remoteId);
                break;

              case 'menu_item':
                await db.deleteMenuItemByRemoteId(remoteId);     // cascades variants
                break;

              case 'item_variant':
                await db.deleteItemVariantByRemoteId(remoteId);
                break;
            }
            continue; // done with this event
          }

          switch (entity) {
            case 'restaurant_settings':
              final companion = RestaurantSettingsCompanion(
                remoteId: Value(remoteId),
                tenantId: Value(payload['tenant_id'] as String?),
                branchId: Value(payload['branch_id'] as String?),
                name: Value(_cast(payload['name'], '')),
                logoUrl: Value(payload['logo_url'] as String?),
                address: Value(payload['address'] as String?),
                phone: Value(payload['phone'] as String?),
                gstin: Value(payload['gstin'] as String?),
                fssai: Value(payload['fssai'] as String?),
                printFssaiOnInvoice: Value(_cast(payload['print_fssai_on_invoice'], false)),
                gstInclusiveDefault: Value(_cast(payload['gst_inclusive_default'], true)),
                serviceChargeMode: Value(_cast(payload['service_charge_mode'], 'NONE')),
                serviceChargeValue: Value(_cast(payload['service_charge_value'], 0.0)),
                packingChargeMode: Value(_cast(payload['packing_charge_mode'], 'NONE')),
                packingChargeValue: Value(_cast(payload['packing_charge_value'], 0.0)),
                billingPrinterId: Value(payload['billing_printer_id'] as String?),
                invoiceFooter: Value(payload['invoice_footer'] as String?),
              );
              await db.upsertSettings(companion);
              break;

            case 'menu_category':
              final companion = MenuCategoriesCompanion(
                remoteId: Value(remoteId),
                name: Value(_cast(payload['name'], 'Unnamed Category')),
                position: Value(_cast(payload['position'], 0)),
              );
              await db.upsertCategory(companion);
              break;

            case 'dining_table':
              final companion = DiningTablesCompanion(
                remoteId: Value(remoteId),
                name: Value(_cast(payload['code'], 'T?')), // Map 'code' to 'name'
              );
              await db.upsertDiningTable(companion);
              break;

            case 'menu_item':
              final remoteCatId = payload['category_id'] as String?;
              final localCat = await (db.select(db.menuCategories)
                ..where((t) => t.remoteId.equals(remoteCatId!)))
                  .getSingleOrNull();

              if (localCat != null) {
                final companion = MenuItemsCompanion(
                  remoteId: Value(remoteId),
                  categoryId: Value(localCat.id),
                  name: Value(_cast(payload['name'], 'Unnamed Item')),
                  description: Value(payload['description'] as String?),
                  sku: Value(payload['sku'] as String?),
                  hsn: Value(payload['hsn'] as String?),
                  isActive: Value(_cast(payload['is_active'], true)),
                  stockOut: Value(_cast(payload['stock_out'], false)),
                  taxInclusive: Value(_cast(payload['tax_inclusive'], true)),
                  gstRate: Value(_cast(payload['gst_rate'], 5.0)),
                  kitchenStationId: Value(payload['kitchen_station_id'] as String?),
                  imageUrl: Value(payload['image_url'] as String?),
                );
                await db.upsertMenuItem(companion);
              }
              break;

            case 'item_variant':
              final remoteItemId = payload['item_id'] as String?;
              final localItem = await (db.select(db.menuItems)
                ..where((t) => t.remoteId.equals(remoteItemId!)))
                  .getSingleOrNull();

              if (localItem != null) {
                final companion = ItemVariantsCompanion(
                  remoteId: Value(remoteId),
                  itemId: Value(localItem.id),
                  label: Value(_cast(payload['label'], 'Variant')),
                  mrp: Value(payload['mrp'] as double?),
                  basePrice: Value(_cast(payload['base_price'], 0.0)),
                  isDefault: Value(_cast(payload['is_default'], false)),
                  imageUrl: Value(payload['image_url'] as String?),
                );
                await db.upsertItemVariant(companion);
              }
              break;
          }
        }
      });

      await _prefs.setInt(_kLastSeqKey, last);
      state = state.copyWith(
        syncing: false,
        lastSeq: last,
        lastMessage: 'Synced ${events.length} updates',
      );
    } catch (e, st) {
      print('Sync failed: $e');
      print(st);
      state = state.copyWith(syncing: false, error: e.toString());
    }
  }
}

final syncControllerProvider =
StateNotifierProvider<SyncController, SyncState>((ref) {
  final prefs = ref.watch(prefsProvider);
  return SyncController(ref, prefs);
});


