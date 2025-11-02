// lib/features/orders/orders_page.dart
import 'dart:async';
import 'dart:convert' as convert;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../debug/queue_diag.dart';
import '../../app/providers.dart';
import '../orders/pending_orders.dart';
import '../../data/models.dart';
import '../kot/kot_page.dart';

// ---- Local queue helpers (same key/device as POS page) ----
const _kOpsQueueKey = 'pos_offline_ops_v1';
const _kDeviceId    = 'flutter-pos';

// --- FIX: Add the missing typedef ---
typedef Read = T Function<T>(ProviderListenable<T> provider);


// --- FIX: Change '_Read' to 'Read' ---
Future<List<Map<String, dynamic>>> _readQueuedOpsOrders(Read read) async {
  final prefs = read(prefsProvider);
  final raw = prefs.getString(_kOpsQueueKey);
  if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
  try {
    final decoded = convert.jsonDecode(raw);
    if (decoded is List) {
      return decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  } catch (_) {}
  return <Map<String, dynamic>>[];
}

// --- FIX: Change '_Read' to 'Read' ---
Future<void> _writeQueuedOpsOrders(Read read, List<Map<String, dynamic>> ops) async {
  final prefs = read(prefsProvider);
  await prefs.setString(_kOpsQueueKey, convert.jsonEncode(ops));
}

Set<String> _extractOrderNosOrders(List<Map<String, dynamic>> ops) {
  // ... (no change here)
  final out = <String>{};
  for (final op in ops) {
    final payload = op['payload'];
    if (payload is Map && payload['order_no'] != null) {
      final no = payload['order_no'].toString();
      if (no.isNotEmpty) out.add(no);
    }
  }
  return out;
}

// --- FIX: Change 'Ref' to 'ConsumerRef' ---
Future<void> _pushQueueFromOrders(BuildContext ctx, WidgetRef ref) async {
  final client = ref.read(apiClientProvider);
  final ops = await _readQueuedOpsOrders(ref.read); // This helper is fine
  if (ops.isEmpty) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Nothing to sync')));
    }
    return;
  }
  final orderNos = _extractOrderNosOrders(ops);
  try {
    await client.syncPush(deviceId: _kDeviceId, ops: ops);
    await _writeQueuedOpsOrders(ref.read, []); // This helper is fine
    ref.read(pendingOrdersProvider.notifier).removeByOrderNos(orderNos);

    // --- FIX: Use 'ref.invalidate(provider)' ---
    ref.invalidate(ordersFutureProvider); // For OrdersPage
    // For KotPage (invalidate all columns)
    for (final status in KOTStatus.values) {
      ref.invalidate(kotTicketsProvider(status));
    }
    // --- END FIX ---

    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Synced ${ops.length} op(s) ✅')));
    }
  } catch (e) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    }
  }
}

/// ---- Filters ----
/// null = show all
final orderStatusFilterProvider = StateProvider<OrderStatus?>((_) => null);

/// ---- Orders list (one page for now) ----
final ordersFutureProvider =
FutureProvider.autoDispose<List<Order>>((ref) async {
  final client   = ref.watch(apiClientProvider);
  final status   = ref.watch(orderStatusFilterProvider);
  final tenantId = ref.watch(activeTenantIdProvider);
  final branchId = ref.watch(activeBranchIdProvider);

  final page = await client.fetchOrders(
    status: status,
    tenantId: tenantId.isEmpty ? null : tenantId,
    branchId: branchId.isEmpty ? null : branchId,
    size: 100,
  );
  return page.items;
});

/// ---- Single order detail (with totals) ----
/// We'll fetch this when user taps an order row.
final orderDetailFutureProvider = FutureProvider.autoDispose
    .family<OrderDetail, String>((ref, orderId) async {
  final client = ref.watch(apiClientProvider);
  return client.getOrderDetail(orderId);
});

final _ordersAutoRefreshProvider = Provider<void>((ref) {
  final timer = Timer.periodic(const Duration(seconds: 20), (_) {
    ref.invalidate(ordersFutureProvider);
  });
  ref.onDispose(timer.cancel);
});

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_ordersAutoRefreshProvider); // optional ticker

    final ordersAsync = ref.watch(ordersFutureProvider);
    final status      = ref.watch(orderStatusFilterProvider);
    final pending     = ref.watch(pendingOrdersProvider);

    List<PendingOrder> filterPending(List<PendingOrder> src) {
      if (status == null) return src;
      return src.where((p) => p.status == status).toList();
    }
    List<Order> filterLive(List<Order> src) {
      if (status == null) return src;
      return src.where((o) => o.status == status).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            tooltip: 'Sync Online',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              // --- PASS 'ref' (not 'ref.read') ---
              await _pushQueueFromOrders(context, ref);
              // after pushing local ops, fetch fresh from server to reconcile
              ref.invalidate(ordersFutureProvider);
            },
          ),
          IconButton(
            tooltip: 'Refresh list',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(ordersFutureProvider),
          ),
          IconButton(
            tooltip: 'Open Drawer',
            icon: const Icon(Icons.point_of_sale),
            onPressed: () async {
              final client = ref.read(apiClientProvider);
              try {
                final tenantId = ref.read(activeTenantIdProvider);
                final branchId = ref.read(activeBranchIdProvider);
                await client.openDrawer(tenantId: tenantId, branchId: branchId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Drawer opened 💸')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Drawer failed: $e')),
                  );
                }
              }
            },
          ),
          IconButton(
            tooltip: 'Diagnostics',
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const QueueDiagnosticsSheet(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            status: status,
            onChanged: (s) => ref.read(orderStatusFilterProvider.notifier).state = s,
          ),
          const Divider(height: 0),
          Expanded(
            child: ordersAsync.when(
              data: (live) {
                // Reconcile: drop pendings that now exist on server (same order_no)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(pendingOrdersProvider.notifier).reconcileWithServer(live);
                  ref.read(pendingOrdersProvider.notifier).reconcileLooseWithServer(live);
                });

                final pendings = filterPending(pending);
                final orders   = filterLive(live);

                if (pendings.isEmpty && orders.isEmpty) {
                  return const _Empty();
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(ordersFutureProvider),
                  child: ListView.separated(
                    itemCount: pendings.length + orders.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, i) {
                      if (i < pendings.length) {
                        final p = pendings[i];
                        return _QueuedOrderTile(p: p);
                      }
                      final o = orders[i - pendings.length];
                      return _OrderTile(
                        order: o,
                        onTap: () {
                          // only open detail if server-side order id exists
                          if (o.id == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('This order is still syncing…')),
                            );
                            return;
                          }
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (ctx) => OrderDetailSheet(orderId: o.id!),
                          );
                        },
                      );
                    },
                  ),
                );
              },
              loading: () {
                // Show whatever pending we have while loading
                if (pending.isNotEmpty) {
                  final pendings = filterPending(pending);
                  return ListView.separated(
                    itemCount: pendings.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (_, i) => _QueuedOrderTile(p: pendings[i]),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
              error: (e, st) {
                // Offline? Still show pending orders instead of an error blank
                if (pending.isNotEmpty) {
                  final pendings = filterPending(pending);
                  return ListView.separated(
                    itemCount: pendings.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (_, i) => _QueuedOrderTile(p: pendings[i]),
                  );
                }
                return _Error(e: e, onRetry: () => ref.invalidate(ordersFutureProvider));
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Top bar with status dropdown etc.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.status,
    required this.onChanged,
  });

  final OrderStatus? status;
  final void Function(OrderStatus?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          const Text(
            'Status:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          DropdownButton<OrderStatus?>(
            value: status,
            onChanged: onChanged,
            items: [
              const DropdownMenuItem<OrderStatus?>(
                value: null,
                child: Text('All'),
              ),
              ...OrderStatus.values.map(
                    (s) => DropdownMenuItem<OrderStatus?>(
                  value: s,
                  child: Text(s.name),
                ),
              ),
            ],
          ),
          const Spacer(),
          // room for future: search/date filters
        ],
      ),
    );
  }
}

/// One row in the list
class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.onTap,
  });

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final opened = order.openedAt?.toLocal();
    final openedStr = opened == null
        ? '—'
        : '${opened.year}-${_two(opened.month)}-${_two(opened.day)} '
        '${_two(opened.hour)}:${_two(opened.minute)}';

    return ListTile(
      title: Text(
        '#${order.orderNo} • ${order.channel.name}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Opened: $openedStr'
            '${order.tableId != null ? '  |  Table: ${order.tableId}' : ''}',
      ),
      trailing: _StatusChip(status: order.status),
      onTap: onTap,
    );
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}

class _QueuedOrderTile extends ConsumerWidget {
  const _QueuedOrderTile({required this.p});
  final PendingOrder p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opened = p.openedAt.toLocal();
    final openedStr =
        '${opened.year}-${opened.month.toString().padLeft(2,'0')}-${opened.day.toString().padLeft(2,'0')} '
        '${opened.hour.toString().padLeft(2,'0')}:${opened.minute.toString().padLeft(2,'0')}';

    return ListTile(
      title: Text(
        '#${p.orderNo} • ${p.channel.name}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Opened: $openedStr'
            '${p.tableId != null ? '  |  Table: ${p.tableId}' : ''}',
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'QUEUED',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      onTap: () async {
        await _pushQueueFromOrders(context, ref);
        ref.invalidate(ordersFutureProvider);
      },
    );
  }
}

/// Colored chip for status
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    switch (status) {
      case OrderStatus.OPEN:
        bg = Colors.orange.shade100;
        break;
      case OrderStatus.KITCHEN:
        bg = Colors.amber.shade100;
        break;
      case OrderStatus.READY:
        bg = Colors.lightGreen.shade100;
        break;
      case OrderStatus.SERVED:
        bg = Colors.green.shade100;
        break;
      case OrderStatus.CLOSED:
        bg = Colors.blueGrey.shade100;
        break;
      case OrderStatus.VOID:
        bg = Colors.red.shade100;
        break;
    }

    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.name,
        style:
        const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Bottom sheet with order totals
class OrderDetailSheet extends ConsumerWidget {
  const OrderDetailSheet({super.key, required this.orderId});
  final String orderId;
  String? _extractInvoiceId(Map<String, dynamic> m) {
    final direct = m['invoice_id'] ?? m['id'] ?? m['invoiceId'];
    if (direct is String && direct.isNotEmpty) return direct;
    if (direct is int) return direct.toString();

    final inv = m['invoice'];
    if (inv is Map) {
      final id = inv['invoice_id'] ?? inv['id'] ?? inv['invoiceId'];
      if (id is String && id.isNotEmpty) return id;
      if (id is int) return id.toString();
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync =
    ref.watch(orderDetailFutureProvider(orderId));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            16, 16, 16, 24),
        child: detailAsync.when(
          data: (detail) {
            final o = detail.order;
            final t = detail.totals;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Order #${o.orderNo}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(status: o.status),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Channel: ${o.channel.name}'
                        '${o.tableId != null ? ' | Table: ${o.tableId}' : ''}',
                  ),
                  if (o.pax != null)
                    Text('PAX: ${o.pax}'),
                  if (o.note != null &&
                      o.note!.trim().isNotEmpty)
                    Text(
                      'Note: ${o.note}',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _TotalRow(
                      label: 'Subtotal',
                      value: t.subtotal),
                  _TotalRow(
                      label: 'Tax',
                      value: t.tax),
                  const Divider(),
                  _TotalRow(
                    label: 'Total',
                    value: t.total,
                    isBold: true,
                  ),
                  const SizedBox(height: 8),
                  _TotalRow(
                    label: 'Paid',
                    value: t.paid,
                  ),
                  _TotalRow(
                    label: 'Due',
                    value: t.due,
                    isBold: true,
                    highlight: t.due > 0.01,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Invoice'),
                            onPressed: () async {
                              final api      = ref.read(apiClientProvider);
                              final tenantId = ref.read(activeTenantIdProvider);
                              final branchId = ref.read(activeBranchIdProvider);

                              try {
                                // Idempotent on most backends: returns existing or creates a new invoice
                                final resp = await api.createInvoice(orderId);
                                final invoiceId = _extractInvoiceId(Map<String, dynamic>.from(resp));

                                if (invoiceId == null) {
                                  throw Exception('Could not determine invoice id from server response.');
                                }

                                await api.printInvoiceSmart(
                                  tenantId: tenantId,
                                  branchId: branchId,
                                  invoiceId: invoiceId,
                                );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invoice printed ✅')),
                                  );
                                }

                                // Optional: refresh orders to reflect state changes
                                ref.invalidate(ordersFutureProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Invoice print failed: $e')),
                                  );
                                }
                              }
                            },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('Print Bill'),
                            onPressed: () async {
                              final api      = ref.read(apiClientProvider);
                              final tenantId = ref.read(activeTenantIdProvider);
                              final branchId = ref.read(activeBranchIdProvider);

                              try {
                                await api.printBillSmart(
                                  tenantId: tenantId,
                                  branchId: branchId,
                                  orderId: orderId,
                                );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Bill sent to printer 🧾')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Bill print failed: $e')),
                                  );
                                }
                              }
                            },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, st) => SizedBox(
            height: 200,
            child: Center(
              child: Padding(
                padding:
                const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    Text(
                      'Failed to load order:\n$e',
                      textAlign:
                      TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref
                          .invalidate(
                          orderDetailFutureProvider(
                              orderId)),
                      child: const Text(
                          'Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// row like  "Subtotal .... 123.45"
class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.highlight = false,
  });

  final String label;
  final double value;
  final bool isBold;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final txtStyle = TextStyle(
      fontWeight: isBold ? FontWeight.w600 : null,
      color: highlight ? Colors.red.shade700 : null,
    );

    return Padding(
      padding:
      const EdgeInsets.symmetric(
          vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: txtStyle,
            ),
          ),
          Text(
            _money(value),
            style: txtStyle,
          ),
        ],
      ),
    );
  }

  String _money(double v) =>
      v.toStringAsFixed(2);
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No orders yet.'),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({
    required this.e,
    required this.onRetry,
  });

  final Object e;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Text(
              'Failed to load orders:\n$e',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
