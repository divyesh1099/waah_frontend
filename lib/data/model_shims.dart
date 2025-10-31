// -----------------------------------------------------------------------------
// File: lib/data/model_shims.dart
// Purpose: Add missing `toJson` and `copyWith` for your core models WITHOUT
//          touching the actual model classes. Fixes:
//          - "The method 'toJson' isn't defined for the type 'BranchInfo'"
//          - "The method 'copyWith' isn't defined for the type 'DiningTable'"
//          - (Also provides Printer.copyWith / toJson if needed elsewhere.)
// -----------------------------------------------------------------------------

import 'package:waah_frontend/data/models.dart';

import 'api_client.dart';

extension BranchInfoShims on BranchInfo {
  Map<String, dynamic> toJson() => {
    // include both camelCase and snake_case for broader compat
    'id': id,
    'tenantId': tenantId,
    'tenant_id': tenantId,
    'name': name,
    'phone': phone,
    'gstin': gstin,
    'address': address,
    'stateCode': stateCode,
    'state_code': stateCode,
  };

  BranchInfo copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? phone,
    String? gstin,
    String? address,
    String? stateCode,
  }) => BranchInfo(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    gstin: gstin ?? this.gstin,
    address: address ?? this.address,
    stateCode: stateCode ?? this.stateCode,
  );
}

extension DiningTableShims on DiningTable {
  DiningTable copyWith({
    String? id,
    String? branchId,
    String? code,
    String? zone,
    int? seats,
  }) => DiningTable(
    id: id ?? this.id,
    branchId: branchId ?? this.branchId,
    code: code ?? this.code,
    zone: zone ?? this.zone,
    seats: seats ?? this.seats,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'branchId': branchId,
    'branch_id': branchId,
    'code': code,
    'zone': zone,
    'seats': seats,
  };
}

extension PrinterShims on Printer {
  Printer copyWith({
    String? id,
    String? tenantId,
    String? branchId,
    String? name,
    PrinterType? type,
    String? connectionUrl,
    bool? isDefault,
    bool? cashDrawerEnabled,
    String? cashDrawerCode,
  }) => Printer(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    branchId: branchId ?? this.branchId,
    name: name ?? this.name,
    type: type ?? this.type,
    connectionUrl: connectionUrl ?? this.connectionUrl,
    isDefault: isDefault ?? this.isDefault,
    cashDrawerEnabled: cashDrawerEnabled ?? this.cashDrawerEnabled,
    cashDrawerCode: cashDrawerCode ?? this.cashDrawerCode,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenantId': tenantId,
    'tenant_id': tenantId,
    'branchId': branchId,
    'branch_id': branchId,
    'name': name,
    'type': type.name,
    'connectionUrl': connectionUrl,
    'connection_url': connectionUrl,
    'isDefault': isDefault,
    'is_default': isDefault,
    'cashDrawerEnabled': cashDrawerEnabled,
    'cash_drawer_enabled': cashDrawerEnabled,
    'cashDrawerCode': cashDrawerCode,
    'cash_drawer_code': cashDrawerCode,
  };
}

// -----------------------------------------------------------------------------
// File: lib/data/api_shims.dart   (OPTIONAL)
// Purpose: Provide no‑op/offline stubs for API methods referenced by UI layers
//          but not implemented on ApiClient yet. Fixes e.g.:
//          - "The method 'createDiningTable' isn't defined for the type 'ApiClient'"
// NOTE: These are SAFE stubs; wire them to real endpoints later.
// -----------------------------------------------------------------------------


extension OfflineSettingsApiShims on ApiClient {
  // If your UI calls: api.createDiningTable(table), this stub will satisfy the type.
  Future<DiningTable> createDiningTable(DiningTable t) async {
    return t; // no‑op for offline; UI already updates via repo optimistically
  }

  Future<DiningTable> updateDiningTable(DiningTable t) async {
    return t; // no‑op
  }

  Future<void> deleteDiningTable(String id) async {
    // no‑op
  }
}

// -----------------------------------------------------------------------------
// PATCH: lib/data/repo/settings_repo.dart (minimal edits)
// Purpose: Eliminate List<Object>→List<T> typing issues by forcing concrete types
//          when emitting to Streams / reading JSON.
// How: 1) Add the shim import. 2) Apply the replacements below.
// -----------------------------------------------------------------------------
/*
1) ADD IMPORT near the top (below other imports):

   import 'package:waah_frontend/data/model_shims.dart';

2) REPLACE these lines (exact spots are marked in your file):

   // A. watchBranches()
   scheduleMicrotask(() => _branchesCtl.add(List.unmodifiable(_branches)));
   // with →
   scheduleMicrotask(() => _branchesCtl.add(List<BranchInfo>.from(_branches, growable: false)));

   // B. watchTables(String branchId)
   scheduleMicrotask(() => ctl.add(List.unmodifiable(cached)));
   // with →
   scheduleMicrotask(() => ctl.add(List<DiningTable>.from(cached, growable: false)));

   // C. _loadCachedTables(String branchId)
   items = (jsonDecode(raw) as List)
       .map((e) => _tableFromMap(Map<String, dynamic>.from(e)))
       .toList(growable: false);
   // with →
   items = (jsonDecode(raw) as List)
       .map((e) => _tableFromMap(Map<String, dynamic>.from(e)))
       .toList(growable: false)
       .cast<DiningTable>();
   ...
   _tablesCtlByBranch.putIfAbsent(branchId, () => StreamController<List<DiningTable>>.broadcast())
       .add(List.unmodifiable(items));
   // with →
   _tablesCtlByBranch.putIfAbsent(branchId, () => StreamController<List<DiningTable>>.broadcast())
       .add(List<DiningTable>.from(items, growable: false));

   // D. watchPrinters(String tenantId, String branchId)
   scheduleMicrotask(() => ctl.add(List.unmodifiable(items)));
   // with →
   scheduleMicrotask(() => ctl.add(List<Printer>.from(items, growable: false)));

   // E. refreshPrinters(...)
   _printersCtlMap[key]?.add(List.unmodifiable(cached));
   // with →
   _printersCtlMap[key]?.add(List<Printer>.from(cached, growable: false));

   // F. _loadCachedPrinters(String tenantId, String branchId)
   items = (jsonDecode(raw) as List)
       .map((e) => _printerFromMap(Map<String, dynamic>.from(e)))
       .toList(growable: false);
   // with →
   items = (jsonDecode(raw) as List)
       .map((e) => _printerFromMap(Map<String, dynamic>.from(e)))
       .toList(growable: false)
       .cast<Printer>();
   ...
   _printersCtlMap.putIfAbsent(key, () => StreamController<List<Printer>>.broadcast())
       .add(List.unmodifiable(items));
   // with →
   _printersCtlMap.putIfAbsent(key, () => StreamController<List<Printer>>.broadcast())
       .add(List<Printer>.from(items, growable: false));
*/
