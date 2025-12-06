import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/app/providers.dart' hide ordersFutureProvider;
import 'package:waah_frontend/data/models.dart';


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

    // Helper to manually refresh all data
    Future<void> refresh() async {
      // Invalidate all providers this page depends on
      ref.invalidate(orderDetailFutureProvider(orderId));

      // Also invalidate the providers for the other main pages
      ref.invalidate(ordersFutureProvider);
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

                // Card 2: Items
                _OrderItemsCard(items: detail.items),

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

/// Card to show the list of ordered items
class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.items});
  final List<OrderItem> items;

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
              'Items',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('No items in this order.', style: TextStyle(color: Colors.grey)),
            ...items.map((item) {
              final sub = <String>[];
              if (item.variantLabel != null) sub.add(item.variantLabel!);
              // if (item.modifiers.isNotEmpty) sub.add ... (if we had modifiers logic ready)
              
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item.name ?? 'Unknown Item'),
                subtitle: sub.isNotEmpty ? Text(sub.join(', ')) : null,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: Colors.black87,
                  child: Text(
                    _fmtQty(item.qty), 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
                  ),
                ),
                trailing: Text('₹ ${(item.unitPrice * item.qty).toStringAsFixed(2)}'),
              );
            }),
          ],
        ),
      ),
    );
  }
    
  String _fmtQty(double q) {
      if (q == q.toInt().toDouble()) return q.toInt().toString();
      return q.toString();
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