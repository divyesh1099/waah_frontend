import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';

/// ---------------------------------------------------------------------------
/// Auth state exposed to rest of app
/// ---------------------------------------------------------------------------

class AuthState {
  final String? token;
  final bool loading;
  final String? error;
  final MeInfo? me; // current user profile + roles + permissions

  const AuthState({
    this.token,
    this.loading = false,
    this.error,
    this.me,
  });

  AuthState copyWith({
    String? token,
    bool? loading,
    String? error,
    MeInfo? me,
  }) {
    return AuthState(
      token: token ?? this.token,
      loading: loading ?? this.loading,
      // keep same "error semantics" you had: caller decides new error
      error: error,
      me: me ?? this.me,
    );
  }
}

/// ---------------------------------------------------------------------------
/// Controller
/// ---------------------------------------------------------------------------

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref, this._prefs) : super(const AuthState()) {
    _bootstrap();
  }

  final Ref _ref;
  final SharedPreferences _prefs;

  static const _kTokenKey = 'auth_token';

  /// On startup:
  /// - load persisted token
  /// NOTE: we *don't* immediately call refreshMe() here because that would
  /// create a circular dependency during provider construction
  Future<void> _bootstrap() async {
    final saved = _prefs.getString(_kTokenKey);
    if (saved != null && saved.isNotEmpty) {
      state = state.copyWith(token: saved);
      // UI (e.g. in a top-level widget's initState) can then call:
      //   ref.read(authControllerProvider.notifier).refreshMe();
    }
  }

  /// Manually inject a token if you already have one.
  void setToken(String token) {
    _prefs.setString(_kTokenKey, token);
    state = AuthState(
      token: token,
      loading: false,
      error: null,
      me: state.me,
    );
  }

  /// Mark loading for UI spinners.
  void beginLoading() {
    state = state.copyWith(loading: true, error: null);
  }

  /// Mark an auth failure.
  void fail(String message) {
    state = state.copyWith(
      loading: false,
      error: message,
    );
  }

  /// Username/password (or PIN) login.
  ///
  /// ApiClient.login() MUST:
  ///  - POST /auth/login?mobile=...&password=... (or &pin=...)
  ///  - parse {"access_token": "..."}
  ///  - return that token String.
  Future<void> login(String mobile, String password, {String? pin}) async {
    state = state.copyWith(loading: true, error: null);

    try {
      // use base (unauth) client (no bearer header yet)
      final client = _ref.read(apiBaseClientProvider);

      final token = await client.login(
        mobile: mobile,
        password: password,
        pin: pin,
      );

      // persist token
      await _prefs.setString(_kTokenKey, token);

      // put token into state
      state = state.copyWith(
        token: token,
        loading: false,
        error: null,
      );

      // now that token is in state, apiClientProvider will rebuild
      // with Authorization header. So we can safely load /auth/me.
      await refreshMe();
    } on ApiException catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  /// Fetch /auth/me using the authed client (with Bearer token)
  /// and store roles / permissions in state.me.
  ///
  /// ApiClient.fetchMe() MUST:
  ///   - GET /auth/me
  ///   - return MeInfo.fromJson(responseJson)
  Future<void> refreshMe() async {
    final tokenNow = state.token;
    if (tokenNow == null || tokenNow.isEmpty) return;

    try {
      final authedClient = _ref.read(apiClientProvider);
      final info = await authedClient.fetchMe();
      state = state.copyWith(me: info, error: null);
    } catch (_) {
      // swallow for now; UI can retry later or show limited menu
    }
  }

  /// Logout fully: clear local token + RBAC info.
  Future<void> logout() async {
    await _prefs.remove(_kTokenKey);
    state = const AuthState(
      token: null,
      loading: false,
      error: null,
      me: null,
    );
  }
}
