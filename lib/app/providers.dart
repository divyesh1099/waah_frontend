// ==============================
// lib/app/providers.dart  (FULL REPLACEMENT)
// ==============================
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/local/app_db.dart'; // Drift DB
import 'package:waah_frontend/features/auth/auth_controller.dart';
import '../data/models.dart';
import '../data/repo/orders_repo.dart';
import '../data/repo/settings_repo.dart';
import '../features/orders/pending_orders.dart'; // NOTE: SettingsRepo class only (no provider inside this file)

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
class IdNotifier extends StateNotifier<String> {
  IdNotifier(this._prefs, this._key, String initial) : super(initial);
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
StateNotifierProvider<IdNotifier, String>((ref) {
  final prefs = ref.watch(prefsProvider);
  final stored = prefs.getString('active_tenant_id') ?? '';
  final n = IdNotifier(prefs, 'active_tenant_id', stored);

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
StateNotifierProvider<IdNotifier, String>((ref) {
  final prefs = ref.watch(prefsProvider);
  final stored = prefs.getString('active_branch_id') ?? '';
  final n = IdNotifier(prefs, 'active_branch_id', stored);

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
// Canonical branches stream from the offline-first repo
final branchesStreamProvider =
StreamProvider.autoDispose<List<BranchInfo>>((ref) {
  return ref.watch(settingsRepoProvider).watchBranches();
});
// NEW: Filter state for the main Orders list
class OrderFilterState {
  final OrderStatus? status;
  final DateTime? startDt;
  final DateTime? endDt;

  OrderFilterState({this.status, this.startDt, this.endDt});

  OrderFilterState copyWith({
    OrderStatus? status,
    DateTime? startDt,
    DateTime? endDt,
  }) {
    return OrderFilterState(
      status: status ?? this.status,
      startDt: startDt ?? this.startDt,
      endDt: endDt ?? this.endDt,
    );
  }
}

class OrderFilterNotifier extends StateNotifier<OrderFilterState> {
  OrderFilterNotifier() : super(OrderFilterState());

  void setStatus(OrderStatus? status) {
    state = state.copyWith(status: status);
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(startDt: start, endDt: end);
  }

  void clear() {
    state = OrderFilterState();
  }
}

final orderFilterProvider =
StateNotifierProvider<OrderFilterNotifier, OrderFilterState>(
      (ref) => OrderFilterNotifier(),
);

// Server orders page (filter by active tenant/branch)
// Server orders page (returns List<Order> by unwrapping PageResult)
// UPDATED: This provider now watches the filter state
final ordersFutureProvider =
FutureProvider.autoDispose<List<Order>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final tenantId = ref.watch(activeTenantIdProvider);
  final branchId = ref.watch(activeBranchIdProvider);
  final filter = ref.watch(orderFilterProvider); // WATCH the filter

  // Your ApiClient returns a PageResult<Order>
  final page = await api.fetchOrders(
    page: 1,
    size: 100,
    tenantId: tenantId, // Pass tenant
    branchId: branchId, // Pass branch
    status: filter.status, // Pass filter status
    startDt: filter.startDt, // Pass filter start date
    endDt: filter.endDt, // Pass filter end date
  );

  // If your PageResult uses a different field than `items`,
  // change `items` to whatever it is (e.g. `data`).
  return page.items;
});

// NEW: Filter state for a standalone KOT list
class KotFilterState {
  final KOTStatus? status;
  final DateTime? startDt;
  final DateTime? endDt;

  KotFilterState({this.status, this.startDt, this.endDt});

  KotFilterState copyWith({
    KOTStatus? status,
    DateTime? startDt,
    DateTime? endDt,
  }) {
    return KotFilterState(
      status: status ?? this.status,
      startDt: startDt ?? this.startDt,
      endDt: endDt ?? this.endDt,
    );
  }
}

class KotFilterNotifier extends StateNotifier<KotFilterState> {
  KotFilterNotifier() : super(KotFilterState());

  void setStatus(KOTStatus? status) {
    state = state.copyWith(status: status);
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(startDt: start, endDt: end);
  }

  void clear() {
    state = KotFilterState();
  }
}

final kotFilterProvider =
StateNotifierProvider<KotFilterNotifier, KotFilterState>(
      (ref) => KotFilterNotifier(),
);

// NEW: A filterable provider for KOTs, separate from the one in kot_page.dart
final filteredKotTicketsProvider =
FutureProvider.autoDispose<List<KitchenTicket>>((ref) {
  final api = ref.watch(apiClientProvider);
  final tenantId = ref.watch(activeTenantIdProvider);
  final branchId = ref.watch(activeBranchIdProvider);
  final filter = ref.watch(kotFilterProvider); // WATCH the filter

  return api.fetchKitchenTickets(
    tenantId: tenantId,
    branchId: branchId,
    status: filter.status,
    startDt: filter.startDt,
    endDt: filter.endDt,
  );
});

// Persisted “device id” for syncPush
final deviceIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(prefsProvider);
  final existing = prefs.getString('device_id');
  if (existing != null && existing.isNotEmpty) return existing;

  final r = Random();
  final id = 'dev-${DateTime.now().millisecondsSinceEpoch}-${r.nextInt(1 << 32)}';
  prefs.setString('device_id', id);
  return id;
});
// Count of "queued ops" (use pending placeholders as the proxy)
final queuedOpsCountProvider = Provider<int?>((ref) {
  final pend = ref.watch(pendingOrdersProvider);
  return pend.length;
});
// TODO: Replace with your real queued ops (coalesced) list.
final queueOpsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  // Example: return ref.read(syncQueueProvider).coalescedOps(onlyOpen: ...);
  return const <Map<String, dynamic>>[];
});

// Push actions used by the diag buttons
final queuePusherProvider = Provider<QueuePusher>((ref) => QueuePusher(ref));

class QueuePusher {
  QueuePusher(this._ref);
  final Ref _ref;

  Future<void> pushAllNow()  async => _push(onlyOpen: false);
  Future<void> pushOpenOnly() async => _push(onlyOpen: true);

  Future<void> _push({required bool onlyOpen}) async {
    final api       = _ref.read(apiClientProvider);
    final deviceId  = _ref.read(deviceIdProvider);

    // If you can filter OPEN vs ALL, do it in the provider that builds ops.
    // For the stub we just read whatever is available.
    final ops = _ref.read(queueOpsProvider);

    await api.syncPush(deviceId: deviceId, ops: ops);

    // Refresh + reconcile placeholders using the fresh server page
    final live    = await _ref.read(ordersFutureProvider.future);
    final pending = _ref.read(pendingOrdersProvider.notifier);
    pending.reconcileWithServer(live);
    pending.reconcileLooseWithServer(live, skew: const Duration(minutes: 3));
  }
}

