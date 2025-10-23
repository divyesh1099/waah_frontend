import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_client.dart';
import '../../data/models.dart';

/// Filter: show only a given KOT status (or all)
final kotStatusFilterProvider = StateProvider<KOTStatus?>((_) => null);

/// Loads tickets for the selected status
final kitchenTicketsFutureProvider =
FutureProvider.autoDispose<List<KitchenTicket>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final status = ref.watch(kotStatusFilterProvider);
  final list = await client.fetchKitchenTickets(status: status);
  // sort: newest first
  list.sort((a, b) {
    final aT = a.createdAt?.millisecondsSinceEpoch ?? 0;
    final bT = b.createdAt?.millisecondsSinceEpoch ?? 0;
    return bT.compareTo(aT);
  });
  return list;
});

class KitchenTicketsPage extends ConsumerWidget {
  const KitchenTicketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(kitchenTicketsFutureProvider);
    final status = ref.watch(kotStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Tickets'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(kitchenTicketsFutureProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            status: status,
            onChanged: (s) => ref.read(kotStatusFilterProvider.notifier).state = s,
          ),
          const Divider(height: 0),
          Expanded(
            child: ticketsAsync.when(
              data: (list) {
                if (list.isEmpty) return const _Empty();
                final grouped = _groupByStation(list);
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(kitchenTicketsFutureProvider),
                  child: ListView(
                    children: grouped.entries.map((e) {
                      final station = e.key?.isNotEmpty == true ? e.key! : 'Unassigned';
                      final items = e.value;
                      return _StationSection(station: station, tickets: items);
                    }).toList(),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Error(
                message: 'Failed to load tickets:\n$e',
                onRetry: () => ref.invalidate(kitchenTicketsFutureProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String?, List<KitchenTicket>> _groupByStation(List<KitchenTicket> list) {
    final map = <String?, List<KitchenTicket>>{};
    for (final t in list) {
      final k = t.targetStation;
      (map[k] ??= []).add(t);
    }
    return map;
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.status, required this.onChanged});
  final KOTStatus? status;
  final void Function(KOTStatus?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          const Text('Status:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          DropdownButton<KOTStatus?>(
            value: status,
            items: [
              const DropdownMenuItem(value: null, child: Text('All')),
              ...KOTStatus.values.map(
                    (s) => DropdownMenuItem(value: s, child: Text(s.name)),
              ),
            ],
            onChanged: onChanged,
          ),
          const Spacer(),
          // space for quick search or station filter later
        ],
      ),
    );
  }
}

class _StationSection extends StatelessWidget {
  const _StationSection({required this.station, required this.tickets});
  final String station;
  final List<KitchenTicket> tickets;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text('$station  (${tickets.length})'),
      children: tickets.map((t) => _TicketTile(ticket: t)).toList(),
    );
  }
}

class _TicketTile extends ConsumerWidget {
  const _TicketTile({required this.ticket});
  final KitchenTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final created = ticket.createdAt?.toLocal();
    final createdStr = created == null
        ? '—'
        : '${_2(created.hour)}:${_2(created.minute)}  '
        '${created.year}-${_2(created.month)}-${_2(created.day)}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${ticket.ticketNo}'),
        ),
        title: Text('Ticket #${ticket.ticketNo}  •  ${ticket.status.name}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Order: ${ticket.orderId ?? '—'}\nCreated: $createdStr'),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 8,
          children: [
            _StatusChip(status: ticket.status),
            // Optional action: advance status (only if your API supports it)
            IconButton(
              tooltip: 'Advance status',
              icon: const Icon(Icons.playlist_add_check),
              onPressed: () async {
                final next = _nextStatus(ticket.status);
                if (next == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No next status')),
                  );
                  return;
                }
                try {
                  // If you added patchKitchenTicketStatus (see Step 2), this will work.
                  await ref.read(apiClientProvider)
                      .patchKitchenTicketStatus(ticket.id, next);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Marked as ${next.name}')),
                  );
                  ref.invalidate(kitchenTicketsFutureProvider);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Update failed: $e')),
                  );
                }
              },
            ),
          ],
        ),
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => _TicketDetailsDialog(ticket: ticket),
          );
        },
      ),
    );
  }

  String _2(int v) => v.toString().padLeft(2, '0');

  /// Simple progression NEW → IN_PROGRESS → READY → DONE
  KOTStatus? _nextStatus(KOTStatus s) {
    switch (s) {
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
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final KOTStatus status;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    switch (status) {
      case KOTStatus.NEW:
        bg = Colors.orange.shade100;
        break;
      case KOTStatus.IN_PROGRESS:
        bg = Colors.amber.shade100;
        break;
      case KOTStatus.READY:
        bg = Colors.lightGreen.shade100;
        break;
      case KOTStatus.DONE:
        bg = Colors.blueGrey.shade100;
        break;
      case KOTStatus.CANCELLED:
        bg = Colors.red.shade100;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.name, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No kitchen tickets.'),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _TicketDetailsDialog extends StatelessWidget {
  const _TicketDetailsDialog({required this.ticket});
  final KitchenTicket ticket;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ticket #${ticket.ticketNo}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('ID', ticket.id),
          _row('Order', ticket.orderId ?? '—'),
          _row('Station', ticket.targetStation ?? '—'),
          _row('Status', ticket.status.name),
          _row('Printed at', ticket.printedAt?.toLocal().toString() ?? '—'),
          _row('Reprints', '${ticket.reprintCount}'),
          if ((ticket.cancelReason ?? '').isNotEmpty)
            _row('Cancel reason', ticket.cancelReason!),
          _row('Created', ticket.createdAt?.toLocal().toString() ?? '—'),
          _row('Updated', ticket.updatedAt?.toLocal().toString() ?? '—'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text('$k:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
