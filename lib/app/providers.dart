// lib/app/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/local/app_db.dart'; // Drift DB
import 'package:waah_frontend/data/repo/settings_repo.dart';
import 'package:waah_frontend/features/auth/auth_controller.dart';
import '../data/models.dart';

final mediaBaseUrlProvider = Provider<String>((ref) => '$kBaseUrl/media/');

const kBaseUrl = String.fromEnvironment(
  'WAAH_BASE_URL',
  defaultValue: 'https://waahbackend-production.up.railway.app',
);

final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefsProvider overridden in main()');
});

BaseOptions _dioBase(String? token) => BaseOptions(
  baseUrl: kBaseUrl,
  headers: {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  },
  // 🔥 Make networking snappy and fail fast
  connectTimeout: const Duration(seconds: 8),
  receiveTimeout: const Duration(seconds: 12),
  sendTimeout: const Duration(seconds: 12),
);

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

final activeTenantIdProvider = StateNotifierProvider<_IdNotifier, String>((ref) {
  final prefs = ref.watch(prefsProvider);
  final stored = prefs.getString('active_tenant_id') ?? '';
  final n = _IdNotifier(prefs, 'active_tenant_id', stored);

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

final branchesProvider =
FutureProvider.autoDispose<List<BranchInfo>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final tenantId = ref.watch(activeTenantIdProvider);
  if (tenantId.isEmpty) return <BranchInfo>[];
  return api.fetchBranches(tenantId: tenantId);
});

final restaurantSettingsProvider =
StreamProvider.autoDispose<RestaurantSetting?>((ref) {
  return ref.watch(settingsRepoProvider).watchRestaurantSettings();
});

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

final localDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});
