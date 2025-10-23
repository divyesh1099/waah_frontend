// lib/app/providers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Bare ApiClient that does not depend on auth state (safe to use inside AuthController)
final apiBaseClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: kBaseUrl);
});

/// Auth controller (holds JWT token, login/logout)
final authControllerProvider =
StateNotifierProvider<AuthController, AuthState>((ref) {
  final prefs = ref.watch(prefsProvider);
  return AuthController(ref, prefs);
});

/// Is user authenticated?
final isAuthedProvider = Provider<bool>(
      (ref) => (ref.watch(authControllerProvider).token?.isNotEmpty ?? false),
);

/// Authed ApiClient that carries the latest token (one-way dep on auth state)
final apiClientProvider = Provider<ApiClient>((ref) {
  final token = ref.watch(authControllerProvider.select((s) => s.token));
  final client = ApiClient(baseUrl: kBaseUrl);
  // If you added updateAuthToken(String?) to ApiClient, keep this line:
  client.updateAuthToken(token);
  return client;
});
