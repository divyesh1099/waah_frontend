import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';

/// Auth state exposed to the rest of the app.
class AuthState {
  final String? token;
  final bool loading;
  final String? error;

  const AuthState({
    this.token,
    this.loading = false,
    this.error,
  });

  AuthState copyWith({
    String? token,
    bool? loading,
    String? error,
  }) {
    return AuthState(
      token: token ?? this.token,
      loading: loading ?? this.loading,
      // if caller passes null explicitly for error we respect that,
      // otherwise keep old error
      error: error,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref, this._prefs) : super(const AuthState()) {
    _bootstrap();
  }

  final Ref _ref;
  final SharedPreferences _prefs;

  static const _kTokenKey = 'auth_token';

  /// Load any cached token from SharedPreferences when the app starts.
  Future<void> _bootstrap() async {
    final saved = _prefs.getString(_kTokenKey);
    if (saved != null && saved.isNotEmpty) {
      state = state.copyWith(token: saved);
    }
  }

  /// Optional helper if you manually got a token elsewhere
  /// (e.g. OTP flow / refreshed token).
  void setToken(String token) {
    _prefs.setString(_kTokenKey, token);
    state = AuthState(
      token: token,
      loading: false,
      error: null,
    );
  }

  /// Mark we're in a loading flow (UI can show spinner).
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

  /// Username/password login.
  ///
  /// Uses the *unauthenticated* client so we don't create a circular
  /// dependency on apiClientProvider. After we get the token, the
  /// authed ApiClient provider will rebuild automatically because
  /// `authControllerProvider`'s state changed.
  Future<void> login(String mobile, String password) async {
    state = state.copyWith(loading: true, error: null);

    try {
      // use base (no-token) client
      final client = _ref.read(apiBaseClientProvider);

      // backend should return a raw JWT string here
      final token = await client.login(
        mobile: mobile,
        password: password,
      );

      // persist token
      await _prefs.setString(_kTokenKey, token);

      // update state (this will trigger apiClientProvider to rebuild
      // with Authorization header)
      state = state.copyWith(
        token: token,
        loading: false,
        error: null,
      );
    } on ApiException catch (e) {
      // known API error
      state = state.copyWith(
        loading: false,
        error: e.message,
      );
    } catch (e) {
      // unexpected error
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  /// Wipe token everywhere and return to logged-out state.
  Future<void> logout() async {
    await _prefs.remove(_kTokenKey);
    state = const AuthState(
      token: null,
      loading: false,
      error: null,
    );
  }
}
