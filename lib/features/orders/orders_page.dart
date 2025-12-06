import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // NEW: For navigation
import 'package:intl/intl.dart'; // NEW: For date formatting

import '../debug/queue_diag.dart';
import '../../app/providers.dart';
import '../orders/pending_orders.dart';
import '../../data/models.dart';
// For invalidating kotTicketsProvider

// Note: All local queue helpers and local providers have been removed,
// as they are now handled by global providers from app/providers.dart

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the new filter-aware provider from app/providers.dart
    final ordersAsync = ref.watch(ordersFutureProvider);
    // Watch the filter state itself to update the UI
    final filter = ref.watch(orderFilterProvider);
    final pending = ref.watch(pendingOrdersProvider);

    List<PendingOrder> filterPending(List<PendingOrder> src) {
      if (filter.status == null) return src;
      return src.where((p) => p.status == filter.status).toList();
    }

    List<Order> filterLive(List<Order> src) {
      if (filter.status == null) return src;
      return src.where((o) => o.status == filter.status).toList();
    }

    // Check if any filters are active
    final bool isFiltered = filter.status != null || filter.startDt != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          // NEW: Filter Button
          IconButton(
            tooltip: 'Filter Orders',
            icon: Icon(isFiltered ? Icons.filter_list : Icons.filter_list_off),
            color: isFiltered ? Theme.of(context).colorScheme.primary : null,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true, // Allows sheet to grow
                builder: (_) => const _OrderFilterSheet(),
              );
            },
          ),
          IconButton(
            tooltip: 'Sync Online',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              // UPDATED: Use the global queuePusherProvider
              try {
                await ref.read(queuePusherProvider).pushAllNow();
                ref.invalidate(ordersFutureProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Sync Complete ✅')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Sync Failed: $e')));
                }
              }
            },
          ),
          IconButton(
            tooltip: 'Refresh list',
            icon: const Icon(Icons.refresh),
            // UPDATED: Invalidate the global provider
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
          // REMOVED: Old _FilterBar
          // NEW: Show active filters
          const _ActiveFilters(),
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
                final orders = filterLive(live);

                if (pendings.isEmpty && orders.isEmpty) {
                  return _Empty(isFiltered: isFiltered);
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
                          // UPDATED: Navigate to the new OrderDetailPage
                          context.go('/order/${o.id}', extra: o);
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

/// NEW: Shows active filters as dismissible chips
class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(orderFilterProvider);
    final notifier = ref.read(orderFilterProvider.notifier);

    final hasStatus = filter.status != null;
    final hasDate = filter.startDt != null;

    if (!hasStatus && !hasDate) {
      return const SizedBox.shrink(); // No filters, show nothing
    }

    String formatDateRange() {
      if (filter.startDt == null || filter.endDt == null) return '';
      final fmt = DateFormat('MMM d');
      // Check for single-day range (e.g., Today, Yesterday)
      if (filter.startDt!.year == filter.endDt!.year &&
          filter.startDt!.month == filter.endDt!.month &&
          filter.startDt!.day == filter.endDt!.day) {
        return fmt.format(filter.startDt!); // e.g., "Nov 8"
      }
      // Multi-day range
      return '${fmt.format(filter.startDt!)} - ${fmt.format(filter.endDt!)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            "Filters:",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (hasStatus)
            Chip(
              label: Text('Status: ${filter.status!.name}'),
              labelStyle: Theme.of(context).textTheme.bodySmall,
              onDeleted: () => notifier.setStatus(null),
            ),
          if (hasDate)
            Chip(
              label: Text('Date: ${formatDateRange()}'),
              labelStyle: Theme.of(context).textTheme.bodySmall,
              onDeleted: () => notifier.setDateRange(null, null),
            ),
        ],
      ),
    );
  }
}

/// NEW: Bottom sheet for setting status and date filters
class _OrderFilterSheet extends ConsumerWidget {
  const _OrderFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(orderFilterProvider);
    final notifier = ref.read(orderFilterProvider.notifier);
    final now = DateTime.now();

    // Helper to get a "clean" date (no time component)
    DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

    void pickRange() async {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2023, 1, 1),
        lastDate: now,
        initialDateRange: filter.startDt != null && filter.endDt != null
            ? DateTimeRange(start: filter.startDt!, end: filter.endDt!)
            : null,
      );
      if (range != null) {
        // Set range from start of first day to end of second day
        notifier.setDateRange(
          dateOnly(range.start),
          dateOnly(range.end).add(const Duration(days: 1, milliseconds: -1)),
        );
      }
    }

    void setToday() {
      final start = dateOnly(now);
      final end = start.add(const Duration(days: 1, milliseconds: -1));
      notifier.setDateRange(start, end);
    }

    void setYesterday() {
      final start = dateOnly(now.subtract(const Duration(days: 1)));
      final end = start.add(const Duration(days: 1, milliseconds: -1));
      notifier.setDateRange(start, end);
    }

    void clearDates() {
      notifier.setDateRange(null, null);
    }

    String formatRange() {
      if (filter.startDt == null || filter.endDt == null) return 'Any Date';
      final fmt = DateFormat('MMM d, yyyy');
      // Check for single-day range
      if (filter.startDt!.year == filter.endDt!.year &&
          filter.startDt!.month == filter.endDt!.month &&
          filter.startDt!.day == filter.endDt!.day) {
        return fmt.format(filter.startDt!);
      }
      return '${fmt.format(filter.startDt!)} - ${fmt.format(filter.endDt!)}';
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter Orders', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),

            // Status Dropdown
            DropdownButtonFormField<OrderStatus?>(
              initialValue: filter.status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Statuses')),
                ...OrderStatus.values.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                ),
              ],
              onChanged: (val) => notifier.setStatus(val),
            ),
            const SizedBox(height: 24),

            // Date Filters
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Date: ${formatRange()}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (filter.startDt != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: clearDates,
                    tooltip: 'Clear Date Filter',
                  )
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: setToday,
                  child: const Text('Today'),
                ),
                FilledButton.tonal(
                  onPressed: setYesterday,
                  child: const Text('Yesterday'),
                ),
                FilledButton(
                  onPressed: pickRange,
                  child: const Text('Custom...'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
            const SizedBox(height: 8),
          ],
        ),
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

    // Build the rich subtitle items
    final details = <Widget>[];

    // 1. Time & Table
    final timeAndTable =
        '$openedStr${order.tableId != null ? ' • Table ${order.tableId}' : ''}';
    details.add(Text(timeAndTable));

    // 2. PAX
    if (order.pax != null) {
      details.add(const SizedBox(height: 4));
      details.add(Row(
        children: [
          const Icon(Icons.people, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text('${order.pax} Guests', style: Theme.of(context).textTheme.bodySmall),
        ],
      ));
    }

    // 3. Note
    if (order.note != null && order.note!.isNotEmpty) {
      details.add(const SizedBox(height: 4));
      details.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sticky_note_2, size: 14, color: Colors.amber),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              order.note!,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ));
    }

    // 4. Provider / Customer
    if (order.provider != null || order.customerId != null) {
       final info = [
         if (order.provider != null) order.provider!.name,
         if (order.customerId != null) 'Cust: ${order.customerId}'
       ].join(' • ');
       
       if (info.isNotEmpty) {
         details.add(const SizedBox(height: 4));
         details.add(Row(
          children: [
             const Icon(Icons.info_outline, size: 14, color: Colors.blueGrey),
             const SizedBox(width: 4),
             Text(info, style: Theme.of(context).textTheme.bodySmall),
          ],
         ));
       }
    }

    return ListTile(
      isThreeLine: true, // Allow subtitle to be taller
      title: Text(
        '#${order.orderNo} • ${order.channel.name}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details,
      ),
      trailing: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => _ChangeOrderStatusDialog(order: order),
          );
        },
        child: _StatusChip(status: order.status),
      ),
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
        // UPDATED: Use the global queuePusherProvider
        await ref.read(queuePusherProvider).pushAllNow();
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

// REMOVED: OrderDetailSheet
// This is now replaced by the full-page OrderDetailPage

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
  const _Empty({this.isFiltered = false});
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          isFiltered ? 'No orders match these filters.' : 'No orders yet.',
        ),
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

/// Dialog to change the main Order's status
class _ChangeOrderStatusDialog extends ConsumerStatefulWidget {
  const _ChangeOrderStatusDialog({required this.order});
  final Order order;

  @override
  ConsumerState<_ChangeOrderStatusDialog> createState() =>
      _ChangeOrderStatusDialogState();
}

class _ChangeOrderStatusDialogState
    extends ConsumerState<_ChangeOrderStatusDialog> {
  bool _isLoading = false;

  // List of statuses a user can manually set
  final _allowedStatuses = [
    OrderStatus.OPEN,
    OrderStatus.KITCHEN,
    OrderStatus.READY,
    OrderStatus.SERVED,
    OrderStatus.CLOSED,
    OrderStatus.VOID,
  ];

  Future<void> _updateStatus(OrderStatus newStatus) async {
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      final update = OrderStatusUpdate(
        status: newStatus,
        reason: 'Updated from Orders List Page',
      );
      await api.updateOrderStatus(widget.order.id!, update);

      // Invalidate providers
      ref.invalidate(ordersFutureProvider); 
      // Also invalidate detail if it was open (though we are on list page)
      // ref.invalidate(orderDetailFutureProvider(widget.order.id!)); 
      // we can't easily invalidate specific dynamic provider family members without the id handy everywhere
      // but invalidating ordersFutureProvider is the main thing for this page.

      // If we want to be thorough:
      // for (final status in KOTStatus.values) {
      //   ref.invalidate(kotTicketsProvider(status));
      // }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to ${newStatus.name}')),
        );
        Navigator.pop(context); // Close the dialog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Set Order Status'),
      children: _isLoading
          ? [const Center(child: Padding(
        padding: EdgeInsets.all(24.0),
        child: CircularProgressIndicator(),
      ))]
          : [
        for (final status in _allowedStatuses)
          SimpleDialogOption(
            onPressed: () => _updateStatus(status),
            child: Row(
              children: [
                Expanded(child: Text(status.name)),
                if (status == widget.order.status)
                  const Icon(Icons.check, size: 16),
              ],
            ),
          ),
      ],
    );
  }
}
