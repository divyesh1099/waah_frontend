import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:waah_frontend/app/providers.dart' hide ordersFutureProvider;
import 'package:waah_frontend/data/models.dart';
import 'package:waah_frontend/features/kot/kot_page.dart'
    show kotTicketsProvider;

import '../../orders/orders_page.dart'; // For invalidation

class OrderDetailPage extends ConsumerWidget {
  final String orderId;
  final Order? initialOrder;

  const OrderDetailPage({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderDetailAsync = ref.watch(orderDetailFutureProvider(orderId));

    // This provider will fetch ALL KOTs, and we'll filter them below
    final allKotsAsync = ref.watch(filteredKotTicketsProvider);

    // Helper to manually refresh all data
    Future<void> refresh() async {
      // Invalidate all providers this page depends on
      ref.invalidate(orderDetailFutureProvider(orderId));
      ref.invalidate(filteredKotTicketsProvider);

      // Also invalidate the providers for the other main pages
      ref.invalidate(ordersFutureProvider);
      for (final status in KOTStatus.values) {
        ref.invalidate(kotTicketsProvider(status));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order ${orderDetailAsync.value?.order.orderNo ?? initialOrder?.orderNo ?? orderId}',
        ),
      ),
      body: orderDetailAsync.when(
        data: (detail) {
          final order = detail.order;
          final totals = detail.totals;

          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.all(12.0),
              children: [
                // Card 1: Order Status
                _OrderStatusCard(order: order),

                // Card 2: KOT Statuses
                _KotStatusCard(
                  orderId: order.id!,
                  allKotsAsync: allKotsAsync,
                ),

                // Card 3: Order Totals
                _OrderTotalsCard(totals: totals),

                // Card 4: Actions (Print, etc.)
                _OrderActionsCard(order: order),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error loading order:\n$e'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: refresh,
                  child: const Text('Retry'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card to manage the overall Order Status
class _OrderStatusCard extends ConsumerWidget {
  const _OrderStatusCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusChip(status: order.status),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Change'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => _ChangeOrderStatusDialog(order: order),
                    );
                  },
                ),
              ],
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
        reason: 'Updated from Order Detail Page',
      );
      await api.updateOrderStatus(widget.order.id!, update);

      // Invalidate everything to refresh all pages
      ref.invalidate(orderDetailFutureProvider(widget.order.id!));
      ref.invalidate(ordersFutureProvider); // For the main orders list
      for (final status in KOTStatus.values) {
        ref.invalidate(kotTicketsProvider(status)); // For the KOT page
      }

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

/// Card to manage KOT statuses for this order
class _KotStatusCard extends ConsumerWidget {
  const _KotStatusCard({required this.orderId, required this.allKotsAsync});
  final String orderId;
  final AsyncValue<List<KitchenTicket>> allKotsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kitchen Tickets',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            allKotsAsync.when(
              data: (allKots) {
                // Filter KOTs just for this order
                final orderKots =
                allKots.where((kot) => kot.orderId == orderId).toList();

                if (orderKots.isEmpty) {
                  return const ListTile(
                    dense: true,
                    title: Text('No KOTs found for this order.'),
                  );
                }

                return Column(
                  children:
                  orderKots.map((kot) => _KotTile(kot: kot)).toList(),
                );
              },
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (e, st) => ListTile(
                title: const Text('Error loading KOTs'),
                subtitle: Text('$e'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single KOT tile with a status-change button
class _KotTile extends StatelessWidget {
  const _KotTile({required this.kot});
  final KitchenTicket kot;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('KOT #${kot.ticketNo} (${kot.stationName ?? "Main"})'),
      subtitle: Text(kot.lines.map((e) => '${e.qty}x ${e.name}').join(', ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KotStatusChip(status: kot.status),
          const SizedBox(width: 8),
          IconButton.outlined(
            icon: const Icon(Icons.edit, size: 16),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => _ChangeKotStatusDialog(kot: kot),
              );
            },
          )
        ],
      ),
    );
  }
}

/// Dialog to change a single KOT's status
class _ChangeKotStatusDialog extends ConsumerStatefulWidget {
  const _ChangeKotStatusDialog({required this.kot});
  final KitchenTicket kot;

  @override
  ConsumerState<_ChangeKotStatusDialog> createState() =>
      _ChangeKotStatusDialogState();
}

class _ChangeKotStatusDialogState extends ConsumerState<_ChangeKotStatusDialog> {
  bool _isLoading = false;

  // List of statuses a user can manually set
  final _allowedStatuses = [
    KOTStatus.NEW,
    KOTStatus.IN_PROGRESS,
    KOTStatus.READY,
    KOTStatus.DONE,
  ];

  Future<void> _updateStatus(KOTStatus newStatus) async {
    if (widget.kot.id == null) return;
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      await api.patchKitchenTicketStatus(widget.kot.id!, newStatus);

      // Invalidate everything
      ref.invalidate(filteredKotTicketsProvider); // For this page
      for (final status in KOTStatus.values) {
        ref.invalidate(kotTicketsProvider(status)); // For the KOT page
      }
      ref.invalidate(orderDetailFutureProvider(widget.kot.orderId)); // Refresh order

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'KOT #${widget.kot.ticketNo} status updated to ${newStatus.name}')),
        );
        Navigator.pop(context); // Close the dialog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update KOT status: $e')),
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
      title: Text('Set KOT #${widget.kot.ticketNo} Status'),
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
                if (status == widget.kot.status)
                  const Icon(Icons.check, size: 16),
              ],
            ),
          ),
      ],
    );
  }
}

/// Card showing order totals
class _OrderTotalsCard extends StatelessWidget {
  const _OrderTotalsCard({required this.totals});
  final OrderTotals totals;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Totals',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _TotalRow(label: 'Subtotal', value: totals.subtotal),
            _TotalRow(label: 'Tax', value: totals.tax),
            const Divider(),
            _TotalRow(
              label: 'Total',
              value: totals.total,
              isBold: true,
            ),
            const SizedBox(height: 8),
            _TotalRow(
              label: 'Paid',
              value: totals.paid,
            ),
            _TotalRow(
              label: 'Due',
              value: totals.due,
              isBold: true,
              highlight: totals.due > 0.01,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card with print actions
class _OrderActionsCard extends ConsumerWidget {
  const _OrderActionsCard({required this.order});
  final Order order;

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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.receipt_long),
                label: const Text('Invoice'),
                onPressed: () async {
                  final api = ref.read(apiClientProvider);
                  final tenantId = ref.read(activeTenantIdProvider);
                  final branchId = ref.read(activeBranchIdProvider);

                  try {
                    // Idempotent: returns existing or creates a new invoice
                    final resp = await api.createInvoice(order.id!);
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

                    // Refresh order list to show status change
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
                  final api = ref.read(apiClientProvider);
                  final tenantId = ref.read(activeTenantIdProvider);
                  final branchId = ref.read(activeBranchIdProvider);

                  try {
                    await api.printBillSmart(
                      tenantId: tenantId,
                      branchId: branchId,
                      orderId: order.id!,
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
      ),
    );
  }
}

// -----------------
// Helper Widgets
// -----------------

/// Colored chip for Order status
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
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

/// Colored chip for KOT status
class _KotStatusChip extends StatelessWidget {
  const _KotStatusChip({required this.status});
  final KOTStatus status;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    switch (status) {
      case KOTStatus.NEW:
        bg = Colors.orange.shade100;
        break;
      case KOTStatus.IN_PROGRESS:
        bg = Colors.yellow.shade100;
        break;
      case KOTStatus.READY:
        bg = Colors.lightGreen.shade100;
        break;
      case KOTStatus.DONE:
        bg = Colors.green.shade100;
        break;
      case KOTStatus.CANCELLED:
        bg = Colors.red.shade100;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
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
      color: highlight ? Colors.red.shade50 : null,
      fontSize: isBold ? 16 : 14,
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
            '₹ ${_money(value)}',
            style: txtStyle,
          ),
        ],
      ),
    );
  }

  String _money(double v) => v.toStringAsFixed(2);
}