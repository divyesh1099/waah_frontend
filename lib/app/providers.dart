// lib/app/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/features/auth/auth_controller.dart';

/// ---- Base URL (edit if you use another env) ----
const kBaseUrl = String.fromEnvironment(
  'WAAH_BASE_URL',
  defaultValue: 'https://waahbackend-production.up.railway.app',
);

/// SharedPreferences as a provider
final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefsProvider overridden in main()');
});

/// Bare ApiClient that does NOT depend on auth state.
/// Used by AuthController.login() before we even have a token.
final apiBaseClientProvider = Provider<ApiClient>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: kBaseUrl,
      headers: const {
        'Content-Type': 'application/json',
      },
    ),
  );

  final client = ApiClient(
    dio,
    baseUrl: kBaseUrl,
    // no onUnauthorized -> we don't want to auto-logout here
  );

  // make sure internal http.* helpers don't try to send a stale token
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
/// Rebuilds whenever the token changes.
final apiClientProvider = Provider<ApiClient>((ref) {
  // current token from auth state
  final token = ref.watch(
    authControllerProvider.select((s) => s.token),
  );

  // we'll need this to force logout if backend says 401
  final authNotifier = ref.read(authControllerProvider.notifier);

  final dio = Dio(
    BaseOptions(
      baseUrl: kBaseUrl,
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      },
    ),
  );

  // Any 401 that comes back from Dio-based calls will trigger logout.
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (err, handler) {
        final status = err.response?.statusCode;
        if (status == 401) {
          authNotifier.logout();
        }
        handler.next(err);
      },
    ),
  );

  // Build the ApiClient wrapper we use everywhere else.
  final client = ApiClient(
    dio,
    baseUrl: kBaseUrl,
    onUnauthorized: () {
      // This is called by the http.* code paths (_get/_post/etc)
      // when they see a 401. We mirror Dio's behavior.
      authNotifier.logout();
    },
  );

  // CRUCIAL:
  // Tell ApiClient about the token so that its http.* helpers
  // (which use `http` package, not Dio) will also send Authorization.
  client.updateAuthToken(token);

  return client;
});
