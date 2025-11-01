import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';

import '../../utils/secure_pin.dart';

/// ---------------------------------------------------------------------------
/// Auth state exposed to rest of app
/// ---------------------------------------------------------------------------

class AuthState {
  final String? token;
  final bool loading;
  final String? error;
  final MeInfo? me;
  final bool offline;          // <— NEW: true when unlocked offline

  const AuthState({
    this.token,
    this.loading = false,
    this.error,
    this.me,
    this.offline = false,      // <— default
  });

  AuthState copyWith({
    String? token,
    bool? loading,
    String? error,
    MeInfo? me,
    bool? offline,
  }) {
    return AuthState(
      token: token ?? this.token,
      loading: loading ?? this.loading,
      error: error,
      me: me ?? this.me,
      offline: offline ?? this.offline,
    );
  }
}

/// ---------------------------------------------------------------------------
/// Controller
/// ---------------------------------------------------------------------------

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref, this._prefs) : super(const AuthState()) { _bootstrap(); }

  final Ref _ref;
  final SharedPreferences _prefs;

  static const _kTokenKey   = 'auth_token';
  static const _kMeJsonKey  = 'auth_me_json';
  static const _kMobileKey  = 'last_mobile';
  static const _kTenantKey  = 'active_tenant_id';
  static const _kBranchKey  = 'active_branch_id';
  static const _kPinSaltKey = 'pin_salt';
  static const _kPinHashKey = 'pin_hash';

  Future<void> _bootstrap() async {
    // Restore token first
    final savedToken = _prefs.getString(_kTokenKey);
    final meJson     = _prefs.getString(_kMeJsonKey);
    if (savedToken != null && savedToken.isNotEmpty) {
      state = state.copyWith(token: savedToken);
    }
    if (meJson != null && meJson.isNotEmpty) {
      try {
        final map = jsonDecode(meJson) as Map<String, dynamic>;
        final me = MeInfo.fromJson(map);
        state = state.copyWith(me: me);
      } catch (_) {}
    }
  }

  void setToken(String token) {
    _prefs.setString(_kTokenKey, token);
    state = AuthState(token: token, loading: false, error: null, me: state.me, offline: false);
  }

  void beginLoading() => state = state.copyWith(loading: true, error: null);
  void fail(String message) => state = state.copyWith(loading: false, error: message);

  Future<void> login(String mobile, String password, {String? pin}) async {
    state = state.copyWith(loading: true, error: null);

    final apiBase = _ref.read(apiBaseClientProvider);

    // Helper to finalize success (online)
    Future<void> afterOnlineLogin(String token, {String? usedPin}) async {
      await _prefs.setString(_kTokenKey, token);
      state = state.copyWith(token: token, loading: false, error: null, offline: false);

      // Load /auth/me now that apiClientProvider will rebuild with token
      await refreshMe();

      // Cache mobile
      _prefs.setString(_kMobileKey, mobile);

      // If we have me, persist tenant/branch and pin hash
      final me = state.me;
      if (me != null) {
        _prefs.setString(_kTenantKey, me.tenantId);
        if (me.branchId != null && me.branchId!.isNotEmpty) {
          _prefs.setString(_kBranchKey, me.branchId!);
        } else {
          // fallback: pick default branch if only one exists
          await _pickDefaultBranchIfMissing(me.tenantId);
        }

        // push to providers
        try {
          final b = _prefs.getString(_kBranchKey);
          setActiveTenantAndBranch(_ref, tenantId: me.tenantId, branchId: b);
        } catch (_) {}
      }

      // If PIN used, store salted hash for future offline unlock
      if (usedPin != null && usedPin.isNotEmpty) {
        final salt = _prefs.getString(_kPinSaltKey) ?? _newSalt();
        _prefs.setString(_kPinSaltKey, salt);
        final h = hashPin(mobile: mobile, pin: usedPin, salt: salt);
        _prefs.setString(_kPinHashKey, h);
      }
    }

    try {
      // Prefer PIN if provided (your backend already supports &pin=)
      final token = await apiBase.login(mobile: mobile, password: password, pin: pin);
      await afterOnlineLogin(token, usedPin: pin);
    } on ApiException catch (e) {
      // If network/host unreachable OR offline and user gave a PIN: try offline unlock
      final offlineOk = await _tryOfflineUnlock(mobile: mobile, pin: pin);
      if (offlineOk) return;
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      // Non-HTTP failure (likely offline): attempt offline unlock if PIN present
      final offlineOk = await _tryOfflineUnlock(mobile: mobile, pin: pin);
      if (!offlineOk) {
        state = state.copyWith(loading: false, error: 'Login failed');
      }
    }
  }

  Future<void> refreshMe() async {
    final tokenNow = state.token;
    if (tokenNow == null || tokenNow.isEmpty) return;
    try {
      final authed = _ref.read(apiClientProvider);
      final info = await authed.fetchMe();
      state = state.copyWith(me: info, error: null);

      // cache to prefs for offline usage
      _prefs.setString(_kMeJsonKey, jsonEncode(info.toJson()));
    } catch (_) {
      // Swallow; in offline mode we’ll rely on cached me.
    }
  }

  Future<void> logout() async {
    await _prefs.remove(_kTokenKey);
    await _prefs.remove(_kMeJsonKey);
    state = const AuthState(token: null, loading: false, error: null, me: null, offline: false);
  }

  // ---- helpers ------------------------------------------------------------

  String _newSalt() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<bool> _tryOfflineUnlock({required String mobile, String? pin}) async {
    // Only if a PIN is provided AND we have a stored hash
    if (pin == null || pin.isEmpty) return false;

    // Quick connectivity check to bias offline path
    final conn = await Connectivity().checkConnectivity();
    final seemsOffline = !conn.contains(ConnectivityResult.mobile) &&
        !conn.contains(ConnectivityResult.wifi);

    final salt = _prefs.getString(_kPinSaltKey);
    final hash = _prefs.getString(_kPinHashKey);
    final cachedToken = _prefs.getString(_kTokenKey);
    final meJson = _prefs.getString(_kMeJsonKey);

    final canVerify = salt != null && hash != null && hash.isNotEmpty && meJson != null && cachedToken != null;
    if (!canVerify) return false;

    final ok = verifyPin(mobile: mobile, pin: pin, salt: salt, storedHash: hash);
    if (!ok) return false;

    // Accept offline unlock using cached token + me
    try {
      final me = MeInfo.fromJson(jsonDecode(meJson) as Map<String, dynamic>);
      state = AuthState(
        token: cachedToken,
        me: me,
        loading: false,
        error: null,
        offline: true,
      );
      // ensure active tenant/branch are set from cache
      final tid = _prefs.getString(_kTenantKey) ?? me.tenantId;
      final bid = _prefs.getString(_kBranchKey) ?? me.branchId ?? '';
      setActiveTenantAndBranch(_ref, tenantId: tid, branchId: bid.isEmpty ? null : bid);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pickDefaultBranchIfMissing(String tenantId) async {
    try {
      final authed = _ref.read(apiClientProvider);
      final branches = await authed.fetchBranches(tenantId: tenantId);
      if (branches.length == 1) {
        final b = branches.first.id;
        if (b.isNotEmpty) {
          _prefs.setString(_kBranchKey, b);
        }
      }
    } catch (_) {}
  }
}