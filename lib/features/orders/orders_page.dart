import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';

/// ---- Filters ----
final orderStatusFilterProvider = StateProvider<OrderStatus?>((_) => null);

/// ---- Data (loads a single page for now) ----
final ordersFutureProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final status = ref.watch(orderStatusFilterProvider);
  final page = await client.fetchOrders(status: status); // returns PageResult<Order>
  return page.items;
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
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(ordersFutureProvider),
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
              data: (orders) {
                if (orders.isEmpty) {
                  return const _Empty();
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(ordersFutureProvider),
                  child: ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, i) => _OrderTile(order: orders[i]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => _Error(e: e, onRetry: () => ref.invalidate(ordersFutureProvider)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.status, required this.onChanged});
  final OrderStatus? status;
  final void Function(OrderStatus?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          const Text('Status:', style: TextStyle(fontWeight: FontWeight.w500)),
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
          // Room for future: search box, date filter, etc.
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final opened = order.openedAt?.toLocal();
    final openedStr = opened == null
        ? '—'
        : '${opened.year}-${_2(opened.month)}-${_2(opened.day)} '
        '${_2(opened.hour)}:${_2(opened.minute)}';

    return ListTile(
      title: Text('#${order.orderNo} • ${order.channel.name}'),
      subtitle: Text('Opened: $openedStr'
          '${order.tableId != null ? '  |  Table: ${order.tableId}' : ''}'),
      trailing: _StatusChip(status: order.status),
      onTap: () {
        // TODO: push to order details when we add that page
        // context.push('/orders/${order.id}');
      },
    );
  }

  String _2(int v) => v.toString().padLeft(2, '0');
}

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
        child: Text('No orders yet.'),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.e, required this.onRetry});
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
            Text('Failed to load orders:\n$e', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
