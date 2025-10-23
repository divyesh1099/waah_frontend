import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';

class AuthState {
  final String? token;
  final bool loading;
  final String? error;

  const AuthState({this.token, this.loading = false, this.error});

  AuthState copyWith({String? token, bool? loading, String? error}) {
    return AuthState(
      token: token ?? this.token,
      loading: loading ?? this.loading,
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

  Future<void> _bootstrap() async {
    final saved = _prefs.getString(_kTokenKey);
    if (saved != null && saved.isNotEmpty) {
      state = state.copyWith(token: saved);
    }
  }

  Future<void> login(String mobile, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      // IMPORTANT: use the base client to avoid a provider cycle
      final client = _ref.read(apiBaseClientProvider);

      final token = await client.login(mobile: mobile, password: password);

      await _prefs.setString(_kTokenKey, token);

      // Do NOT read apiClientProvider here (would re-create the cycle).
      // Just update our state; apiClientProvider will rebuild with the new token automatically.
      state = state.copyWith(token: token, loading: false);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    await _prefs.remove(_kTokenKey);
    state = const AuthState();
  }
}
