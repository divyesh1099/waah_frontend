// lib/features/pos/queue_diag.dart
// POS Diagnostics drawer/sheet (with Pending tools + Manual Resolve)
// Drop-in v3.2 (compile-safe)
// - No missing providers
// - No `await` on void-returning notifier method
// - showModalBottomSheet typed as <void>

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';           // activeTenantIdProvider, activeBranchIdProvider
import '../../data/models.dart';             // Order model
import '../orders/pending_orders.dart';      // pendingOrdersProvider, notifier methods
// ordersFutureProvider

// -----------------------------
// Public API
// -----------------------------
Future<void> showQueueDiagnostics(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const Padding(
      padding: EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 16),
      child: QueueDiagnosticsSheet(),
    ),
  );
}

// -----------------------------
// Sheet
// -----------------------------
class QueueDiagnosticsSheet extends ConsumerWidget {
  const QueueDiagnosticsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(activeTenantIdProvider);
    final branchId = ref.watch(activeBranchIdProvider);

    // No queue count provider available -> show 0 (or compute from pending if you prefer).
    final queuedOps = 0;

    // Pending placeholders list
    final pendingList = ref.watch(pendingOrdersProvider); // List<PendingOrder>

    // Server orders page
    final ordersAsync = ref.watch(ordersFutureProvider);  // AsyncValue<List<Order>>

    final color = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.settings, size: 20),
              const SizedBox(width: 8),
              Text('POS Diagnostics', style: textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // IDs
          _MonoLine('Tenant: $tenantId'),
          _MonoLine('Branch: $branchId'),
          const SizedBox(height: 8),

          // Stats
          _StatLine(label: 'Queued ops', value: '$queuedOps'),
          _StatLine(label: 'Pending placeholders', value: '${pendingList.length}'),
          _ServerOrdersPreview(ordersAsync: ordersAsync),

          const SizedBox(height: 8),

          // Pending tools
          _PendingToolsRow(),
          const SizedBox(height: 6),

          // Force reconcile (±3 min)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('Force reconcile (±3 min)'),
              onPressed: () async {
                try {
                  final live = await ref.read(ordersFutureProvider.future);
                  // DON'T await here — your notifier likely returns void.
                  ref
                      .read(pendingOrdersProvider.notifier)
                      .reconcileLooseWithServer(live, skew: const Duration(minutes: 3));
                  _snack(context, 'Reconciled against server (±3m)');
                } catch (e) {
                  _snack(context, 'Reconcile failed: $e');
                }
              },
            ),
          ),

          const SizedBox(height: 8),

          // Manual resolve — appears once server orders load
          ordersAsync.maybeWhen(
            data: (orders) => orders.isEmpty
                ? const SizedBox.shrink()
                : _ManualResolvePicker(orders: orders),
            orElse: () => const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),

          // Push buttons row (stubs until wired)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Push ALL now'),
                  onPressed: () {
                    _snack(context, 'TODO: wire pushAllNow()');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('Push OPEN only'),
                  onPressed: () {
                    _snack(context, 'TODO: wire pushOpenOnly()');
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Copy queue JSON (optional — keep disabled unless you expose a peek)
          Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: 'Copies first pending queue op as JSON to clipboard',
              child: OutlinedButton.icon(
                icon: const Icon(Icons.content_copy),
                label: const Text('Copy queue JSON (first 1)'),
                onPressed: null,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Footer tip
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tip: If OPEN pushes succeed but the full batch fails, your backend may reject later ops '
                  '(e.g., KOT/PRINT needing actor_user_id).',
              style: textTheme.bodySmall?.copyWith(color: color.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------
// Widgets
// -----------------------------
class _MonoLine extends StatelessWidget {
  const _MonoLine(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontFeatures: const [FontFeature.tabularFigures()],
          color: color.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.bodyMedium)),
          Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ServerOrdersPreview extends ConsumerWidget {
  const _ServerOrdersPreview({required this.ordersAsync});
  final AsyncValue<List<Order>> ordersAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;

    return ordersAsync.when(
      loading: () => _StatLine(label: 'Server orders (page)', value: '—'),
      error: (_, __) => _StatLine(label: 'Server orders (page)', value: 'error'),
      data: (orders) {
        final nos = orders.map((o) => o.orderNo ?? '—').where((s) => s.isNotEmpty).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatLine(label: 'Server orders (page)', value: '${orders.length}'),
            if (nos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'order_nos: ${nos.join(', ')}',
                  style: t.bodySmall?.copyWith(fontFamily: 'monospace'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        );
      },
    );
  }
}

// Row with: Inspect pending (first) + Clear stale (≥30m)
class _PendingToolsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingOrdersProvider); // List<PendingOrder>
    final disabled = pending.isEmpty;

    return Row(
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.visibility),
          label: const Text('Inspect pending (first)'),
          onPressed: disabled
              ? null
              : () {
            ref.read(pendingOrdersProvider.notifier).debugLogFirst();
            _snack(context, 'Dumped first pending to console');
          },
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_sweep),
          label: const Text('Clear stale (≥30m)'),
          onPressed: disabled
              ? null
              : () {
            ref.read(pendingOrdersProvider.notifier).clearStale(
              olderThan: const Duration(minutes: 30),
            );
            _snack(context, 'Cleared stale placeholders (≥30m)');
          },
        ),
      ],
    );
  }
}

// Manual resolve: attach nearest pending to selected server order_no
class _ManualResolvePicker extends ConsumerStatefulWidget {
  const _ManualResolvePicker({required this.orders});
  final List<Order> orders;

  @override
  ConsumerState<_ManualResolvePicker> createState() => _MRPState();
}

class _MRPState extends ConsumerState<_ManualResolvePicker> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final items = widget.orders
        .map((o) => DropdownMenuItem<String>(
      value: (o.orderNo ?? '').trim(),
      child: Text(o.orderNo ?? '—'),
    ))
        .toList();

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _selected,
            hint: const Text('Attach pending → order_no'),
            items: items,
            onChanged: (v) => setState(() => _selected = v),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.link),
          label: const Text('Resolve'),
          onPressed: (_selected == null || _selected!.isEmpty)
              ? null
              : () async {
            try {
              final live = await ref.read(ordersFutureProvider.future);
              ref
                  .read(pendingOrdersProvider.notifier)
                  .resolveByServerOrderNo(_selected!, live, skew: const Duration(hours: 1));
              _snack(context, 'Resolved to $_selected');
            } catch (e) {
              _snack(context, 'Resolve failed: $e');
            }
          },
        ),
      ],
    );
  }
}

// -----------------------------
// Helpers
// -----------------------------
void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
