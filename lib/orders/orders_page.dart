import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';

/// Which status tab we're looking at.
final _orderStatusFilterProvider =
StateProvider<OrderStatus?>((ref) => OrderStatus.OPEN);

/// async list of orders for the current filter
final _ordersFutureProvider =
FutureProvider.autoDispose<List<Order>>((ref) async {
  final client = ref.read(apiClientProvider);
  final status = ref.watch(_orderStatusFilterProvider);
  // server paging exists but for now just get page 1 size 50
  final page = await client.fetchOrders(
    status: status,
    page: 1,
    size: 50,
  );
  return page.items;
});

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(_ordersFutureProvider);
    final statusFilter = ref.watch(_orderStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          // Manual sync button
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              ref.invalidate(_ordersFutureProvider);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // status dropdown row
            Row(
              children: [
                const Text(
                  'Status:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                DropdownButton<OrderStatus?>(
                  value: statusFilter,
                  onChanged: (val) {
                    ref.read(_orderStatusFilterProvider.notifier).state = val;
                    // refetch
                    ref.invalidate(_ordersFutureProvider);
                  },
                  items: [
                    const DropdownMenuItem<OrderStatus?>(
                      value: null,
                      child: Text('ALL'),
                    ),
                    ...OrderStatus.values.map(
                          (s) => DropdownMenuItem<OrderStatus?>(
                        value: s,
                        child: Text(s.name),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ordersAsync.when(
                data: (orders) {
                  if (orders.isEmpty) {
                    return const Center(
                      child: Text('No orders found.'),
                    );
                  }
                  return ListView.separated(
                    itemBuilder: (context, index) {
                      final o = orders[index];

                      // We'll display a compact card
                      return _OrderTile(order: o);
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: orders.length,
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (err, st) => SingleChildScrollView(
                  child: Text(
                    'Failed to load orders:\n$err',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderTile extends ConsumerWidget {
  const _OrderTile({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(apiClientProvider);

    // next status flow (simple heuristic)
    final nextStatus = _calcNextStatus(order.status);

    return Card(
      child: ListTile(
        title: Text(
          'Order #${order.orderNo} (${order.channel.name})',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${order.status.name}'),
            if (order.tableId != null && order.tableId!.isNotEmpty)
              Text('Table: ${order.tableId}'),
            if (order.pax != null) Text('Pax: ${order.pax}'),
            if (order.note != null && order.note!.isNotEmpty)
              Text('Note: ${order.note}'),
            if (order.openedAt != null)
              Text('Opened: ${order.openedAt}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (nextStatus != null)
              ElevatedButton(
                onPressed: () async {
                  try {
                    await client.patchOrderStatus(order.id!, nextStatus);
                    // refetch list after update
                    ref.invalidate(_ordersFutureProvider);
                  } catch (e) {
                    _showSnack(context, 'Failed to update: $e');
                  }
                },
                child: Text(nextStatus.name),
              ),
            const SizedBox(height: 4),
            IconButton(
              tooltip: 'Invoice & close',
              icon: const Icon(Icons.receipt_long),
              onPressed: () async {
                try {
                  // 1. generate invoice
                  final inv = await client.createInvoice(order.id!);

                  // 2. try print (may be optional in backend)
                  final invoiceId = inv['invoice_id']?.toString() ??
                      inv['id']?.toString();
                  if (invoiceId != null) {
                    await client.printInvoice(
                      invoiceId,
                      reason: 'Customer request',
                    );
                  }

                  // 3. after invoice, set CLOSED
                  await client.patchOrderStatus(
                      order.id!, OrderStatus.CLOSED);

                  ref.invalidate(_ordersFutureProvider);
                  _showSnack(context, 'Invoiced & closed');
                } catch (e) {
                  _showSnack(context, 'Invoice failed: $e');
                }
              },
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          _showOrderDetailsSheet(context, order, client);
        },
      ),
    );
  }
}

OrderStatus? _calcNextStatus(OrderStatus current) {
  switch (current) {
    case OrderStatus.OPEN:
      return OrderStatus.KITCHEN;
    case OrderStatus.KITCHEN:
      return OrderStatus.READY;
    case OrderStatus.READY:
      return OrderStatus.SERVED;
    case OrderStatus.SERVED:
      return OrderStatus.CLOSED;
    case OrderStatus.CLOSED:
    case OrderStatus.VOID:
      return null;
  }
}

void _showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg)),
  );
}

void _showOrderDetailsSheet(
    BuildContext context, Order order, ApiClient client) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: DefaultTextStyle(
            style: Theme.of(ctx).textTheme.bodyMedium!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.orderNo}',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Status: ${order.status.name}'),
                Text('Channel: ${order.channel.name}'),
                if (order.tableId != null && order.tableId!.isNotEmpty)
                  Text('Table: ${order.tableId}'),
                if (order.customerId != null &&
                    order.customerId!.isNotEmpty)
                  Text('Customer: ${order.customerId}'),
                if (order.note != null && order.note!.isNotEmpty)
                  Text('Note: ${order.note}'),
                if (order.openedAt != null)
                  Text('Opened: ${order.openedAt}'),
                if (order.closedAt != null)
                  Text('Closed: ${order.closedAt}'),
                const SizedBox(height: 16),
                // Future: show line items, totals, payments, etc.
                const Text(
                  'Line items / payments preview TODO',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
