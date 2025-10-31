// features/kot/kot_page.dart
// Fast + Offline‑first KOT board (DROP‑IN v3)
// Key upgrades vs v2:
// - Pending overlay: server refreshes can’t undo your local moves.
// - Queue coalescing: only the latest status per ticket is kept.
// - Immediate queue push after enqueue (no 15s wait).
// - Faster polling (6s) + debounced taps + keyed list for stability.
// - Cancel is instant: removed from all lanes and hidden until server confirms.
// - More details: order type chip, hints, waiter/table, notes, age.

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

// ------------------------------------------------------------------
// Config
// ------------------------------------------------------------------
const int _kPollSeconds = 6; // faster refresh

// ------------------------------------------------------------------
// Types & helpers
// ------------------------------------------------------------------
typedef Read = T Function<T>(ProviderListenable<T> provider);

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

DateTime? _extractCreatedAt(dynamic t) {
  try {
    final v = t.createdAt;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
  } catch (_) {}
  return null;
}

// User‑facing channel chip text/icon
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
    qty: m['qty'] ?? 1,
    name: m['name']?.toString() ?? '',
    variantLabel: (m['variantLabel']?.toString().isEmpty ?? true)
        ? null
        : m['variantLabel'].toString(),
    modifiers: (m['modifiers'] as List?)
        ?.map((e) => e.toString())
        .toList() ??
        const <String>[],
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
  final DateTime? createdAt;
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
    required this.createdAt,
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
    createdAt: createdAt,
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
    'lines': lines.map((e) => e.toMap()).toList(),
  };

  factory KotCardData.fromMap(Map<String, dynamic> m) => KotCardData(
    id: m['id']?.toString() ?? '',
    ticketNo: (m['ticketNo'] as num?)?.toInt() ?? 0,
    status: KOTStatus.values
        .firstWhere((e) => e.name == m['status'], orElse: () => KOTStatus.NEW),
    stationName:
    (m['stationName']?.toString().isEmpty ?? true) ? null : m['stationName'].toString(),
    tableCode: (m['tableCode']?.toString().isEmpty ?? true) ? null : m['tableCode'].toString(),
    waiterName: (m['waiterName']?.toString().isEmpty ?? true) ? null : m['waiterName'].toString(),
    orderNo: (m['orderNo']?.toString().isEmpty ?? true) ? null : m['orderNo'].toString(),
    orderId: (m['orderId']?.toString().isEmpty ?? true) ? null : m['orderId'].toString(),
    orderNote: (m['orderNote']?.toString().isEmpty ?? true) ? null : m['orderNote'].toString(),
    channel: (() {
      final s = m['channel']?.toString();
      if (s == null || s.isEmpty) return null;
      return OrderChannel.values
          .firstWhere((e) => e.name == s, orElse: () => OrderChannel.TAKEAWAY);
    })(),
    createdAt: (() {
      final s = m['createdAt']?.toString();
      return s == null || s.isEmpty ? null : DateTime.tryParse(s);
    })(),
    lines: (m['lines'] as List?)
        ?.map((e) => KotLineLite.fromMap(Map<String, dynamic>.from(e)))
        .toList() ??
        const <KotLineLite>[],
  );

  static KotCardData fromKitchenTicket(KitchenTicket t) {
    final List<KotLineLite> ls = <KotLineLite>[];
    try {
      final ln = t.lines;
      if (ln is List) {
        for (final l in ln) {
          dynamic name;
          dynamic qty;
          dynamic vlabel;
          List<String> mods = <String>[];
          try {
            name = (l as dynamic).name;
          } catch (_) {}
          try {
            qty = (l as dynamic).qty;
          } catch (_) {}
          try {
            vlabel = (l as dynamic).variantLabel;
          } catch (_) {}
          try {
            final raw = (l as dynamic).modifiers;
            if (raw is List) {
              mods = raw
                  .map((e) => e is String
                  ? e
                  : ((e as dynamic).name ?? e.toString()).toString())
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
      }
    } catch (_) {}

    return KotCardData(
      id: (t.id ?? '').toString(),
      ticketNo: t.ticketNo,
      status: t.status,
      stationName: (t.stationName?.trim().isEmpty ?? true) ? null : t.stationName,
      tableCode: (t.tableCode?.trim().isEmpty ?? true) ? null : t.tableCode,
      waiterName: (t.waiterName?.trim().isNotEmpty ?? false) ? t.waiterName : null,
      orderNo: (t.orderNo?.trim().isNotEmpty ?? false) ? t.orderNo : null,
      orderId: (t.orderId?.toString().trim().isNotEmpty ?? false) ? t.orderId?.toString() : null,
      orderNote: (t.orderNote?.trim().isNotEmpty ?? false) ? t.orderNote : null,
      channel: _extractChannel(t),
      createdAt: _extractCreatedAt(t),
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
  out.sort((a, b) => b.ticketNo.compareTo(a.ticketNo));
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
// Provider: SWR (serve cache immediately, then refresh in background)
// ------------------------------------------------------------------
final kotTicketsProvider = FutureProvider.family.autoDispose<List<KotCardData>, KOTStatus>((ref, status) async {
  final tenantId = ref.watch(kotTenantIdProvider);
  final branchId = ref.watch(kotBranchIdProvider);
  ref.watch(_kotAutoPollProvider); // keep poller alive while page open
  final key = _kb(tenantId, branchId, status);

  // 1) Memory cache (already overlayed)
  final mem = _memCache[key];
  if (mem != null) {
    unawaited(_refreshKot(ref.read, tenantId, branchId, status));
    return mem;
  }

  // 2) Disk cache -> overlay
  try {
    final prefs = ref.read(prefsProvider);
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      final arr = (convert.jsonDecode(raw) as List).cast<Map>();
      final parsed = arr.map((e) => KotCardData.fromMap(Map<String, dynamic>.from(e))).toList();
      final effective = _overlayAndMergeForLane(parsed, status);
      _memCache[key] = effective;
      unawaited(_refreshKot(ref.read, tenantId, branchId, status));
      return effective;
    }
  } catch (_) {}

  // 3) Network (first load)
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

class _TicketCard extends ConsumerWidget {
  const _TicketCard({super.key, required this.ticket});
  final KotCardData ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor = _statusColor(ticket.status);
    final next = _nextStatus(ticket.status);
    final prev = _prevStatus(ticket.status);

    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: next == null
            ? null
            : () => _changeStatus(context, ref, ticket, next, sourceStatus: ticket.status),
        onLongPress: prev == null
            ? null
            : () => _changeStatus(context, ref, ticket, prev, sourceStatus: ticket.status),
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
                          Text('KOT #${ticket.ticketNo}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          if ((ticket.stationName ?? '').isNotEmpty)
                            const Text('• ', style: TextStyle(fontSize: 12)),
                          if ((ticket.stationName ?? '').isNotEmpty)
                            Text(ticket.stationName!, style: const TextStyle(fontSize: 12)),
                          if (ticket.channel != null) _ChannelChip(channel: ticket.channel!),
                          if (ticket.createdAt != null)
                            Text('• ${_ago(ticket.createdAt)} ago',
                                style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (choice) async {
                        switch (choice) {
                          case 'reprint':
                            await _doReprint(context, ref, ticket);
                            break;
                          case 'cancel':
                            await _doCancel(context, ref, ticket);
                            break;
                          case 'status':
                            await _pickStatus(context, ref, ticket);
                            break;
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem<String>(value: 'status', child: Text('Change status…')),
                        PopupMenuItem<String>(value: 'reprint', child: Text('Reprint')),
                        PopupMenuItem<String>(value: 'cancel', child: Text('Cancel')),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // table / waiter
                Text(
                  [
                    if ((ticket.tableCode ?? '').isNotEmpty) 'Table ${ticket.tableCode}',
                    if ((ticket.waiterName ?? '').isNotEmpty) 'By ${ticket.waiterName}',
                  ].join(' • '),
                  style: const TextStyle(fontSize: 12),
                ),

                const SizedBox(height: 2),

                // order id/no & quick item hints
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        (ticket.orderNo != null && ticket.orderNo!.isNotEmpty)
                            ? 'Order ${ticket.orderNo}'
                            : (ticket.orderId != null ? 'Order ${ticket.orderId}' : 'Order'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (ticket.lines.isNotEmpty)
                      Text('${ticket.lines.length} items', style: const TextStyle(fontSize: 12)),
                  ],
                ),

                if ((ticket.orderNote ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Note: ${ticket.orderNote}',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ],

                // Quick item hint line
                if (ticket.lines.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _hintFromLines(ticket.lines),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],

                // Lines (bounded; show max 6 + overflow indicator)
                if (ticket.lines.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...() {
                    final cap = min(6, ticket.lines.length);
                    final List<Widget> shown =
                    ticket.lines.take(cap).map<Widget>((ln) => _TicketLineRow(line: ln)).toList();
                    if (ticket.lines.length > cap) {
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
                        onPressed: () => _changeStatus(context, ref, ticket, prev, sourceStatus: ticket.status),
                        icon: const Icon(Icons.arrow_back),
                        label: Text('Back to ${prev.name}'),
                      ),
                    const Spacer(),
                    if (next != null)
                      FilledButton.icon(
                        onPressed: () => _changeStatus(context, ref, ticket, next, sourceStatus: ticket.status),
                        icon: const Icon(Icons.check),
                        label: Text('Mark ${next.name}'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

  Future<void> _changeStatus(
      BuildContext context,
      WidgetRef ref,
      KotCardData t,
      KOTStatus target, {
        required KOTStatus sourceStatus,
      }) async {
    if (t.id.isEmpty) return;
    if (_busyTickets.contains(t.id)) return; // debounce rapid taps
    _busyTickets.add(t.id);

    final tenantId = ref.read(kotTenantIdProvider);
    final branchId = ref.read(kotBranchIdProvider);

    // Mark pending + optimistic move
    _pendingCancel.remove(t.id);
    _pendingStatus[t.id] = target;
    _ticketById[t.id] = t.copyWith(status: target);
    _optimisticMove(ref.read, tenantId, branchId, t, target);

    // Only refresh source & destination lanes to reduce rebuilds
    ref.invalidate(kotTicketsProvider(sourceStatus));
    ref.invalidate(kotTicketsProvider(target));

    try {
      await ref.read(apiClientProvider).patchKitchenTicketStatus(
        t.id,
        target,
        tenantId: tenantId,
        branchId: branchId,
      );
      _pendingStatus.remove(t.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('KOT #${t.ticketNo} → ${target.name}')),
        );
      }
    } catch (_) {
      // Queue for retry (coalesced)
      await _enqueueKotOp(ref.read, tenantId, branchId, _KotOp('status', t.id, {'next': target.name}));
      // Try push immediately to minimize delay
      unawaited(_pushKotQueue(ref.read, tenantId, branchId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline: queued status update')),
        );
      }
    } finally {
      _busyTickets.remove(t.id);
    }
  }

  Future<void> _doReprint(BuildContext context, WidgetRef ref, KotCardData t) async {
    final tenantId = ref.read(kotTenantIdProvider);
    final branchId = ref.read(kotBranchIdProvider);
    try {
      await ref.read(apiClientProvider).reprintKitchenTicket(
        t.id,
        reason: 'Reprint from tablet',
        tenantId: tenantId,
        branchId: branchId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Reprinted KOT #${t.ticketNo}')));
      }
    } catch (_) {
      await _enqueueKotOp(
          ref.read, tenantId, branchId, _KotOp('reprint', t.id, {'reason': 'Queued reprint'}));
      unawaited(_pushKotQueue(ref.read, tenantId, branchId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Offline: reprint queued')));
      }
    }
  }

  Future<void> _doCancel(BuildContext context, WidgetRef ref, KotCardData t) async {
    final reason = await _askReason(context, 'Cancel KOT #${t.ticketNo}? Reason (optional)');
    if (reason == null) return;

    final tenantId = ref.read(kotTenantIdProvider);
    final branchId = ref.read(kotBranchIdProvider);

    // Mark pending cancel & optimistic remove
    _pendingStatus.remove(t.id);
    _pendingCancel.add(t.id);
    _optimisticRemove(ref.read, tenantId, branchId, t);
    for (final st in [KOTStatus.NEW, KOTStatus.IN_PROGRESS, KOTStatus.READY, KOTStatus.DONE]) {
      ref.invalidate(kotTicketsProvider(st));
    }

    try {
      await ref.read(apiClientProvider).cancelKitchenTicket(
        t.id,
        reason: reason,
        tenantId: tenantId,
        branchId: branchId,
      );
      _pendingCancel.remove(t.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Cancelled KOT #${t.ticketNo}')));
      }
    } catch (_) {
      await _enqueueKotOp(ref.read, tenantId, branchId, _KotOp('cancel', t.id, {'reason': reason}));
      unawaited(_pushKotQueue(ref.read, tenantId, branchId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Offline: cancel queued')));
      }
    }
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

  Future<void> _pickStatus(BuildContext ctx, WidgetRef ref, KotCardData t) async {
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
    await _changeStatus(ctx, ref, t, choice, sourceStatus: t.status);
  }
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
  const _TicketLineRow({
    required this.line,
    this.padding = const EdgeInsets.symmetric(vertical: 2),
  });

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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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
