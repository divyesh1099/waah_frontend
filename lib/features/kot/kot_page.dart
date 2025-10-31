import 'dart:async';
import 'dart:convert' as convert;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

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
    variantLabel:
    (m['variantLabel']?.toString().isEmpty ?? true) ? null : m['variantLabel'].toString(),
    modifiers:
    (m['modifiers'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[],
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
    tableCode:
    (m['tableCode']?.toString().isEmpty ?? true) ? null : m['tableCode'].toString(),
    waiterName:
    (m['waiterName']?.toString().isEmpty ?? true) ? null : m['waiterName'].toString(),
    orderNo: (m['orderNo']?.toString().isEmpty ?? true) ? null : m['orderNo'].toString(),
    orderId: (m['orderId']?.toString().isEmpty ?? true) ? null : m['orderId'].toString(),
    orderNote:
    (m['orderNote']?.toString().isEmpty ?? true) ? null : m['orderNote'].toString(),
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
                  .map((e) => e is String ? e : ((e as dynamic).name ?? e.toString()).toString())
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

// ------------------------------------------------------------------
// Session/Context: tenant & branch (mirror global)
// ------------------------------------------------------------------
final kotTenantIdProvider = Provider<String>((ref) => ref.watch(activeTenantIdProvider));
final kotBranchIdProvider = Provider<String>((ref) => ref.watch(activeBranchIdProvider));

// ------------------------------------------------------------------
// In-memory cache + queued ops
// ------------------------------------------------------------------
final Map<String, List<KotCardData>> _memCache = {};

class _KotOp {
  final String type; // 'status' | 'reprint' | 'cancel'
  final String ticketId;
  final Map<String, dynamic> payload;
  _KotOp(this.type, this.ticketId, this.payload);
  Map<String, dynamic> toMap() => {'type': type, 'ticketId': ticketId, 'payload': payload};
  static _KotOp fromMap(Map<String, dynamic> m) => _KotOp(
      m['type'] as String, m['ticketId'] as String, Map<String, dynamic>.from(m['payload'] as Map));
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
  cur.add(op);
  await _writeKotQueue(read, tenantId, branchId, cur);
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
        await api.patchKitchenTicketStatus(op.ticketId, ns,
            tenantId: tenantId, branchId: branchId);
      } else if (op.type == 'reprint') {
        await api.reprintKitchenTicket(op.ticketId,
            reason: op.payload['reason']?.toString() ?? 'Queued reprint',
            tenantId: tenantId,
            branchId: branchId);
      } else if (op.type == 'cancel') {
        await api.cancelKitchenTicket(op.ticketId,
            reason: op.payload['reason']?.toString(),
            tenantId: tenantId,
            branchId: branchId);
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
Future<List<KotCardData>> _fetchFresh(
    Read read, String tenantId, String branchId, KOTStatus status) async {
  final api = read(apiClientProvider);
  final list = await api.fetchKitchenTickets(
    status: status,
    tenantId: tenantId.isEmpty ? null : tenantId,
    branchId: branchId.isEmpty ? null : branchId,
  );
  final mapped = list.map(KotCardData.fromKitchenTicket).toList()
    ..sort((a, b) => b.ticketNo.compareTo(a.ticketNo));

  // Write caches
  final key = _kb(tenantId, branchId, status);
  _memCache[key] = mapped;
  final prefs = read(prefsProvider);
  try {
    await prefs.setString(key, convert.jsonEncode(mapped.map((e) => e.toMap()).toList()));
  } catch (_) {}
  return mapped;
}

Future<void> _refreshKot(Read read, String tenantId, String branchId, KOTStatus status) async {
  try {
    await _fetchFresh(read, tenantId, branchId, status);
  } catch (_) {}
}

// ------------------------------------------------------------------
// Auto-refresh + queue pusher (polling every 15s)
// ------------------------------------------------------------------
final _kotAutoPollProvider = Provider<void>((ref) {
  final tenantId = ref.watch(kotTenantIdProvider);
  final branchId = ref.watch(kotBranchIdProvider);
  final t = Timer.periodic(const Duration(seconds: 15), (_) async {
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
final kotTicketsProvider =
FutureProvider.family.autoDispose<List<KotCardData>, KOTStatus>((ref, status) async {
  final tenantId = ref.watch(kotTenantIdProvider);
  final branchId = ref.watch(kotBranchIdProvider);
  ref.watch(_kotAutoPollProvider); // keep poller alive while page open
  final key = _kb(tenantId, branchId, status);

  // 1) Memory cache
  final mem = _memCache[key];
  if (mem != null) {
    // schedule background refresh
    unawaited(_refreshKot(ref.read, tenantId, branchId, status));
    return mem;
  }

  // 2) Disk cache
  try {
    final prefs = ref.read(prefsProvider);
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      final arr = (convert.jsonDecode(raw) as List).cast<Map>();
      final parsed =
      arr.map((e) => KotCardData.fromMap(Map<String, dynamic>.from(e))).toList();
      _memCache[key] = parsed;
      unawaited(_refreshKot(ref.read, tenantId, branchId, status));
      return parsed;
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
          Expanded(
            child: Row(
              children: const [
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
                itemCount: tickets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _TicketCard(ticket: tickets[i]),
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
  const _TicketCard({required this.ticket});
  final KotCardData ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor = _statusColor(ticket.status);
    final next = _nextStatus(ticket.status);

    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () async {
          if (next == null || ticket.id.isEmpty) return;
          final tenantId = ref.read(kotTenantIdProvider);
          final branchId = ref.read(kotBranchIdProvider);
          try {
            await ref
                .read(apiClientProvider)
                .patchKitchenTicketStatus(ticket.id, next, tenantId: tenantId, branchId: branchId);
            // refresh boards (move across columns)
            for (final st in KOTStatus.values) {
              ref.invalidate(kotTicketsProvider(st));
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('KOT #${ticket.ticketNo} → ${next.name}')));
            }
          } catch (_) {
            // Queue & optimistic move
            await _enqueueKotOp(
                ref.read, tenantId, branchId, _KotOp('status', ticket.id, {'next': next.name}));
            _optimisticMove(ref.read, tenantId, branchId, ticket, next);
            for (final st in KOTStatus.values) {
              ref.invalidate(kotTicketsProvider(st));
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Offline: queued status update')));
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DefaultTextStyle(
            style: const TextStyle(fontSize: 13, color: Colors.black),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: KOT, station, channel, age, menu
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
                            Text('• ${ticket.stationName}', style: const TextStyle(fontSize: 12)),
                          if (ticket.channel != null)
                            Container(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(.08),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(ticket.channel!.name.replaceAll('_', ' '),
                                  style: const TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
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
                        }
                      },
                      itemBuilder: (_) => const [
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

                // order no
                Text(
                  (ticket.orderNo != null && ticket.orderNo!.isNotEmpty)
                      ? 'Order ${ticket.orderNo}'
                      : (ticket.orderId != null ? 'Order ${ticket.orderId}' : 'Order'),
                  style: const TextStyle(fontSize: 12),
                ),

                if ((ticket.orderNote ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Note: ${ticket.orderNote}',
                      style:
                      const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ],

                // Lines (bounded; show max 6 + overflow indicator)
                if (ticket.lines.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...() {
                    final cap = min(6, ticket.lines.length);
                    final List<Widget> shown =
                    ticket.lines.take(cap).map<Widget>((ln) => _TicketLineRow(line: ln)).toList();
                    if (ticket.lines.length > cap) {
                      shown.add(const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text('+more…',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      ));
                    }
                    return shown;
                  }(),
                ],

                const SizedBox(height: 8),
                Text(
                    next == null ? 'Done' : 'Tap to mark ${next.name}',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade800)),
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

  Future<void> _doReprint(BuildContext context, WidgetRef ref, KotCardData t) async {
    final tenantId = ref.read(kotTenantIdProvider);
    final branchId = ref.read(kotBranchIdProvider);
    try {
      await ref
          .read(apiClientProvider)
          .reprintKitchenTicket(t.id, reason: 'Reprint from tablet', tenantId: tenantId, branchId: branchId);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Reprinted KOT #${t.ticketNo}')));
      }
    } catch (_) {
      await _enqueueKotOp(
          ref.read, tenantId, branchId, _KotOp('reprint', t.id, {'reason': 'Queued reprint'}));
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

    try {
      await ref
          .read(apiClientProvider)
          .cancelKitchenTicket(t.id, reason: reason, tenantId: tenantId, branchId: branchId);
      // remove from all columns
      _optimisticRemove(ref.read, tenantId, branchId, t);
      for (final st in KOTStatus.values) {
        ref.invalidate(kotTicketsProvider(st));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Cancelled KOT #${t.ticketNo}')));
      }
    } catch (_) {
      await _enqueueKotOp(
          ref.read, tenantId, branchId, _KotOp('cancel', t.id, {'reason': reason}));
      _optimisticRemove(ref.read, tenantId, branchId, t);
      for (final st in KOTStatus.values) {
        ref.invalidate(kotTicketsProvider(st));
      }
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
      builder: (_) => AlertDialog(
        title: Text(prompt),
        content: TextField(controller: ctl, decoration: const InputDecoration(labelText: 'Reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    return res;
  }
}

// Optimistic cache mutations -------------------------------------------------
void _optimisticMove(
    Read read, String tenantId, String branchId, KotCardData t, KOTStatus next) {
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

  // NOTE: Use KotLineLite (offline-friendly) not KitchenTicketLine
  final KotLineLite line;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final variant =
    (line.variantLabel?.isNotEmpty ?? false) ? ' (${line.variantLabel})' : '';
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
