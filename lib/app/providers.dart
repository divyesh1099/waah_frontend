// ==============================
// lib/app/providers.dart  (FULL REPLACEMENT)
// ==============================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/local/app_db.dart'; // Drift DB
import 'package:waah_frontend/features/auth/auth_controller.dart';
import '../data/models.dart';
import '../data/repo/orders_repo.dart';
import '../data/repo/settings_repo.dart'; // NOTE: SettingsRepo class only (no provider inside this file)

// ---- Media base ----
final mediaBaseUrlProvider = Provider<String>((ref) => '$kBaseUrl/media/');

// ---- Base URL ----
const kBaseUrl = String.fromEnvironment(
  'WAAH_BASE_URL',
  defaultValue: 'https://waahbackend-production.up.railway.app',
);

// ---- SharedPreferences ----
final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefsProvider overridden in main()');
});

// ---- Dio base options ----
BaseOptions _dioBase(String? token) => BaseOptions(
  baseUrl: kBaseUrl,
  headers: {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  },
  connectTimeout: const Duration(seconds: 8),
  receiveTimeout: const Duration(seconds: 12),
  sendTimeout: const Duration(seconds: 12),
);

// ---- API clients ----
final apiBaseClientProvider = Provider<ApiClient>((ref) {
  final dio = Dio(_dioBase(null));
  final client = ApiClient(dio, baseUrl: kBaseUrl);
  client.updateAuthToken(null);
  return client;
});

final authControllerProvider =
StateNotifierProvider<AuthController, AuthState>((ref) {
  final prefs = ref.watch(prefsProvider);
  return AuthController(ref, prefs);
});

final isAuthedProvider = Provider<bool>((ref) {
  final token = ref.watch(authControllerProvider.select((s) => s.token));
  return token != null && token.isNotEmpty;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final token = ref.watch(authControllerProvider.select((s) => s.token));
  final authNotifier = ref.read(authControllerProvider.notifier);

  final dio = Dio(_dioBase(token));
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (err, handler) {
        if (err.response?.statusCode == 401) authNotifier.logout();
        handler.next(err);
      },
    ),
  );

  final client = ApiClient(
    dio,
    baseUrl: kBaseUrl,
    onUnauthorized: () => authNotifier.logout(),
  );
  client.updateAuthToken(token);
  return client;
});

// ==============================
// Canonical Active Tenant/Branch (NON‑NULLABLE String state)
// ==============================
class _IdNotifier extends StateNotifier<String> {
  _IdNotifier(this._prefs, this._key, String initial) : super(initial);
  final SharedPreferences _prefs;
  final String _key;
  void set(String v) {
    state = v.trim();
    _prefs.setString(_key, state);
  }

  void clear() {
    state = '';
    _prefs.remove(_key);
  }
}

final activeTenantIdProvider =
StateNotifierProvider<_IdNotifier, String>((ref) {
  final prefs = ref.watch(prefsProvider);
  final stored = prefs.getString('active_tenant_id') ?? '';
  final n = _IdNotifier(prefs, 'active_tenant_id', stored);

  // Clear on logout; adopt tenant from /auth/me on login if empty
  ref.listen<AuthState>(authControllerProvider, (prev, next) {
    final prevToken = prev?.token ?? '';
    final nextToken = next.token ?? '';
    if (prevToken.isNotEmpty && nextToken.isEmpty) n.clear();

    final prevTenant = prev?.me?.tenantId ?? '';
    final nextTenant = next.me?.tenantId ?? '';
    if (prevTenant != nextTenant && n.state.isEmpty && nextTenant.isNotEmpty) {
      n.set(nextTenant);
    }
  });

  return n;
});

final activeBranchIdProvider =
StateNotifierProvider<_IdNotifier, String>((ref) {
  final prefs = ref.watch(prefsProvider);
  final stored = prefs.getString('active_branch_id') ?? '';
  final n = _IdNotifier(prefs, 'active_branch_id', stored);

  // Clear on logout; adopt branch from /auth/me on login if empty
  ref.listen<AuthState>(authControllerProvider, (prev, next) {
    final prevToken = prev?.token ?? '';
    final nextToken = next.token ?? '';
    if (prevToken.isNotEmpty && nextToken.isEmpty) n.clear();

    final prevBranch = prev?.me?.branchId ?? '';
    final nextBranch = next.me?.branchId ?? '';
    if (prevBranch != nextBranch && n.state.isEmpty && nextBranch.isNotEmpty) {
      n.set(nextBranch);
    }
  });

  return n;
});

/// Set both tenant and branch from ANY ref (WidgetRef extends Ref).
void setActiveTenantAndBranch(
    Ref ref, {
      required String tenantId,
      String? branchId,
    }) {
  ref.read(activeTenantIdProvider.notifier).set(tenantId);
  final b = (branchId == null || branchId.isEmpty) ? '' : branchId;
  ref.read(activeBranchIdProvider.notifier).set(b);
}

void setActiveTenant(Ref ref, String tenantId) {
  ref.read(activeTenantIdProvider.notifier).set(tenantId);
}

void setActiveBranch(Ref ref, String? branchId) {
  final b = (branchId == null || branchId.isEmpty) ? '' : branchId;
  ref.read(activeBranchIdProvider.notifier).set(b);
}

// ==============================
// Branches (server)
// ==============================
final branchesProvider =
FutureProvider.autoDispose<List<BranchInfo>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final tenantId = ref.watch(activeTenantIdProvider);
  if (tenantId.isEmpty) return <BranchInfo>[];
  return api.fetchBranches(tenantId: tenantId);
});

// ==============================
// SettingsRepo provider (moved here to avoid import cycles)
// ==============================

final settingsRepoProvider = Provider<SettingsRepo>((ref) {
  final client = ref.watch(apiClientProvider);
  final prefs  = ref.watch(prefsProvider);

  final repo = SettingsRepo(client: client, prefs: prefs);
  // initialize with current ids
  repo.setActiveTenant(ref.read(activeTenantIdProvider));
  repo.setActiveBranch(ref.read(activeBranchIdProvider));

  // propagate changes
  ref.listen<String>(activeTenantIdProvider, (prev, next) => repo.setActiveTenant(next));
  ref.listen<String>(activeBranchIdProvider, (prev, next) => repo.setActiveBranch(next));
  return repo;
});

// Restaurant settings stream (from repo)
final restaurantSettingsProvider =
StreamProvider.autoDispose<RestaurantSetting?>((ref) {
  return ref.watch(settingsRepoProvider).watchRestaurantSettings();
});

// ==============================
// Media helpers
// ==============================
String resolveMediaUrl(String? input) {
  if (input == null || input.isEmpty) return '';
  final s = input.trim();
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  if (s.startsWith('/media/')) return '$kBaseUrl$s';
  return '$kBaseUrl/media/$s';
}

final mediaResolverProvider = Provider<Uri Function(String?)>((ref) {
  return (s) => Uri.parse(resolveMediaUrl(s));
});

// ==============================
// Local DB
// ==============================
final localDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

// ==============================
// Orders Repo + streams
// ==============================
final ordersRepoProvider = Provider<OrdersRepo>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final api = ref.watch(apiClientProvider);
  return OrdersRepo(db, api);
});

final ordersLocalProvider =
StreamProvider.autoDispose.family<List<OrderRow>, OrderStatus?>(
        (ref, status) {
      final repo = ref.watch(ordersRepoProvider);

      // fire-and-forget silent refresh
      final tenantId = ref.watch(activeTenantIdProvider);
      final branchId = ref.watch(activeBranchIdProvider);
      repo.refresh(status: status, tenantId: tenantId, branchId: branchId).catchError((_) {});

      return repo.watch(status);
    });

final orderDetailCachedProvider =
FutureProvider.autoDispose.family<OrderDetail, String>((ref, orderId) async {
  final repo = ref.watch(ordersRepoProvider);
  return repo.detail(orderId);
});

// ==============================
// IMPORTANT: Delete any duplicate definitions below if they exist in your copy:
// - activeTenantIdProvider (StateProvider/nullable variants)
// - activeBranchIdProvider (StateProvider/nullable variants)
// - setActiveTenantAndBranch(WidgetRef ...) variant
// Keep ONLY the versions above.
// ==============================



// ==============================
// lib/data/repo/settings_repo.dart  (TOP CLEANUP)
// ==============================
// Replace the header of this file with the following and **REMOVE** any
// `settingsRepoProvider` from this file to avoid cycles.
/*
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';
import 'package:waah_frontend/data/local/app_db.dart' as db;

// NOTE: Do NOT import app/providers.dart here. The provider for SettingsRepo
// now lives in lib/app/providers.dart to break circular imports.
*/

// Then keep the rest of your SettingsRepo class as-is.
