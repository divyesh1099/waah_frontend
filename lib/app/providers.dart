import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/local/app_db.dart'; // Import Drift DB
import 'package:waah_frontend/data/repo/settings_repo.dart'; // Import SettingsRepo
import 'package:waah_frontend/features/auth/auth_controller.dart';
import '../data/models.dart';
// We no longer import FilePicker here, it's in the repo

final mediaBaseUrlProvider = Provider<String>((ref) => '$kBaseUrl/media/');

/// ---- Base URL (edit if you use another env) ----
const kBaseUrl = String.fromEnvironment(
  'WAAH_BASE_URL',
  defaultValue: 'https://waahbackend-production.up.railway.app',
);

/// SharedPreferences as a provider
final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefsProvider overridden in main()');
});

/// Bare ApiClient (no auth)
final apiBaseClientProvider = Provider<ApiClient>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: kBaseUrl,
      headers: const {'Content-Type': 'application/json'},
    ),
  );
  final client = ApiClient(dio, baseUrl: kBaseUrl);
  client.updateAuthToken(null);
  return client;
});

/// Auth controller (holds JWT token, login/logout)
final authControllerProvider =
StateNotifierProvider<AuthController, AuthState>((ref) {
  final prefs = ref.watch(prefsProvider);
  return AuthController(ref, prefs);
});

/// Is user authenticated?
final isAuthedProvider = Provider<bool>((ref) {
  final token = ref.watch(authControllerProvider).token;
  return token != null && token.isNotEmpty;
});

/// Authed ApiClient that carries the latest token.
final apiClientProvider = Provider<ApiClient>((ref) {
  final token = ref.watch(authControllerProvider.select((s) => s.token));
  final authNotifier = ref.read(authControllerProvider.notifier);

  final dio = Dio(
    BaseOptions(
      baseUrl: kBaseUrl,
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (err, handler) {
        if (err.response?.statusCode == 401) {
          authNotifier.logout();
        }
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

/// ===== Persisted tenant/branch selection =====

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

  ref.listen<AuthState>(authControllerProvider, (prev, next) {
    final prevToken = prev?.token ?? '';
    final nextToken = next.token ?? '';

    if (prevToken.isNotEmpty && nextToken.isEmpty) {
      n.clear(); // logout => clear tenant
    }

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

  ref.listen<AuthState>(authControllerProvider, (prev, next) {
    final prevToken = prev?.token ?? '';
    final nextToken = next.token ?? '';

    if (prevToken.isNotEmpty && nextToken.isEmpty) {
      n.clear();
    }

    final prevBranch = prev?.me?.branchId ?? '';
    final nextBranch = next.me?.branchId ?? '';
    if (prevBranch != nextBranch && n.state.isEmpty && nextBranch.isNotEmpty) {
      n.set(nextBranch);
    }
  });

  return n;
});

/// All branches for the active tenant (used by branch picker UI)
/// This remains a FutureProvider as it's not core data needed offline
/// and is only used on the branch selection screen.
final branchesProvider = FutureProvider.autoDispose<List<BranchInfo>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final tenantId = ref.watch(activeTenantIdProvider);
  if (tenantId.isEmpty) return <BranchInfo>[];
  return api.fetchBranches(tenantId: tenantId);
});

/// ===== REFACTORED FOR OFFLINE-FIRST =====
/// Restaurant settings (branding) for active tenant+branch
/// This provider now reads from the local DB stream.
/// It will load instantly and update automatically when a sync happens.
final restaurantSettingsProvider =
StreamProvider.autoDispose<RestaurantSetting?>((ref) {
  // Watch the repo, which watches the local DB
  return ref.watch(settingsRepoProvider).watchRestaurantSettings();
});

/// Build a full URL for images that may come as absolute, relative, or /media/…
/// (I am re-adding this function which I mistakenly removed)
String resolveMediaUrl(String? input) {
  if (input == null || input.isEmpty) return '';
  final s = input.trim();
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  if (s.startsWith('/media/')) return '$kBaseUrl$s';
  // fallback: your generic media base
  return '$kBaseUrl/media/$s';
}

/// Expose the resolver in DI for widgets that prefer reading from ref
/// (I am re-adding this provider which I mistakenly removed)
final mediaResolverProvider = Provider<Uri Function(String?)>((ref) {
  return (s) => Uri.parse(resolveMediaUrl(s));
});
