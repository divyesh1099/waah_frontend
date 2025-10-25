import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// ---- Filters ----
/// null = show all
final orderStatusFilterProvider = StateProvider<OrderStatus?>((_) => null);

/// ---- Orders list (one page for now) ----
final ordersFutureProvider =
FutureProvider.autoDispose<List<Order>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final status = ref.watch(orderStatusFilterProvider);
  final page = await client.fetchOrders(status: status);
  return page.items;
});

/// ---- Single order detail (with totals) ----
/// We'll fetch this when user taps an order row.
final orderDetailFutureProvider =
FutureProvider.autoDispose.family<OrderDetail, String>((ref, orderId) async {
  final client = ref.watch(apiClientProvider);
  return client.getOrderDetail(orderId);
});

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersFutureProvider);
    final status = ref.watch(orderStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          // (3) Cash drawer button
          IconButton(
            tooltip: 'Open Drawer',
            icon: const Icon(Icons.point_of_sale),
            onPressed: () async {
              final client = ref.read(apiClientProvider);
              try {
                await client.openDrawer();
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
            tooltip: 'Sync Online',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              // super barebones sync tap:
              final client = ref.read(apiClientProvider);
              try {
                // push a dummy sync event like our test script does
                await client.syncPush(
                  deviceId: 'flutter-demo',
                  ops: const [
                    {
                      'entity': 'ping',
                      'entity_id': 'flutter-demo',
                      'op': 'UPSERT',
                      'payload': {'hello': 'world'}
                    }
                  ],
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sync pushed ✅')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sync failed: $e')),
                  );
                }
              }
            },
          ),
          IconButton(
            tooltip: 'Refresh list',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(ordersFutureProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            status: status,
            onChanged: (s) =>
            ref.read(orderStatusFilterProvider.notifier).state = s,
          ),
          const Divider(height: 0),
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return const _Empty();
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(ordersFutureProvider),
                  child: ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, i) => _OrderTile(
                      order: orders[i],
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (ctx) => OrderDetailSheet(
                            orderId: orders[i].id!,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              loading: () =>
              const Center(child: CircularProgressIndicator()),
              error: (e, st) => _Error(
                e: e,
                onRetry: () => ref.invalidate(ordersFutureProvider),
              ),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Bottom sheet with order totals
class OrderDetailSheet extends ConsumerWidget {
  const OrderDetailSheet({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(orderDetailFutureProvider(orderId));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: detailAsync.when(
          data: (detail) {
            final o = detail.order;
            final t = detail.totals;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Channel: ${o.channel.name}'
                        '${o.tableId != null ? ' | Table: ${o.tableId}' : ''}',
                  ),
                  if (o.pax != null) Text('PAX: ${o.pax}'),
                  if (o.note != null && o.note!.trim().isNotEmpty)
                    Text(
                      'Note: ${o.note}',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _TotalRow(label: 'Subtotal', value: t.subtotal),
                  _TotalRow(label: 'Tax', value: t.tax),
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
                      // (1) Invoice button: create invoice -> print invoice
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Invoice'),
                          onPressed: () async {
                            final client = ref.read(apiClientProvider);
                            try {
                              // ask backend to allocate (or return existing) invoice
                              final inv = await client.createInvoice(orderId);
                              final invoiceId = inv['invoice_id'] as String?;

                              // then actually print it if we got an id
                              if (invoiceId != null) {
                                await client.printInvoiceById(invoiceId);
                              }

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invoice printed ✅'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Invoice failed: $e'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),

                      const SizedBox(width: 12),

                      // (1) Print Bill button: /print/bill/{order_id}
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('Print Bill'),
                          onPressed: () async {
                            final client = ref.read(apiClientProvider);
                            try {
                              await client.printBill(orderId);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Bill printed ✅'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                    Text('Bill print failed: $e'),
                                  ),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Failed to load order:\n$e',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(
                        orderDetailFutureProvider(orderId),
                      ),
                      child: const Text('Retry'),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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

  String _money(double v) => v.toStringAsFixed(2);
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
