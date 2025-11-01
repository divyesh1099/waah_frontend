// ==============================
// lib/data/repo/settings_repo.dart
// ==============================
// Offline-first SettingsRepo with SharedPreferences cache only (no network calls).
// Safe compile: removed any reference to non-existent ApiClient methods like fetchTables.
// You can wire real API syncs later without breaking the app.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';
import 'package:waah_frontend/data/local/app_db.dart' as db;


// ---------------- Repo ----------------
class SettingsRepo {
  SettingsRepo({required ApiClient client, required SharedPreferences prefs})
      : _client = client, // ignore: unused_field
        _prefs  = prefs {
    _loadCachedBranches();
    _loadCachedTables(_branchId);
    _loadCachedPrinters(_tenantId, _branchId);
    _loadCachedRestaurantSettings(_tenantId);
  }

  final ApiClient _client; // kept for future wiring
  final SharedPreferences _prefs;

  String _tenantId = '';
  String _branchId = '';

  // Branches
  final _branchesCtl = StreamController<List<BranchInfo>>.broadcast();
  List<BranchInfo> _branches = const [];

  // Tables (per-branch)
  final Map<String, StreamController<List<DiningTable>>> _tablesCtlByBranch = {};
  final Map<String, List<DiningTable>> _tablesByBranch = {};

  // Printers (per tenant+branch)
  final Map<String, StreamController<List<Printer>>> _printersCtlMap = {};
  final Map<String, List<Printer>> _printersMap = {};

  // Restaurant settings (per-tenant)
  final _restCtl = StreamController<db.RestaurantSetting?>.broadcast();
  db.RestaurantSetting? _rest;

  String _pkPrinters(String tenantId, String branchId) => 'printers:$tenantId:$branchId';
  String _pkTables(String branchId) => 'tables:$branchId';
  String _pkBranches(String tenantId) => 'branches:$tenantId';
  String _pkRestaurant(String tenantId) => 'restaurant_settings:$tenantId';

  // Active IDs
  void setActiveTenant(String id) {
    _tenantId = id;
    _loadCachedBranches();
    _loadCachedRestaurantSettings(id);
    if (_tenantId.isNotEmpty) {
      // fire-and-forget server pull to hydrate cache
      refreshBranches(_tenantId);
    }
    if (_branchId.isNotEmpty) {
      _loadCachedPrinters(_tenantId, _branchId);
    }
  }

  void setActiveBranch(String id) {
    _branchId = id;
    _loadCachedTables(id);
    _loadCachedPrinters(_tenantId, id);
  }

  // -------- Branches --------
  Stream<List<BranchInfo>> watchBranches() {
    scheduleMicrotask(() => _branchesCtl.add(List.unmodifiable(_branches)));
    return _branchesCtl.stream;
  }

  Future<void> refreshBranches(String tenantId) async {
    try {
      // fetch from server if possible
      final list = await _client.fetchBranches(tenantId: tenantId);
      _emitBranches(list);
      _persistBranches();
    } catch (_) {
      // offline / server error → keep whatever we have
      _emitBranches(_branches);
    }
  }


  Future<void> createBranchOptimistic(BranchInfo b) async {
    _assertTenant(b.tenantId);
    _emitBranches([..._branches, b]);
    _persistBranches();
    // TODO: push to server when API is available
  }

  Future<void> updateBranchOptimistic(BranchInfo b) async {
    _assertTenant(b.tenantId);
    _emitBranches(_branches.map((x) => x.id == b.id ? b : x).toList(growable: false));
    _persistBranches();
    // TODO: push to server when API is available
  }

  Future<void> deleteBranchOptimistic(String id) async {
    _emitBranches(_branches.where((x) => x.id != id).toList(growable: false));
    _persistBranches();
    // TODO: push to server when API is available
  }

  void _emitBranches(List<BranchInfo> items) {
    _branches = List.unmodifiable(items);
    _branchesCtl.add(_branches);
  }

  void _persistBranches() {
    if (_tenantId.isEmpty) return;
    final arr = _branches.map(_branchToMap).toList(growable: false);
    _prefs.setString(_pkBranches(_tenantId), jsonEncode(arr));
  }

  void _loadCachedBranches() {
    if (_tenantId.isEmpty) { _emitBranches(const []); return; }
    final raw = _prefs.getString(_pkBranches(_tenantId));
    if (raw == null || raw.isEmpty) { _emitBranches(const []); return; }
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => _branchFromMap(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      _emitBranches(list);
    } catch (_) {
      _emitBranches(const []);
    }
  }

  // -------- Tables --------
  Stream<List<DiningTable>> watchTables(String branchId) {
    final ctl = _tablesCtlByBranch.putIfAbsent(branchId, () => StreamController<List<DiningTable>>.broadcast());
    final cached = _tablesByBranch[branchId] ?? const <DiningTable>[];
    scheduleMicrotask(() => ctl.add(List.unmodifiable(cached)));
    return ctl.stream;
  }

  Future<void> refreshTables(String branchId) async {
    // Offline-first (cache only). Wire server later if needed.
    final cached = _tablesByBranch[branchId] ?? const <DiningTable>[];
    _tablesCtlByBranch[branchId]?.add(List.unmodifiable(cached));
  }

  Future<void> createTableOptimistic(String branchId, DiningTable t) async {
    final list = [...(_tablesByBranch[branchId] ?? const <DiningTable>[]), t];
    _tablesByBranch[branchId] = List.unmodifiable(list);
    _tablesCtlByBranch[branchId]?.add(_tablesByBranch[branchId]!);
    _persistTables(branchId);
    // TODO: push to server when API is available
  }

  Future<void> updateTableOptimistic(String branchId, DiningTable t) async {
    final list = (_tablesByBranch[branchId] ?? const <DiningTable>[])
        .map((x) => x.id == t.id ? t : x)
        .toList(growable: false);
    _tablesByBranch[branchId] = List.unmodifiable(list);
    _tablesCtlByBranch[branchId]?.add(_tablesByBranch[branchId]!);
    _persistTables(branchId);
    // TODO: push to server when API is available
  }

  Future<void> deleteTableOptimistic(String branchId, String id) async {
    final list = (_tablesByBranch[branchId] ?? const <DiningTable>[])
        .where((x) => x.id != id)
        .toList(growable: false);
    _tablesByBranch[branchId] = List.unmodifiable(list);
    _tablesCtlByBranch[branchId]?.add(_tablesByBranch[branchId]!);
    _persistTables(branchId);
    // TODO: push to server when API is available
  }

  void _loadCachedTables(String branchId) {
    if (branchId.isEmpty) return;
    final raw = _prefs.getString(_pkTables(branchId));
    List<DiningTable> items = const [];
    if (raw != null && raw.isNotEmpty) {
      try {
        items = (jsonDecode(raw) as List)
            .map((e) => _tableFromMap(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      } catch (_) {}
    }
    _tablesByBranch[branchId] = items;
    _tablesCtlByBranch.putIfAbsent(branchId, () => StreamController<List<DiningTable>>.broadcast())
        .add(List.unmodifiable(items));
  }

  void _persistTables(String branchId) {
    final items = _tablesByBranch[branchId] ?? const <DiningTable>[];
    final arr = items.map(_tableToMap).toList(growable: false);
    _prefs.setString(_pkTables(branchId), jsonEncode(arr));
  }

  // -------- Printers --------
  Stream<List<Printer>> watchPrinters(String tenantId, String branchId) {
    final key = _pkPrinters(tenantId, branchId);
    final ctl = _printersCtlMap.putIfAbsent(key, () => StreamController<List<Printer>>.broadcast());
    final items = _printersMap[key] ?? const <Printer>[];
    scheduleMicrotask(() => ctl.add(List.unmodifiable(items)));
    return ctl.stream;
  }

  Future<void> refreshPrinters({required String tenantId, required String branchId}) async {
    final key = _pkPrinters(tenantId, branchId);
    final cached = _printersMap[key] ?? const <Printer>[];
    _printersCtlMap[key]?.add(List.unmodifiable(cached));
  }

  Future<void> createPrinterOptimistic(String tenantId, String branchId, Printer p) async {
    final key = _pkPrinters(tenantId, branchId);
    final list = [...(_printersMap[key] ?? const <Printer>[]), p];
    _emitPrinters(key, list);
    _persistPrinters(key);
    // TODO: push to server when API is available
  }

  Future<void> updatePrinterOptimistic(String tenantId, String branchId, Printer p) async {
    final key = _pkPrinters(tenantId, branchId);
    final list = (_printersMap[key] ?? const <Printer>[])
        .map((x) => x.id == p.id ? p : x)
        .toList(growable: false);
    _emitPrinters(key, list);
    _persistPrinters(key);
    // TODO: push to server when API is available
  }

  Future<void> deletePrinterOptimistic(String tenantId, String branchId, String id) async {
    final key = _pkPrinters(tenantId, branchId);
    final list = (_printersMap[key] ?? const <Printer>[])
        .where((x) => x.id != id)
        .toList(growable: false);
    _emitPrinters(key, list);
    _persistPrinters(key);
    // TODO: push to server when API is available
  }

  void _emitPrinters(String key, List<Printer> items) {
    final list = List<Printer>.unmodifiable(items);
    _printersMap[key] = list;
    _printersCtlMap[key]?.add(list);
  }

  void _persistPrinters(String key) {
    final arr = (_printersMap[key] ?? const <Printer>[])
        .map(_printerToMap)
        .toList(growable: false);
    _prefs.setString(key, jsonEncode(arr));
  }

  void _loadCachedPrinters(String tenantId, String branchId) {
    if (tenantId.isEmpty || branchId.isEmpty) return;
    final key = _pkPrinters(tenantId, branchId);
    final raw = _prefs.getString(key);
    List<Printer> items = const [];
    if (raw != null && raw.isNotEmpty) {
      try {
        items = (jsonDecode(raw) as List)
            .map((e) => _printerFromMap(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      } catch (_) {}
    }
    _printersMap[key] = items;
    _printersCtlMap.putIfAbsent(key, () => StreamController<List<Printer>>.broadcast())
        .add(List.unmodifiable(items));
  }

  // -------- Restaurant Settings --------
  Stream<db.RestaurantSetting?> watchRestaurantSettings() {
    scheduleMicrotask(() => _restCtl.add(_rest));
    return _restCtl.stream;
  }

  Future<void> setRestaurantSettingsOptimistic(db.RestaurantSetting? s) async {
    _rest = s;
    _restCtl.add(_rest);
    _persistRestaurantSettings();
  }

  void _loadCachedRestaurantSettings(String tenantId) {
    if (tenantId.isEmpty) { _rest = null; _restCtl.add(_rest); return; }
    final raw = _prefs.getString(_pkRestaurant(tenantId));
    if (raw == null || raw.isEmpty) { _rest = null; _restCtl.add(_rest); return; }
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      _rest = db.RestaurantSetting.fromJson(map); // if available
    } catch (_) {
      _rest = null;
    }
    _restCtl.add(_rest);
  }

  void _persistRestaurantSettings() {
    if (_tenantId.isEmpty) return;
    if (_rest == null) { _prefs.remove(_pkRestaurant(_tenantId)); return; }
    try {
      final jsonMap = (_rest as dynamic).toJson?.call();
      if (jsonMap is Map<String, dynamic>) {
        _prefs.setString(_pkRestaurant(_tenantId), jsonEncode(jsonMap));
      }
    } catch (_) {
      // If your model lacks toJson, store a subset here as Map manually.
    }
  }

  // -------- Offline queue (stub) --------
  final List<Map<String, dynamic>> _opQueue = [];
  Future<void> autoFlushOps() async { _opQueue.clear(); }

  // -------- Utils --------
  void _assertTenant(String t) {
    if (_tenantId.isEmpty || _tenantId != t) {
      if (kDebugMode) print('[SettingsRepo] Warning: tenant mismatch active=$_tenantId arg=$t');
    }
  }

  // -------- Lightweight mappers (no model .toJson/.fromJson required) --------
  Map<String, dynamic> _branchToMap(BranchInfo b) => {
    'id': b.id,
    'tenant_id': b.tenantId,
    'name': b.name,
    'phone': b.phone,
    'gstin': b.gstin,
    'address': b.address,
    'state_code': b.stateCode,
  };

  BranchInfo _branchFromMap(Map<String, dynamic> m) => BranchInfo(
    id: (m['id'] ?? '') as String,
    tenantId: (m['tenant_id'] ?? '') as String,
    name: (m['name'] ?? '') as String,
    phone: (m['phone'] as String?)?.trim().isEmpty == true ? null : m['phone'] as String?,
    gstin: (m['gstin'] as String?)?.trim().isEmpty == true ? null : m['gstin'] as String?,
    address: (m['address'] as String?)?.trim().isEmpty == true ? null : m['address'] as String?,
    stateCode: (m['state_code'] as String?)?.trim().isEmpty == true ? null : m['state_code'] as String?,
  );

  Map<String, dynamic> _tableToMap(DiningTable t) => {
    'id': t.id,
    'branch_id': t.branchId,
    'code': t.code,
    'zone': t.zone,
    'seats': t.seats,
  };

  DiningTable _tableFromMap(Map<String, dynamic> m) => DiningTable(
    id: (m['id'] ?? '') as String,
    branchId: (m['branch_id'] ?? '') as String,
    code: (m['code'] ?? '') as String,
    zone: (m['zone'] as String?)?.trim().isEmpty == true ? null : m['zone'] as String?,
    seats: (m['seats'] is int)
        ? m['seats'] as int
        : (m['seats'] is String ? int.tryParse(m['seats'] as String) : null),
  );

  Map<String, dynamic> _printerToMap(Printer p) => {
    'id': p.id,
    'tenant_id': p.tenantId,
    'branch_id': p.branchId,
    'name': p.name,
    'type': p.type.name,
    'connection_url': p.connectionUrl,
    'is_default': p.isDefault,
    'cash_drawer_enabled': p.cashDrawerEnabled,
    'cash_drawer_code': p.cashDrawerCode,
  };

  Printer _printerFromMap(Map<String, dynamic> m) {
    final typeName = (m['type'] ?? 'BILLING') as String;
    final type = PrinterType.values.where((e) => e.name == typeName).isNotEmpty
        ? PrinterType.values.firstWhere((e) => e.name == typeName)
        : PrinterType.BILLING;
    return Printer(
      id: (m['id'] ?? '') as String,
      tenantId: (m['tenant_id'] ?? '') as String,
      branchId: (m['branch_id'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      type: type,
      connectionUrl: (m['connection_url'] as String?)?.trim().isEmpty == true ? null : m['connection_url'] as String?,
      isDefault: (m['is_default'] ?? false) as bool,
      cashDrawerEnabled: (m['cash_drawer_enabled'] ?? false) as bool,
      cashDrawerCode: (m['cash_drawer_code'] as String?)?.trim().isEmpty == true ? null : m['cash_drawer_code'] as String?,
    );
  }
}
