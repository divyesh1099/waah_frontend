import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/models.dart';

/// Fetch ONLINE channel orders for the active tenant+branch.
/// Includes ZOMATO / SWIGGY etc.
final onlineOrdersProvider =
FutureProvider.autoDispose<List<Order>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final tenantId = ref.watch(activeTenantIdProvider);
  final branchId = ref.watch(activeBranchIdProvider);

  // If we don't know tenant/branch yet, nothing to show.
  if (tenantId.isEmpty || branchId.isEmpty) {
    return <Order>[];
  }

  final pageRes = await api.fetchOrders(
    channel: OrderChannel.ONLINE,
    tenantId: tenantId,
    branchId: branchId,
    page: 1,
    size: 100,
  );

  // Copy & sort newest-first by openedAt
  final list = [...pageRes.items];
  list.sort((a, b) {
    final ad = a.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bd = b.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bd.compareTo(ad); // latest first
  });

  return list;
});

/// Human label for provider chip.
String _providerLabel(OnlineProvider? p) {
  switch (p) {
    case OnlineProvider.ZOMATO:
      return 'Zomato';
    case OnlineProvider.SWIGGY:
      return 'Swiggy';
    case OnlineProvider.CUSTOM:
      return 'Custom';
    default:
      return 'OTHER';
  }
}

/// Brand color for provider chip.
Color _providerColor(OnlineProvider? p) {
  switch (p) {
    case OnlineProvider.ZOMATO:
      return Colors.red;
    case OnlineProvider.SWIGGY:
      return Colors.deepOrange;
    case OnlineProvider.CUSTOM:
      return Colors.blueGrey;
    default:
      return Colors.grey;
  }
}

/// Little rounded chip for "Zomato", "Swiggy", etc.
Widget _providerChip(OnlineProvider? p) {
  final c = _providerColor(p);
  final t = _providerLabel(p);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c, width: 1),
    ),
    child: Text(
      t,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: c,
      ),
    ),
  );
}

/// Color for order status chip.
Color _statusColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.OPEN:
      return Colors.blueGrey;
    case OrderStatus.KITCHEN:
      return Colors.orange;
    case OrderStatus.READY:
      return Colors.blue;
    case OrderStatus.SERVED:
      return Colors.green;
    case OrderStatus.CLOSED:
      return Colors.grey;
    case OrderStatus.VOID:
      return Colors.red;
  }
}

/// Rounded status chip ("OPEN", "READY", ...)
Widget _statusChip(OrderStatus s) {
  final c = _statusColor(s);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c, width: 1),
    ),
    child: Text(
      s.name,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: c,
      ),
    ),
  );
}

/// Simple dd/mm hh:mm for "opened at"
String _fmtWhen(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final mon = local.month.toString().padLeft(2, '0');
  return '$day/$mon $hh:$mm';
}

/// The actual page shown at /online
class OnlinePage extends ConsumerWidget {
  const OnlinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(activeTenantIdProvider);
    final branchId = ref.watch(activeBranchIdProvider);

    final asyncOrders = ref.watch(onlineOrdersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------- Header row ----------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Text(
                'Online Orders',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Branch: ${branchId.isEmpty ? "—" : branchId}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // ---------- Body list ----------
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // force refetch
              ref.invalidate(onlineOrdersProvider);
            },
            child: asyncOrders.when(
              loading: () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
              error: (err, st) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error loading online orders:\n$err',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              data: (orders) {
                // No branch selected yet
                if (tenantId.isEmpty || branchId.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No branch selected.\nPlease choose a branch first.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  );
                }

                // No orders yet
                if (orders.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No online orders yet.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  );
                }

                // Render each order as a Card row
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 24,
                  ),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final o = orders[index];
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.black12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // LEFT: Platform + Status
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _providerChip(o.provider),
                                const SizedBox(height: 8),
                                _statusChip(o.status),
                              ],
                            ),

                            const SizedBox(width: 12),

                            // MIDDLE: Order info
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o.orderNo ?? '(no orderNo)',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Opened ${_fmtWhen(o.openedAt)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  if (o.note != null &&
                                      o.note!.trim().isNotEmpty)
                                    Padding(
                                      padding:
                                      const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        o.note!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // RIGHT: Channel + Details button (future hook)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  o.channel.name, // should be "ONLINE"
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    // hook for full order view / actions
                                    // Example future nav:
                                    // context.go('/orders?orderId=${o.id}');
                                  },
                                  child: const Text('Details'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
