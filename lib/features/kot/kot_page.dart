// features/kot/kot_page.dart
// Fast + Offline‑first KOT board (DROP‑IN v3.3)
//
// What’s new in v3.3 (fixes + speed):
// • Offline‑first by default (instant cache render, then quiet refresh).
// • Robust ticket number derivation — no more "KOT #0" (uses kotNo/number/orderNo/id hash).
// • Safer createdAt extraction (Map/toJson/direct fields; epoch seconds/ms supported).
// • Stable sorting: createdAt desc → ticketNo desc → id, so newest stays on top even if ticketNo is 0.
// • UI shows a smart KOT label (falls back to short order/provider/id when ticketNo is 0).
// • All v3.2 details preserved (customer, provider refs, rider, notes, inline expand, details sheet).
//
// Paste this WHOLE file to replace your current features/kot/kot_page.dart.

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

// ------------------------------------------------------------------
// Config
// ------------------------------------------------------------------
const int _kPollSeconds = 6; // quick refresh
const bool _kOnlineFirst = false; // OFFLINE‑FIRST by default

// ------------------------------------------------------------------
// Types & helpers
// ------------------------------------------------------------------
typedef Read = T Function<T>(ProviderListenable<T> provider);
typedef Invalidate = void Function(ProviderOrFamily provider);

String _kb(String t, String b, KOTStatus s) => 'kot_cache/$t/$b/${s.name}';
String _qb(String t, String b) => 'kot_queue/$t/$b';

String _ago(DateTime? dt) {
  if (dt == null) return '';
  final d = DateTime.now().difference(dt);
  if (d.inSeconds < 60) return '${d.inSeconds}s';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}

String _fmtQty(num q) => (q % 1 == 0) ? q.toInt().toString() : q.toString();

OnlineProvider? _extractProvider(dynamic t) {
  try {
    final p = t.provider;
    if (p is OnlineProvider) return p;
    if (p is String && p.isNotEmpty) {
      return OnlineProvider.values
          .firstWhere((e) => e.name == p, orElse: () => OnlineProvider.CUSTOM);
    }
  } catch (_) {}
  // common alternate property names
  try {
    final p2 = t.onlineProvider;
    if (p2 is String && p2.isNotEmpty) {
      return OnlineProvider.values
          .firstWhere((e) => e.name == p2, orElse: () => OnlineProvider.CUSTOM);
    }
  } catch (_) {}
  return null;
}

// Absolute timestamp formatter
String _fmtWhen(DateTime dt) {
  final now = DateTime.now();
  final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
  String two(int v) => v.toString().padLeft(2, '0');
  const mons = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  if (isToday) return '${two(dt.hour)}:${two(dt.minute)}';
  return '${two(dt.day)} ${mons[dt.month - 1]}, ${two(dt.hour)}:${two(dt.minute)}';
}

// provider chip UI meta
({IconData icon, String label}) _providerMeta(OnlineProvider p) {
  switch (p) {
    case OnlineProvider.ZOMATO:
      return (icon: Icons.restaurant_menu, label: 'Zomato');
    case OnlineProvider.SWIGGY:
      return (icon: Icons.delivery_dining, label: 'Swiggy');
    default:
      return (icon: Icons.cloud, label: p.name);
  }
}

OrderChannel? _extractChannel(dynamic t) {
  try {
    final ch = t.channel; // may or may not exist
    if (ch is OrderChannel) return ch;
    if (ch is String) {
      return OrderChannel.values
          .firstWhere((e) => e.name == ch, orElse: () => OrderChannel.TAKEAWAY);
    }
  } catch (_) {}
  // Fallback heuristic: table present -> DINE_IN
  try {
    final table = t.tableCode as String?;
    if (table != null && table.trim().isNotEmpty) return OrderChannel.DINE_IN;
  } catch (_) {}
  return null;
}

// ---- Robust date extraction (supports Map/toJson/direct & epoch secs/ms)
DateTime? _asDate(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is int) {
    if (v > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
    if (v > 1000000000) return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true).toLocal();
  }
  if (v is num) {
    final iv = v.toInt();
    if (iv > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(iv, isUtc: true).toLocal();
    if (iv > 1000000000) return DateTime.fromMillisecondsSinceEpoch(iv * 1000, isUtc: true).toLocal();
  }
  return null;
}

DateTime? _extractCreatedAt(dynamic t) {
  const keys = ['createdAt', 'created_at', 'openedAt', 'placedAt', 'created'];

  // 1) Map‑like
  if (t is Map) {
    for (final k in keys) {
      final dt = _asDate(t[k]);
      if (dt != null) return dt;
    }
  }

  // 2) toJson() Map
  try {
    final dynamic toJson = (t as dynamic).toJson;
    if (toJson is Function) {
      final m = toJson();
      if (m is Map) {
        for (final k in keys) {
          final dt = _asDate(m[k]);
          if (dt != null) return dt;
        }
      }
    }
  } catch (_) {}

  // 3) Direct fields
  for (final k in keys) {
    try {
      final v = (t as dynamic).$k; // <-- not valid in Dart; do NOT use
    } catch (_) {
      // fall through
    }
  }
  try { final dt = _asDate((t as dynamic).createdAt); if (dt != null) return dt; } catch (_) {}
  try { final dt = _asDate((t as dynamic).created_at); if (dt != null) return dt; } catch (_) {}
  try { final dt = _asDate((t as dynamic).openedAt); if (dt != null) return dt; } catch (_) {}
  try { final dt = _asDate((t as dynamic).placedAt); if (dt != null) return dt; } catch (_) {}
  try { final dt = _asDate((t as dynamic).created); if (dt != null) return dt; } catch (_) {}

  return null;
}

// channel chip text/icon
({IconData icon, String label}) _channelMeta(OrderChannel ch) {
  switch (ch) {
    case OrderChannel.DINE_IN:
      return (icon: Icons.restaurant, label: 'Dine‑In');
    case OrderChannel.TAKEAWAY:
      return (icon: Icons.shopping_bag, label: 'Takeaway');
    case OrderChannel.DELIVERY:
      return (icon: Icons.delivery_dining, label: 'Delivery');
    default:
      return (icon: Icons.local_mall, label: ch.name.replaceAll('_', ' '));
  }
}

// ------------------------------------------------------------------
// Lite models for fast cache (only what the card displays)
// ------------------------------------------------------------------
class KotLineLite {
  final num qty;
  final String name;
  final String? variantLabel;
  final List<String> modifiers;

  KotLineLite({
    required this.qty,
    required this.name,
    required this.variantLabel,
    required this.modifiers,
  });

  Map<String, dynamic> toMap() => {
    'qty': qty,
    'name': name,
    'variantLabel': variantLabel,
    'modifiers': modifiers,
  };

  factory KotLineLite.fromMap(Map<String, dynamic> m) => KotLineLite(
    qty: (m['qty'] is num)
        ? m['qty'] as num
        : num.tryParse(m['qty']?.toString() ?? '1') ?? 1,
    name: m['name']?.toString() ?? '',
    variantLabel: () {
      final cands = ['variantLabel', 'variant', 'variant_name', 'variant_label'];
      for (final k in cands) {
        final v = m[k]?.toString();
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }(),
    modifiers: (m['modifiers'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[],
  );
}

class KotCardData {
  final String id;
  final int ticketNo;
  final KOTStatus status;
  final String? stationName;
  final String? tableCode;
  final String? waiterName;
  final String? orderNo;
  final String? orderId;
  final String? orderNote;
  final OrderChannel? channel;
  final OnlineProvider? provider;
  final DateTime? createdAt;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final String? providerOrderId;
  final String? riderName;
  final String? riderStatus;
  final List<KotLineLite> lines;

  KotCardData({
    required this.id,
    required this.ticketNo,
    required this.status,
    required this.stationName,
    required this.tableCode,
    required this.waiterName,
    required this.orderNo,
    required this.orderId,
    required this.orderNote,
    required this.channel,
    required this.provider,
    required this.createdAt,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.providerOrderId,
    required this.riderName,
    required this.riderStatus,
    required this.lines,
  });

  KotCardData copyWith({KOTStatus? status}) => KotCardData(
    id: id,
    ticketNo: ticketNo,
    status: status ?? this.status,
    stationName: stationName,
    tableCode: tableCode,
    waiterName: waiterName,
    orderNo: orderNo,
    orderId: orderId,
    orderNote: orderNote,
    channel: channel,
    provider: provider,
    createdAt: createdAt,
    customerName: customerName,
    customerPhone: customerPhone,
    deliveryAddress: deliveryAddress,
    providerOrderId: providerOrderId,
    riderName: riderName,
    riderStatus: riderStatus,
    lines: lines,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'ticketNo': ticketNo,
    'status': status.name,
    'stationName': stationName,
    'tableCode': tableCode,
    'waiterName': waiterName,
    'orderNo': orderNo,
    'orderId': orderId,
    'orderNote': orderNote,
    'channel': channel?.name,
    'createdAt': createdAt?.toIso8601String(),
    'provider': provider?.name,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'deliveryAddress': deliveryAddress,
    'providerOrderId': providerOrderId,
    'riderName': riderName,
    'riderStatus': riderStatus,
    'lines': lines.map((e) => e.toMap()).toList(),
  };

  factory KotCardData.fromMap(Map<String, dynamic> m) => KotCardData(
    id: m['id']?.toString() ?? '',
    ticketNo: (m['ticketNo'] as num?)?.toInt() ?? 0,
    status: KOTStatus.values.firstWhere((e) => e.name == m['status'], orElse: () => KOTStatus.NEW),
    stationName: (m['stationName']?.toString().isEmpty ?? true) ? null : m['stationName'].toString(),
    tableCode: (m['tableCode']?.toString().isEmpty ?? true) ? null : m['tableCode'].toString(),
    waiterName: (m['waiterName']?.toString().isEmpty ?? true) ? null : m['waiterName'].toString(),
    orderNo: (m['orderNo']?.toString().isEmpty ?? true) ? null : m['orderNo'].toString(),
    orderId: (m['orderId']?.toString().isEmpty ?? true) ? null : m['orderId'].toString(),
    orderNote: (m['orderNote']?.toString().isEmpty ?? true) ? null : m['orderNote'].toString(),
    channel: (() {
      final s = m['channel']?.toString();
      if (s == null || s.isEmpty) return null;
      return OrderChannel.values.firstWhere((e) => e.name == s, orElse: () => OrderChannel.TAKEAWAY);
    })(),
    createdAt: (() {
      final s = m['createdAt']?.toString();
      return s == null || s.isEmpty ? null : DateTime.tryParse(s);
    })(),
    provider: (() {
      final s = m['provider']?.toString();
      if (s == null || s.isEmpty) return null;
      return OnlineProvider.values.firstWhere((e) => e.name == s, orElse: () => OnlineProvider.CUSTOM);
    })(),
    customerName: (m['customerName']?.toString().isEmpty ?? true) ? null : m['customerName'].toString(),
    customerPhone: (m['customerPhone']?.toString().isEmpty ?? true) ? null : m['customerPhone'].toString(),
    deliveryAddress: (m['deliveryAddress']?.toString().isEmpty ?? true) ? null : m['deliveryAddress'].toString(),
    providerOrderId: (m['providerOrderId']?.toString().isEmpty ?? true) ? null : m['providerOrderId'].toString(),
    riderName: (m['riderName']?.toString().isEmpty ?? true) ? null : m['riderName'].toString(),
    riderStatus: (m['riderStatus']?.toString().isEmpty ?? true) ? null : m['riderStatus'].toString(),
    lines: (m['lines'] as List?)?.map((e) => KotLineLite.fromMap(Map<String, dynamic>.from(e))).toList() ??
        const <KotLineLite>[],
  );

  static int _stableTicketFromId(String id) {
    var s = 0x7fffffff & 0; // non‑negative
    for (final c in id.codeUnits) {
      s = (s * 31 + c) & 0x7fffffff;
    }
    return 1000 + (s % 9000); // 1000‑9999 range
  }

  static int _deriveTicketNoFromMaps(dynamic t) {
    int _asPositiveInt(dynamic v) {
      if (v is int && v > 0) return v;
      if (v is String) {
        final m = RegExp(r'\d+').firstMatch(v);
        if (m != null) {
          final n = int.tryParse(m.group(0)!);
          if (n != null && n > 0) return n;
        }
      }
      return 0;
    }

    // 1) If KitchenTicket has toJson that returns a Map, read keys safely (no `?.[]`)
    try {
      final dynamic toJson = (t as dynamic).toJson;
      if (toJson is Function) {
        final m = toJson();
        if (m is Map) {
          for (final k in const ['kotNo','kotNumber','kot_no','number','ticket','ticket_no','ticketNumber']) {
            final got = m[k];
            final n = _asPositiveInt(got);
            if (n > 0) return n;
          }
        }
      }
    } catch (_) {}

    // 2) Direct fields (check a small set explicitly; no dynamic string field eval)
    dynamic _try(dynamic Function() f) {
      try { return f(); } catch (_) { return null; }
    }

    for (final getter in <dynamic Function()>[
          () => (t as dynamic).kotNo,
          () => (t as dynamic).kotNumber,
          () => (t as dynamic).kot_no,
          () => (t as dynamic).number,
          () => (t as dynamic).ticket,
          () => (t as dynamic).ticket_no,
          () => (t as dynamic).ticketNumber,
          () => (t as dynamic).no,
    ]) {
      final v = _try(getter);
      final n = _asPositiveInt(v);
      if (n > 0) return n;
    }

    return 0;
  }

  static KotCardData fromKitchenTicket(KitchenTicket t) {
    // Lines
    final List<KotLineLite> ls = <KotLineLite>[];
    try {
      final ln = t.lines;
      for (final l in ln) {
        dynamic name;
        dynamic qty;
        dynamic vlabel;
        List<String> mods = <String>[];
        try {
          name = (l as dynamic).name ?? (l as dynamic).itemName ?? (l as dynamic).title;
        } catch (_) {}
        try {
          qty = (l as dynamic).qty ?? (l as dynamic).quantity;
        } catch (_) {}
        try {
          vlabel = (l as dynamic).variantLabel ?? (l as dynamic).variant ?? (l as dynamic).variant_name;
        } catch (_) {}
        try {
          final raw = (l as dynamic).modifiers ?? (l as dynamic).mods;
          if (raw is List) {
            mods = raw
                .map((e) => e is String
                ? e
                : ((e as dynamic).name ?? (e as dynamic).label ?? e.toString()).toString())
                .toList();
          }
        } catch (_) {}
        ls.add(KotLineLite(
          qty: (qty is num) ? qty : num.tryParse(qty?.toString() ?? '1') ?? 1,
          name: name?.toString() ?? '',
          variantLabel: (vlabel?.toString().isEmpty ?? true) ? null : vlabel.toString(),
          modifiers: mods,
        ));
      }
    } catch (_) {}

    // Extra info
    String? _s(dynamic x) => (x == null) ? null : (x.toString().trim().isEmpty ? null : x.toString());

    String? customerName;
    String? customerPhone;
    String? deliveryAddress;
    String? providerOrderId;
    String? riderName;
    String? riderStatus;

    // Try multiple likely fields to be robust across backends
    try { customerName = _s((t as dynamic).customerName ?? (t as dynamic).customer?.name); } catch (_) {}
    try { customerPhone = _s((t as dynamic).customerPhone ?? (t as dynamic).customer?.phone); } catch (_) {}
    try { deliveryAddress = _s((t as dynamic).deliveryAddress ?? (t as dynamic).address); } catch (_) {}
    try { providerOrderId = _s((t as dynamic).providerOrderId ?? (t as dynamic).externalOrderId); } catch (_) {}
    try { riderName = _s((t as dynamic).riderName ?? (t as dynamic).agentName); } catch (_) {}
    try { riderStatus = _s((t as dynamic).riderStatus ?? (t as dynamic).agentStatus); } catch (_) {}

    // createdAt
    final created = _extractCreatedAt(t);

    // ticketNo (robust)
    int tn = 0;
    try { tn = (t.ticketNo is int) ? t.ticketNo : 0; } catch (_) {}
    if (tn == 0) tn = _deriveTicketNoFromMaps(t);
    if (tn == 0) {
      try {
        final s = ((t as dynamic).orderNo ?? (t as dynamic).order_id ?? (t as dynamic).orderId)?.toString();
        if (s != null) {
          final mnum = RegExp(r'(\d{1,6})$').firstMatch(s);
          if (mnum != null) tn = int.tryParse(mnum.group(1)!) ?? 0;
        }
      } catch (_) {}
    }
    final idStr = (t.id ?? '').toString();
    if (tn == 0) tn = _stableTicketFromId(idStr);

    return KotCardData(
      id: idStr,
      ticketNo: tn,
      status: t.status,
      stationName: (t.stationName?.trim().isEmpty ?? true) ? null : t.stationName,
      tableCode: (t.tableCode?.trim().isEmpty ?? true) ? null : t.tableCode,
      waiterName: (t.waiterName?.trim().isNotEmpty ?? false) ? t.waiterName : null,
      orderNo: (t.orderNo?.trim().isNotEmpty ?? false) ? t.orderNo : null,
      orderId: (t.orderId.toString().trim().isNotEmpty ?? false) ? t.orderId.toString() : null,
      orderNote: (t.orderNote?.trim().isNotEmpty ?? false) ? t.orderNote : null,
      channel: _extractChannel(t),
      createdAt: created,
      provider: _extractProvider(t),
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      providerOrderId: providerOrderId,
      riderName: riderName,
      riderStatus: riderStatus,
      lines: ls,
    );
  }
}

// Simple mods summary for KotLineLite
String _modsSummaryLite(KotLineLite ln) {
  if (ln.modifiers.isEmpty) return '';
  return ' • ${ln.modifiers.join(", ")}';
}

String _hintFromLines(List<KotLineLite> lines) {
  if (lines.isEmpty) return '';
  final cap = min(3, lines.length);
  final head = lines.take(cap).map((l) => '${_fmtQty(l.qty)}× ${l.name}').join(', ');
  final more = lines.length > cap ? ' +${lines.length - cap} more' : '';
  return head + more;
}

String _shortTail(String s, [int n = 6]) => (s.length <= n) ? s : s.substring(s.length - n);
String _ticketLabel(KotCardData t) {
  if (t.ticketNo > 0) return '#${t.ticketNo}';
  final prefer = (t.orderNo?.trim().isNotEmpty ?? false)
      ? t.orderNo!.trim()
      : ((t.providerOrderId?.trim().isNotEmpty ?? false)
      ? t.providerOrderId!.trim()
      : ((t.orderId?.trim().isNotEmpty ?? false) ? t.orderId!.trim() : t.id));
  return '#${_shortTail(prefer)}';
}

// ------------------------------------------------------------------
// Session/Context: tenant & branch (mirror global)
// ------------------------------------------------------------------
final kotTenantIdProvider = Provider<String>((ref) => ref.watch(activeTenantIdProvider));
final kotBranchIdProvider = Provider<String>((ref) => ref.watch(activeBranchIdProvider));

// ------------------------------------------------------------------
// In-memory state: caches + registry + pending overlay + queued ops
// ------------------------------------------------------------------
final Map<String, List<KotCardData>> _memCache = {}; // per-lane view (overlayed)
final Map<String, KotCardData> _ticketById = {}; // last known copy (any lane)
final Map<String, KOTStatus> _pendingStatus = {}; // ticketId -> target
final Set<String> _pendingCancel = <String>{};
final Set<String> _busyTickets = <String>{}; // dedupe rapid taps

class _KotOp {
  final String type; // 'status' | 'reprint' | 'cancel'
  final String ticketId;
  final Map<String, dynamic> payload;
  _KotOp(this.type, this.ticketId, this.payload);
  Map<String, dynamic> toMap() => {'type': type, 'ticketId': ticketId, 'payload': payload};
  static _KotOp fromMap(Map<String, dynamic> m) =>
      _KotOp(m['type'] as String, m['ticketId'] as String, Map<String, dynamic>.from(m['payload'] as Map));
}

Future<List<_KotOp>> _readKotQueue(Read read, String tenantId, String branchId) async {
  final prefs = read(prefsProvider);
  final raw = prefs.getString(_qb(tenantId, branchId));
  if (raw == null || raw.isEmpty) return <_KotOp>[];
  try {
    final arr = (convert.jsonDecode(raw) as List).cast<Map>();
    return arr.map((e) => _KotOp.fromMap(Map<String, dynamic>.from(e))).toList();
  } catch (_) {
    return <_KotOp>[];
  }
}

Future<void> _writeKotQueue(Read read, String tenantId, String branchId, List<_KotOp> ops) async {
  final prefs = read(prefsProvider);
  await prefs.setString(_qb(tenantId, branchId), convert.jsonEncode(ops.map((e) => e.toMap()).toList()));
}

Future<void> _enqueueKotOp(Read read, String tenantId, String branchId, _KotOp op) async {
  final cur = await _readKotQueue(read, tenantId, branchId);
  // Coalesce: keep only the latest status/cancel per ticket
  if (op.type == 'status') {
    cur.removeWhere((e) => e.type == 'status' && e.ticketId == op.ticketId);
  }
  if (op.type == 'cancel') {
    cur.removeWhere((e) => e.ticketId == op.ticketId); // cancel overrides any pending status
  }
  cur.add(op);
  await _writeKotQueue(read, tenantId, branchId, cur);
}

// Apply overlay + merge in pending items destined for this lane (from registry)
List<KotCardData> _overlayAndMergeForLane(List<KotCardData> server, KOTStatus lane) {
  final map = <String, KotCardData>{for (final t in server) t.id: t};
  // add missing items that are pending into this lane
  _pendingStatus.forEach((id, st) {
    if (st == lane) {
      final t = _ticketById[id];
      if (t != null) map[id] = t.copyWith(status: st);
    }
  });
  // drop cancels and ensure effective status matches lane
  map.removeWhere((id, _) => _pendingCancel.contains(id));
  final out = <KotCardData>[];
  for (final t in map.values) {
    final eff = _pendingStatus[t.id] ?? t.status;
    if (eff == lane) {
      out.add(_pendingStatus.containsKey(t.id) ? t.copyWith(status: eff) : t);
    }
  }
  // Stable sort: createdAt desc → ticketNo desc → id desc
  out.sort((a, b) {
    final ca = a.createdAt; final cb = b.createdAt;
    if (ca != null && cb != null) {
      final cmp = cb.compareTo(ca);
      if (cmp != 0) return cmp;
    } else if (ca == null && cb != null) {
      return 1;
    } else if (ca != null && cb == null) {
      return -1;
    }
    final tn = b.ticketNo.compareTo(a.ticketNo);
    if (tn != 0) return tn;
    return b.id.compareTo(a.id);
  });
  return out;
}

Future<void> _pushKotQueue(Read read, String tenantId, String branchId) async {
  final api = read(apiClientProvider);
  final ops = await _readKotQueue(read, tenantId, branchId);
  if (ops.isEmpty) return;
  final failures = <_KotOp>[];
  for (final op in ops) {
    try {
      if (op.type == 'status') {
        final ns = KOTStatus.values.firstWhere((e) => e.name == op.payload['next']);
        await api.patchKitchenTicketStatus(op.ticketId, ns, tenantId: tenantId, branchId: branchId);
        _pendingStatus.remove(op.ticketId);
      } else if (op.type == 'reprint') {
        await api.reprintKitchenTicket(op.ticketId,
            reason: op.payload['reason']?.toString() ?? 'Queued reprint', tenantId: tenantId, branchId: branchId);
      } else if (op.type == 'cancel') {
        await api.cancelKitchenTicket(op.ticketId,
            reason: op.payload['reason']?.toString(), tenantId: tenantId, branchId: branchId);
        _pendingCancel.remove(op.ticketId);
      }
    } catch (_) {
      failures.add(op);
    }
  }
  await _writeKotQueue(read, tenantId, branchId, failures);
}

// ------------------------------------------------------------------
// Network fetch + SWR cache update
// ------------------------------------------------------------------
Future<List<KotCardData>> _fetchFresh(Read read, String tenantId, String branchId, KOTStatus status) async {
  final api = read(apiClientProvider);
  final list = await api.fetchKitchenTickets(
    status: status,
    tenantId: tenantId.isEmpty ? null : tenantId,
    branchId: branchId.isEmpty ? null : branchId,
  );
  final mapped = list.map(KotCardData.fromKitchenTicket).toList();
  // update registry
  for (final t in mapped) {
    _ticketById[t.id] = t;
  }
  final effective = _overlayAndMergeForLane(mapped, status);

  // Write caches (overlayed view) + disk
  final key = _kb(tenantId, branchId, status);
  _memCache[key] = effective;
  final prefs = read(prefsProvider);
  try {
    await prefs.setString(key, convert.jsonEncode(effective.map((e) => e.toMap()).toList()));
  } catch (_) {}
  return effective;
}

Future<void> _refreshKot(Read read, String tenantId, String branchId, KOTStatus status) async {
  try {
    await _fetchFresh(read, tenantId, branchId, status);
  } catch (_) {}
}

// ------------------------------------------------------------------
// Auto-refresh + queue pusher (polling every _kPollSeconds)
// ------------------------------------------------------------------
final _kotAutoPollProvider = Provider<void>((ref) {
  final tenantId = ref.watch(kotTenantIdProvider);
  final branchId = ref.watch(kotBranchIdProvider);
  final t = Timer.periodic(Duration(seconds: _kPollSeconds), (_) async {
    for (final st in KOTStatus.values) {
      unawaited(_refreshKot(ref.read, tenantId, branchId, st));
    }
    unawaited(_pushKotQueue(ref.read, tenantId, branchId));
  });
  ref.onDispose(t.cancel);
});

// ------------------------------------------------------------------
// Provider: Offline‑first with online refresh (or set _kOnlineFirst=true)
// ------------------------------------------------------------------
final kotTicketsProvider = FutureProvider.family.autoDispose<List<KotCardData>, KOTStatus>((ref, status) async {
  final tenantId = ref.watch(kotTenantIdProvider);
  final branchId = ref.watch(kotBranchIdProvider);
  ref.watch(_kotAutoPollProvider); // keep poller alive while page open
  final key = _kb(tenantId, branchId, status);

  if (_kOnlineFirst) {
    // Network first; fallback to cache
    try {
      return await _fetchFresh(ref.read, tenantId, branchId, status);
    } catch (e) {
      final mem = _memCache[key];
      if (mem != null) return mem;
      try {
        final raw = ref.read(prefsProvider).getString(key);
        if (raw != null && raw.isNotEmpty) {
          final arr = (convert.jsonDecode(raw) as List).cast<Map>();
          final parsed = arr.map((e) => KotCardData.fromMap(Map<String, dynamic>.from(e))).toList();
          final effective = _overlayAndMergeForLane(parsed, status);
          _memCache[key] = effective;
          return effective;
        }
      } catch (_) {}
      rethrow; // nothing cached — surface the error
    }
  }

  // Offline‑first path (cache -> refresh)
  final mem = _memCache[key];
  if (mem != null) {
    unawaited(_refreshKot(ref.read, tenantId, branchId, status));
    return mem;
  }

  try {
    final raw = ref.read(prefsProvider).getString(key);
    if (raw != null && raw.isNotEmpty) {
      final arr = (convert.jsonDecode(raw) as List).cast<Map>();
      final parsed = arr.map((e) => KotCardData.fromMap(Map<String, dynamic>.from(e))).toList();
      final effective = _overlayAndMergeForLane(parsed, status);
      _memCache[key] = effective;
      unawaited(_refreshKot(ref.read, tenantId, branchId, status));
      return effective;
    }
  } catch (_) {}

  return _fetchFresh(ref.read, tenantId, branchId, status);
});

// ------------------------------------------------------------------
// UI
// ------------------------------------------------------------------
class KotPage extends ConsumerWidget {
  const KotPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pump the poller
    ref.watch(_kotAutoPollProvider);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Kitchen Tickets', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh all',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  for (final st in KOTStatus.values) {
                    ref.invalidate(kotTicketsProvider(st));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Expanded(
            child: Row(
              children: [
                Expanded(child: _KotColumn(title: 'New', status: KOTStatus.NEW)),
                VerticalDivider(width: 1),
                Expanded(child: _KotColumn(title: 'In Progress', status: KOTStatus.IN_PROGRESS)),
                VerticalDivider(width: 1),
                Expanded(child: _KotColumn(title: 'Ready', status: KOTStatus.READY)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KotColumn extends ConsumerWidget {
  const _KotColumn({required this.title, required this.status});
  final String title;
  final KOTStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTickets = ref.watch(kotTicketsProvider(status));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              iconSize: 18,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.invalidate(kotTicketsProvider(status)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: asyncTickets.when(
            data: (tickets) {
              if (tickets.isEmpty) return const Center(child: Text('No tickets'));
              return ListView.separated(
                key: PageStorageKey('lane_${status.name}'),
                cacheExtent: 800,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                itemCount: tickets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _TicketCard(key: ValueKey(tickets[i].id), ticket: tickets[i]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Failed:\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketCard extends ConsumerStatefulWidget {
  const _TicketCard({super.key, required this.ticket});
  final KotCardData ticket;

  @override
  ConsumerState<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends ConsumerState<_TicketCard> {
  bool _expanded = false; // show all lines on the card

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final bgColor = _statusColor(t.status);
    final next = _nextStatus(t.status);
    final prev = _prevStatus(t.status);

    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DefaultTextStyle(
          style: const TextStyle(fontSize: 13, color: Colors.black),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: KOT, station, channel, age
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text('KOT ${_ticketLabel(t)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        if ((t.stationName ?? '').isNotEmpty)
                          const Text('• ', style: TextStyle(fontSize: 12)),
                        if ((t.stationName ?? '').isNotEmpty)
                          Text(t.stationName!, style: const TextStyle(fontSize: 12)),

                        if (t.channel != null) _ChannelChip(channel: t.channel!),
                        if (t.provider != null) _ProviderChip(provider: t.provider!),

                        if (t.createdAt != null)
                          Text('• ${_fmtWhen(t.createdAt!)}', style: const TextStyle(fontSize: 11)),
                        if (t.createdAt != null)
                          Text('(${_ago(t.createdAt)} ago)', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  // menu
                  PopupMenuButton<String>(
                    onSelected: (choice) async {
                      switch (choice) {
                        case 'details':
                          await _showDetailsSheet(context, t);
                          break;
                        case 'copyid':
                          final text = (t.orderNo?.isNotEmpty ?? false) ? t.orderNo! : (t.orderId ?? '');
                          if (text.isNotEmpty) {
                            await Clipboard.setData(ClipboardData(text: text));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                            }
                          }
                          break;
                        case 'reprint':
                          await _doReprint(context, ref.read, ref.invalidate, t);
                          break;
                        case 'cancel':
                          await _doCancel(context, ref.read, ref.invalidate, t);
                          break;
                        case 'status':
                          await _pickStatus(context, ref.read, ref.invalidate, t);
                          break;
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem<String>(value: 'details', child: Text('Details…')),
                      PopupMenuItem<String>(value: 'status', child: Text('Change status…')),
                      PopupMenuItem<String>(value: 'reprint', child: Text('Reprint')),
                      PopupMenuItem<String>(value: 'cancel', child: Text('Cancel')),
                      PopupMenuItem<String>(value: 'copyid', child: Text('Copy Order #')),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // table / waiter / provider order id
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if ((t.tableCode ?? '').isNotEmpty)
                    Text('Table ${t.tableCode}', style: const TextStyle(fontSize: 12)),
                  if ((t.waiterName ?? '').isNotEmpty)
                    Text('By ${t.waiterName}', style: const TextStyle(fontSize: 12)),
                  if ((t.providerOrderId ?? '').isNotEmpty)
                    Text('Ext #${t.providerOrderId}', style: const TextStyle(fontSize: 12)),
                ],
              ),

              const SizedBox(height: 2),

              // order id/no & quick item hints + chevron to expand
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      (t.orderNo != null && t.orderNo!.isNotEmpty)
                          ? 'Order ${t.orderNo}'
                          : (t.orderId != null ? 'Order ${t.orderId}' : 'Order'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (t.lines.isNotEmpty)
                    Text('${t.lines.length} items', style: const TextStyle(fontSize: 12)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    tooltip: _expanded ? 'Collapse' : 'Expand',
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  ),
                ],
              ),

              // Customer & address row
              if ((t.customerName ?? '').isNotEmpty || (t.customerPhone ?? '').isNotEmpty || (t.deliveryAddress ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if ((t.customerName ?? '').isNotEmpty)
                      Text('Cust: ${t.customerName}', style: const TextStyle(fontSize: 12)),
                    if ((t.customerPhone ?? '').isNotEmpty)
                      Text('📞 ${t.customerPhone}', style: const TextStyle(fontSize: 12)),
                    if ((t.deliveryAddress ?? '').isNotEmpty)
                      Text(
                        t.deliveryAddress!,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ],

              // Rider info
              if ((t.riderName ?? '').isNotEmpty || (t.riderStatus ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  [
                    if ((t.riderName ?? '').isNotEmpty) 'Rider: ${t.riderName}',
                    if ((t.riderStatus ?? '').isNotEmpty) '(${t.riderStatus})',
                  ].join(' '),
                  style: const TextStyle(fontSize: 12),
                ),
              ],

              if ((t.orderNote ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Note: ${t.orderNote}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ],

              // Quick item hint line
              if (!_expanded && t.lines.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _hintFromLines(t.lines),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],

              // Lines (bounded by cap when collapsed; all when expanded)
              if (t.lines.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...() {
                  final cap = _expanded ? t.lines.length : min(6, t.lines.length);
                  final List<Widget> shown = t.lines.take(cap).map<Widget>((ln) => _TicketLineRow(line: ln)).toList();
                  if (!_expanded && t.lines.length > cap) {
                    shown.add(const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text('+more…', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ));
                  }
                  return shown;
                }(),
              ],

              const SizedBox(height: 8),

              // Action row (back/forward)
              Row(
                children: [
                  if (prev != null)
                    TextButton.icon(
                      onPressed: () => _changeStatus(context, ref.read, ref.invalidate, t, prev, sourceStatus: t.status),
                      icon: const Icon(Icons.arrow_back),
                      label: Text('Back to ${prev.name}'),
                    ),
                  const Spacer(),
                  if (next != null)
                    FilledButton.icon(
                      onPressed: () => _changeStatus(context, ref.read, ref.invalidate, t, next, sourceStatus: t.status),
                      icon: const Icon(Icons.check),
                      label: Text('Mark ${next.name}'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetailsSheet(BuildContext context, KotCardData t) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('KOT ${_ticketLabel(t)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (t.createdAt != null)
                        Text(_fmtWhen(t.createdAt!), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if ((t.stationName ?? '').isNotEmpty) Chip(label: Text('Station: ${t.stationName}')),
                      if (t.channel != null) Chip(label: Text(_channelMeta(t.channel!).label)),
                      if (t.provider != null) Chip(label: Text(_providerMeta(t.provider!).label)),
                      if ((t.tableCode ?? '').isNotEmpty) Chip(label: Text('Table ${t.tableCode}')),
                      if ((t.waiterName ?? '').isNotEmpty) Chip(label: Text('By ${t.waiterName}')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (t.orderNo?.isNotEmpty ?? false) ? 'Order #${t.orderNo}' : (t.orderId != null ? 'Order ID ${t.orderId}' : 'Order'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if ((t.providerOrderId ?? '').isNotEmpty)
                    Text('External Ref: ${t.providerOrderId}'),
                  if ((t.customerName ?? '').isNotEmpty || (t.customerPhone ?? '').isNotEmpty)
                    Text('Customer: ${[t.customerName, t.customerPhone].where((e) => (e ?? '').isNotEmpty).join(' • ')}'),
                  if ((t.deliveryAddress ?? '').isNotEmpty)
                    Text('Address: ${t.deliveryAddress}'),
                  if ((t.riderName ?? '').isNotEmpty || (t.riderStatus ?? '').isNotEmpty)
                    Text('Rider: ${[t.riderName, t.riderStatus].where((e) => (e ?? '').isNotEmpty).join(' • ')}'),
                  if ((t.orderNote ?? '').isNotEmpty) Text('Note: ${t.orderNote}'),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Items (${t.lines.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ...t.lines.map((ln) => _TicketLineRow(line: ln, padding: const EdgeInsets.symmetric(vertical: 3))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(KOTStatus st) {
    switch (st) {
      case KOTStatus.NEW:
        return Colors.orange.shade100;
      case KOTStatus.IN_PROGRESS:
        return Colors.yellow.shade100;
      case KOTStatus.READY:
        return Colors.lightGreen.shade100;
      case KOTStatus.DONE:
        return Colors.green.shade200;
      case KOTStatus.CANCELLED:
        return Colors.red.shade100;
    }
  }

  KOTStatus? _nextStatus(KOTStatus st) {
    switch (st) {
      case KOTStatus.NEW:
        return KOTStatus.IN_PROGRESS;
      case KOTStatus.IN_PROGRESS:
        return KOTStatus.READY;
      case KOTStatus.READY:
        return KOTStatus.DONE;
      case KOTStatus.DONE:
      case KOTStatus.CANCELLED:
        return null;
    }
  }

  KOTStatus? _prevStatus(KOTStatus st) {
    switch (st) {
      case KOTStatus.NEW:
        return null;
      case KOTStatus.IN_PROGRESS:
        return KOTStatus.NEW;
      case KOTStatus.READY:
        return KOTStatus.IN_PROGRESS;
      case KOTStatus.DONE:
        return KOTStatus.READY;
      case KOTStatus.CANCELLED:
        return null;
    }
  }
}

// ------------------------------------------------------------------
// Helpers (TOP‑LEVEL) — accept `Ref` so they work from widgets & providers
// ------------------------------------------------------------------
void kotForceRefresh(Ref ref) {
  for (final st in KOTStatus.values) {
    ref.invalidate(kotTicketsProvider(st));
  }
}

Future<void> _changeStatus(
    BuildContext context,
    Read read,
    Invalidate invalidate,
    KotCardData t,
    KOTStatus target, {
      required KOTStatus sourceStatus,
    }) async {
  if (t.id.isEmpty) return;
  if (_busyTickets.contains(t.id)) return; // debounce rapid taps
  _busyTickets.add(t.id);

  final tenantId = read(kotTenantIdProvider);
  final branchId = read(kotBranchIdProvider);

  // Mark pending + optimistic move
  _pendingCancel.remove(t.id);
  _pendingStatus[t.id] = target;
  _ticketById[t.id] = t.copyWith(status: target);
  _optimisticMove(read, tenantId, branchId, t, target);

  // Only refresh source & destination lanes to reduce rebuilds
  invalidate(kotTicketsProvider(sourceStatus));
  invalidate(kotTicketsProvider(target));

  try {
    await read(apiClientProvider).patchKitchenTicketStatus(
      t.id,
      target,
      tenantId: tenantId,
      branchId: branchId,
    );
    _pendingStatus.remove(t.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('KOT ${_ticketLabel(t)} → ${target.name}')),
      );
    }
  } catch (_) {
    // Queue for retry (coalesced)
    await _enqueueKotOp(read, tenantId, branchId, _KotOp('status', t.id, {'next': target.name}));
    // Try push immediately to minimize delay
    unawaited(_pushKotQueue(read, tenantId, branchId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline: queued status update')),
      );
    }
  } finally {
    _busyTickets.remove(t.id);
  }
}

Future<void> _doReprint(BuildContext context, Read read, Invalidate invalidate, KotCardData t) async {
  final tenantId = read(kotTenantIdProvider);
  final branchId = read(kotBranchIdProvider);
  try {
    await read(apiClientProvider).reprintKitchenTicket(
      t.id,
      reason: 'Reprint from tablet',
      tenantId: tenantId,
      branchId: branchId,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Reprinted KOT ${_ticketLabel(t)}')));
    }
  } catch (_) {
    await _enqueueKotOp(
      read,
      tenantId,
      branchId,
      _KotOp('reprint', t.id, {'reason': 'Queued reprint'}),
    );
    unawaited(_pushKotQueue(read, tenantId, branchId));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Offline: reprint queued')));
    }
  }
}

Future<void> _doCancel(BuildContext context, Read read, Invalidate invalidate, KotCardData t) async {
  final reason = await _askReason(context, 'Cancel KOT ${_ticketLabel(t)}? Reason (optional)');
  if (reason == null) return;

  final tenantId = read(kotTenantIdProvider);
  final branchId = read(kotBranchIdProvider);

  // Mark pending cancel & optimistic remove
  _pendingStatus.remove(t.id);
  _pendingCancel.add(t.id);
  _optimisticRemove(read, tenantId, branchId, t);
  for (final st in [KOTStatus.NEW, KOTStatus.IN_PROGRESS, KOTStatus.READY, KOTStatus.DONE]) {
    invalidate(kotTicketsProvider(st));
  }

  try {
    await read(apiClientProvider).cancelKitchenTicket(
      t.id,
      reason: reason,
      tenantId: tenantId,
      branchId: branchId,
    );
    _pendingCancel.remove(t.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Cancelled KOT ${_ticketLabel(t)}')));
    }
  } catch (_) {
    await _enqueueKotOp(read, tenantId, branchId, _KotOp('cancel', t.id, {'reason': reason}));
    unawaited(_pushKotQueue(read, tenantId, branchId));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Offline: cancel queued')));
    }
  }
}

Future<void> _pickStatus(BuildContext ctx, Read read, Invalidate invalidate, KotCardData t) async {
  final choice = await showDialog<KOTStatus>(
    context: ctx,
    builder: (dialogCtx) => SimpleDialog(
      title: Text(
        'Change status',
        style: Theme.of(dialogCtx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      children: KOTStatus.values
          .where((s) => s != KOTStatus.CANCELLED)
          .map((s) => SimpleDialogOption(
        onPressed: () => Navigator.of(dialogCtx).pop(s),
        child: Text(s.name),
      ))
          .toList(),
    ),
  );
  if (choice == null || choice == t.status) return;
  await _changeStatus(ctx, read, invalidate, t, choice, sourceStatus: t.status);
}

Future<String?> _askReason(BuildContext ctx, String prompt) async {
  final ctl = TextEditingController();
  final res = await showDialog<String>(
    context: ctx,
    builder: (dialogCtx) => AlertDialog(
      title: Text(prompt),
      content: TextField(controller: ctl, decoration: const InputDecoration(labelText: 'Reason')),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogCtx).pop(null), child: const Text('No')),
        FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(ctl.text.trim()), child: const Text('OK')),
      ],
    ),
  );
  return res;
}

// Optimistic cache mutations -------------------------------------------------
void _optimisticMove(Read read, String tenantId, String branchId, KotCardData t, KOTStatus next) {
  // remove from all lists; add to next
  for (final st in KOTStatus.values) {
    final key = _kb(tenantId, branchId, st);
    final cur = _memCache[key];
    if (cur != null) {
      _memCache[key] = cur.where((e) => e.id != t.id).toList();
    }
  }
  final dstKey = _kb(tenantId, branchId, next);
  final dst = _memCache[dstKey] ?? <KotCardData>[];
  _memCache[dstKey] = [t.copyWith(status: next), ...dst];
}

void _optimisticRemove(Read read, String tenantId, String branchId, KotCardData t) {
  for (final st in KOTStatus.values) {
    final key = _kb(tenantId, branchId, st);
    final cur = _memCache[key];
    if (cur != null) {
      _memCache[key] = cur.where((e) => e.id != t.id).toList();
    }
  }
}

// Render one ticket line (qty × name [+ variant/mods]) -----------------------
class _TicketLineRow extends StatelessWidget {
  const _TicketLineRow({required this.line, this.padding = const EdgeInsets.only(top: 2)});

  // NOTE: Use KotLineLite (offline‑friendly) not KitchenTicketLine
  final KotLineLite line;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final variant = (line.variantLabel?.isNotEmpty ?? false) ? ' (${line.variantLabel})' : '';
    final mods = _modsSummaryLite(line);
    final qtyStr = _fmtQty(line.qty);

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$qtyStr× ', style: const TextStyle(fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(
              '${line.name}$variant$mods',
              maxLines: 99,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({required this.channel});
  final OrderChannel channel;

  @override
  Widget build(BuildContext context) {
    final meta = _channelMeta(channel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 12),
          const SizedBox(width: 4),
          Text(meta.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.provider});
  final OnlineProvider provider;

  @override
  Widget build(BuildContext context) {
    final meta = _providerMeta(provider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 12),
          const SizedBox(width: 4),
          Text(meta.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
