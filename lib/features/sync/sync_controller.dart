import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';

class SyncState {
  final bool syncing;
  final int lastSeq;
  final String? lastMessage;
  final String? error;
  const SyncState({
    this.syncing = false,
    this.lastSeq = 0,
    this.lastMessage,
    this.error,
  });

  SyncState copyWith({
    bool? syncing,
    int? lastSeq,
    String? lastMessage,
    String? error,
  }) {
    return SyncState(
      syncing: syncing ?? this.syncing,
      lastSeq: lastSeq ?? this.lastSeq,
      lastMessage: lastMessage,
      error: error,
    );
  }
}

class SyncController extends StateNotifier<SyncState> {
  SyncController(this._ref, this._prefs)
      : super(SyncState(lastSeq: _prefs.getInt(_kLastSeqKey) ?? 0));

  final Ref _ref;
  final SharedPreferences _prefs;

  static const _kLastSeqKey = 'sync_last_seq';

  Future<void> syncNow() async {
    if (state.syncing) return;
    state = state.copyWith(syncing: true, error: null, lastMessage: null);

    try {
      final client = _ref.read(apiClientProvider);
      final since = _prefs.getInt(_kLastSeqKey) ?? 0;

      final res = await client.syncPull(since: since, limit: 200);
      final events =
          (res['events'] as List?) ?? (res['items'] as List?) ?? const [];
      final last = (res['last_seq'] is int)
          ? res['last_seq'] as int
          : (events.isNotEmpty ? since + 1 : since);

      await _prefs.setInt(_kLastSeqKey, last);
      state = state.copyWith(
        syncing: false,
        lastSeq: last,
        lastMessage: 'Synced ${events.length} updates',
      );
    } catch (e) {
      state = state.copyWith(syncing: false, error: e.toString());
    }
  }
}

final syncControllerProvider =
StateNotifierProvider<SyncController, SyncState>((ref) {
  final prefs = ref.watch(prefsProvider);
  return SyncController(ref, prefs);
});
