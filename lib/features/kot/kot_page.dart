import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// ------------------------------------------------------------------
/// Session/Context: tenant & branch (plug your auth/session later)
/// ------------------------------------------------------------------
final kotTenantIdProvider = StateProvider<String>((_) => '');
final kotBranchIdProvider = StateProvider<String>((_) => '');

/// ------------------------------------------------------------------
/// Data: tickets per status (tenant/branch aware)
/// ------------------------------------------------------------------
final kotTicketsProvider = FutureProvider.family
    .autoDispose<List<KitchenTicket>, KOTStatus>((ref, status) async {
  final api = ref.watch(apiClientProvider);
  final tenantId = ref.watch(kotTenantIdProvider);
  final branchId = ref.watch(kotBranchIdProvider);

  final list = await api.fetchKitchenTickets(
    status: status,
    tenantId: tenantId,
    branchId: branchId,
  );

  // newest first
  list.sort((a, b) => b.ticketNo.compareTo(a.ticketNo));
  return list;
});

class KotPage extends ConsumerWidget {
  const KotPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Tiny filter/header row (tenant/branch placeholders for now)
          Row(
            children: [
              const Text(
                'Kitchen Tickets',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
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
                Expanded(
                  child: _KotColumn(
                    title: 'New',
                    status: KOTStatus.NEW,
                  ),
                ),
                VerticalDivider(width: 1),
                Expanded(
                  child: _KotColumn(
                    title: 'In Progress',
                    status: KOTStatus.IN_PROGRESS,
                  ),
                ),
                VerticalDivider(width: 1),
                Expanded(
                  child: _KotColumn(
                    title: 'Ready',
                    status: KOTStatus.READY,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KotColumn extends ConsumerWidget {
  const _KotColumn({
    required this.title,
    required this.status,
  });

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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              iconSize: 18,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: () {
                ref.invalidate(kotTicketsProvider(status));
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: asyncTickets.when(
            data: (tickets) {
              if (tickets.isEmpty) {
                return const Center(
                  child: Text('No tickets'),
                );
              }
              return ListView.separated(
                itemCount: tickets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  return _TicketCard(ticket: tickets[i]);
                },
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
  final KitchenTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor = _statusColor(ticket.status);
    final next = _nextStatus(ticket.status);

    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () async {
          // tap card = advance to next status in the kitchen workflow
          if (next == null || (ticket.id ?? '').isEmpty) return;
          try {
            final api = ref.read(apiClientProvider);
            final tenantId = ref.read(kotTenantIdProvider);
            final branchId = ref.read(kotBranchIdProvider);

            await api.patchKitchenTicketStatus(
              ticket.id!,
              next,
              tenantId: tenantId,
              branchId: branchId,
            );

            // refresh all boards since the card moves columns
            for (final st in KOTStatus.values) {
              ref.invalidate(kotTicketsProvider(st));
            }

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('KOT #${ticket.ticketNo} → ${next.name}')),
              );
            }
          } catch (err) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Update failed: $err')),
              );
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
                // header row with popup menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'KOT #${ticket.ticketNo}'
                            '${ticket.stationName != null ? " • ${ticket.stationName}" : ""}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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

                // table / waiter row
                Text(
                  [
                    if (ticket.tableCode != null && ticket.tableCode!.trim().isNotEmpty)
                      'Table ${ticket.tableCode}',
                    if (ticket.waiterName != null && ticket.waiterName!.trim().isNotEmpty)
                      'By ${ticket.waiterName}',
                  ].join(' • '),
                  style: const TextStyle(fontSize: 12),
                ),

                const SizedBox(height: 2),

                // order no row
                Text(
                  (ticket.orderNo != null && ticket.orderNo!.isNotEmpty)
                      ? 'Order ${ticket.orderNo}'
                      : 'Order ${ticket.orderId}',
                  style: const TextStyle(fontSize: 12),
                ),

                if (ticket.orderNote != null && ticket.orderNote!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Note: ${ticket.orderNote}',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],

                // line items (if backend returns them)
                if ((ticket.lines?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 8),
                  ...ticket.lines!.map((ln) => _TicketLineRow(line: ln)).toList(),
                ],

                const SizedBox(height: 8),
                Text(
                  next == null ? 'Done' : 'Tap to mark ${next.name}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
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

  Future<void> _doReprint(
      BuildContext context,
      WidgetRef ref,
      KitchenTicket t,
      ) async {
    try {
      final api = ref.read(apiClientProvider);
      final tenantId = ref.read(kotTenantIdProvider);
      final branchId = ref.read(kotBranchIdProvider);

      await api.reprintKitchenTicket(
        t.id!,
        reason: 'Reprint from tablet',
        tenantId: tenantId,
        branchId: branchId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reprinted KOT #${t.ticketNo}')),
        );
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reprint failed: $err')),
        );
      }
    }
  }

  Future<void> _doCancel(
      BuildContext context,
      WidgetRef ref,
      KitchenTicket t,
      ) async {
    final reason = await _askReason(context, 'Cancel KOT #${t.ticketNo}? Reason (optional)');
    if (reason == null) return;

    try {
      final api = ref.read(apiClientProvider);
      final tenantId = ref.read(kotTenantIdProvider);
      final branchId = ref.read(kotBranchIdProvider);

      await api.cancelKitchenTicket(
        t.id!,
        reason: reason,
        tenantId: tenantId,
        branchId: branchId,
      );

      // cancelled ticket should disappear from all visible boards
      for (final st in KOTStatus.values) {
        ref.invalidate(kotTicketsProvider(st));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cancelled KOT #${t.ticketNo}')),
        );
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cancel failed: $err')),
        );
      }
    }
  }

  Future<String?> _askReason(BuildContext ctx, String prompt) async {
    final ctl = TextEditingController();
    final res = await showDialog<String>(
      context: ctx,
      builder: (_) {
        return AlertDialog(
          title: Text(prompt),
          content: TextField(
            controller: ctl,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    return res;
  }
}

/// Render one ticket line (qty × name [+ variant/mods])
class _TicketLineRow extends StatelessWidget {
  const _TicketLineRow({required this.line});
  final KitchenTicketLine line; // make sure models.dart exposes this

  String _modsSummary(KitchenTicketLine ln) {
    // Accept either List<String> or List<ModifierLike>
    final mods = ln.modifiers ?? const [];
    if (mods.isEmpty) return '';
    final parts = <String>[];
    for (final m in mods) {
      if (m is String) {
        parts.add(m);
      } else {
        // fallback: try common keys
        final name = (m as dynamic).name ?? (m as dynamic)['name'];
        if (name != null) parts.add(name.toString());
      }
    }
    return parts.isEmpty ? '' : ' • ${parts.join(", ")}';
  }

  @override
  Widget build(BuildContext context) {
    final variant = (line.variantLabel != null && line.variantLabel!.isNotEmpty)
        ? ' (${line.variantLabel})'
        : '';
    final mods = _modsSummary(line);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${line.qty}× ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
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
