import 'dart:convert' as convert;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/providers.dart';
import '../../data/models.dart';

const _kPendingKey = 'orders_pending_v1';

class PendingOrder {
  final String orderNo;
  final OrderChannel channel;
  final OrderStatus status;     // usually OPEN until server confirms
  final DateTime openedAt;
  final String? tableId;

  PendingOrder({
    required this.orderNo,
    required this.channel,
    required this.status,
    required this.openedAt,
    this.tableId,
  });

  Map<String, dynamic> toJson() => {
    'order_no': orderNo,
    'channel': channel.name,
    'status': status.name,
    'opened_at': openedAt.toIso8601String(),
    'table_id': tableId,
  };

  static PendingOrder fromJson(Map<String, dynamic> j) => PendingOrder(
    orderNo: j['order_no']?.toString() ?? '',
    channel: OrderChannel.values.firstWhere(
          (c) => c.name == (j['channel']?.toString() ?? 'TAKEAWAY'),
      orElse: () => OrderChannel.TAKEAWAY,
    ),
    status: OrderStatus.values.firstWhere(
          (s) => s.name == (j['status']?.toString() ?? 'OPEN'),
      orElse: () => OrderStatus.OPEN,
    ),
    openedAt: DateTime.tryParse(j['opened_at']?.toString() ?? '') ?? DateTime.now(),
    tableId: j['table_id']?.toString(),
  );
}

class PendingOrdersNotifier extends StateNotifier<List<PendingOrder>> {
  PendingOrdersNotifier(this._prefs): super(const []) {
    _load();
  }

  final SharedPreferences _prefs;

  void _save() {
    final enc = convert.jsonEncode(state.map((p) => p.toJson()).toList());
    _prefs.setString(_kPendingKey, enc);
  }

  void _load() {
    final raw = _prefs.getString(_kPendingKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = convert.jsonDecode(raw);
    if (decoded is List) {
      state = decoded.map((e) => PendingOrder.fromJson(Map<String,dynamic>.from(e))).toList();
    }
  }

  void addQueued({
    required String orderNo,
    required OrderChannel channel,
    String? tableId,
    DateTime? openedAt,
  }) {
    final p = PendingOrder(
      orderNo: orderNo,
      channel: channel,
      status: OrderStatus.OPEN,
      openedAt: openedAt ?? DateTime.now(),
      tableId: tableId,
    );
    // de-dup by orderNo
    final without = state.where((x) => x.orderNo != orderNo).toList();
    state = [p, ...without]..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    _save();
  }

  /// Remove any pending rows that now exist on the server.
  void reconcileWithServer(List<Order> serverOrders) {
    if (state.isEmpty || serverOrders.isEmpty) return;
    final liveNos = serverOrders.map((o) => o.orderNo).toSet();
    final keep = state.where((p) => !liveNos.contains(p.orderNo)).toList();
    if (keep.length != state.length) {
      state = keep;
      _save();
    }
  }

  /// Remove any pending placeholders whose orderNos we just pushed.
  void removeByOrderNos(Set<String> orderNos) {
    if (orderNos.isEmpty || state.isEmpty) return;
    final keep = state.where((p) => !orderNos.contains(p.orderNo)).toList();
    if (keep.length != state.length) {
      state = keep;
      _save();
    }
  }

  void clearAll() {
    state = const [];
    _save();
  }

  void reconcileLooseWithServer(List<Order> serverOrders, {Duration skew = const Duration(minutes: 3)}) {
    if (state.isEmpty || serverOrders.isEmpty) return;

    bool shouldKeep(PendingOrder p) {
      final pTs = p.openedAt.toUtc();
      for (final o in serverOrders) {
        // If strict order_no already matches, strict reconcile would have removed it.
        if ((o.orderNo ?? '') == p.orderNo) continue;

        // Channel must match
        if (o.channel != p.channel) continue;

        // If pending had a table, require same table
        if (p.tableId != null && p.tableId!.isNotEmpty) {
          if (o.tableId != p.tableId) continue;
        }

        // openedAt must exist and be close in time
        final oTs = (o.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc();
        final diff = oTs.difference(pTs).abs();
        if (diff <= skew) {
          // Consider this the same real order — drop the placeholder
          return false;
        }
      }
      return true; // keep it if no near match found
    }

    final keep = state.where(shouldKeep).toList();
    if (keep.length != state.length) {
      state = keep;
      _save();
    }
  }

  /// Log first pending placeholder for quick inspection.
  void debugLogFirst() {
    if (state.isEmpty) return;
    final p = state.first;
    // ignore: avoid_print
    print('[PENDING:first] '
        'orderNo=${p.orderNo} '
        'channel=${p.channel.name} '
        'table=${p.tableId ?? "-"} '
        'openedAt=${p.openedAt.toIso8601String()}');
    // If you want the full JSON of what you persist:
    // ignore: avoid_print
    // print(convert.jsonEncode(p.toJson()));
  }

  /// Remove placeholders older than [olderThan].
  void clearStale({Duration olderThan = const Duration(minutes: 30)}) {
    final cutoff = DateTime.now().toUtc().subtract(olderThan);
    final keep = state.where((p) => p.openedAt.toUtc().isAfter(cutoff)).toList();
    if (keep.length != state.length) {
      state = keep;
      _save();
    }
  }

  /// Manually resolve: pick one server orderNo and drop the nearest pending by time.
  void resolveByServerOrderNo(String serverOrderNo, List<Order> serverOrders,
      {Duration skew = const Duration(minutes: 60)}) {
    final o = serverOrders.firstWhere(
          (x) => (x.orderNo ?? '') == serverOrderNo,
      orElse: () => throw ArgumentError('order not in page'),
    );
    if (state.isEmpty) return;
    final oTs = (o.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc();

    int best = -1;
    Duration bestDiff = const Duration(days: 999);
    for (int i = 0; i < state.length; i++) {
      final p = state[i];
      if (o.channel != p.channel) continue;
      if (p.tableId != null && p.tableId!.isNotEmpty && p.tableId != o.tableId) continue;
      final diff = (p.openedAt.toUtc().difference(oTs)).abs();
      if (diff <= skew && diff < bestDiff) {
        best = i;
        bestDiff = diff;
      }
    }
    if (best >= 0) {
      final copy = [...state];
      copy.removeAt(best);
      state = copy;
      _save();
    }
  }

}

final pendingOrdersProvider =
StateNotifierProvider<PendingOrdersNotifier, List<PendingOrder>>((ref) {
  final prefs = ref.read(prefsProvider);
  return PendingOrdersNotifier(prefs);

});

