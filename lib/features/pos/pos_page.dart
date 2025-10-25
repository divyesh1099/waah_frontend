// lib/features/pos/pos_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/models.dart';

/// ------------------------------------------------------------
/// CATEGORY + ITEM DATA
/// ------------------------------------------------------------

/// Which category is currently selected in POS? null means "All".
final selectedCategoryIdProvider = StateProvider<String?>((ref) => null);

/// Load menu categories (tenant/branch aware soon; for now we send "").
final posCategoriesProvider =
FutureProvider.autoDispose<List<MenuCategory>>((ref) async {
  final client = ref.watch(apiClientProvider);
  // backend wants tenant_id & branch_id, but we've been passing "" for now
  final cats = await client.fetchCategories(
    tenantId: "",
    branchId: "",
  );
  // sort nicely by position
  cats.sort((a, b) => a.position.compareTo(b.position));
  return cats;
});

/// Load menu items for currently selected category.
final posItemsProvider =
FutureProvider.autoDispose<List<MenuItem>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final catId = ref.watch(selectedCategoryIdProvider);

  final items = await client.fetchItems(
    categoryId: catId,
    tenantId: "", // consistent with backend test script
  );

  // Only active / not stock_out, just to keep POS clean.
  final filtered = items.where((i) => i.isActive && !i.stockOut).toList();

  // sort by name for predictable grid
  filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return filtered;
});

/// ------------------------------------------------------------
/// CART STATE
/// ------------------------------------------------------------

/// One line in the cart
class CartLine {
  final MenuItem item;
  final ItemVariant? variant;
  final double unitPrice;
  final double qty;

  CartLine({
    required this.item,
    required this.variant,
    required this.unitPrice,
    required this.qty,
  });

  CartLine copyWith({
    MenuItem? item,
    ItemVariant? variant,
    double? unitPrice,
    double? qty,
  }) {
    return CartLine(
      item: item ?? this.item,
      variant: variant ?? this.variant,
      unitPrice: unitPrice ?? this.unitPrice,
      qty: qty ?? this.qty,
    );
  }

  String get displayName {
    if (variant != null && variant!.label.isNotEmpty) {
      return '${item.name} (${variant!.label})';
    }
    return item.name;
  }

  double get lineTotal => unitPrice * qty;
}

/// Entire cart snapshot
class PosCartState {
  final List<CartLine> lines;
  const PosCartState({this.lines = const []});

  double get subTotal {
    return lines.fold(
      0.0,
          (sum, l) => sum + (l.unitPrice * l.qty),
    );
  }

  bool get isEmpty => lines.isEmpty;
}

/// Notifier for cart
class PosCartNotifier extends Notifier<PosCartState> {
  @override
  PosCartState build() => const PosCartState();

  /// Internal helper: find matching line (item+variant).
  int _findLineIndex(MenuItem item, ItemVariant? variant) {
    for (var i = 0; i < state.lines.length; i++) {
      final ln = state.lines[i];
      if (ln.item.id == item.id &&
          (ln.variant?.id ?? '') == (variant?.id ?? '')) {
        return i;
      }
    }
    return -1;
  }

  /// Add 1 qty of this item.
  /// We fetch variants to get price.
  Future<void> addItem(MenuItem item) async {
    final client = ref.read(apiClientProvider);

    // Fetch variants so we can figure out which variant/price to add.
    // We'll pick default=true first, else first, else price=0.
    final variants = await client.fetchVariants(item.id!);
    ItemVariant? chosen;
    double price = 0;

    if (variants.isNotEmpty) {
      // prefer the variant marked isDefault
      chosen = variants.firstWhere(
            (v) => v.isDefault,
        orElse: () => variants.first,
      );
      price = chosen.basePrice;
    }

    // See if this (item+that variant) is already in cart
    final idx = _findLineIndex(item, chosen);
    if (idx >= 0) {
      final old = state.lines[idx];
      final updated = old.copyWith(qty: old.qty + 1);
      final newLines = [...state.lines];
      newLines[idx] = updated;
      state = PosCartState(lines: newLines);
    } else {
      final newLine = CartLine(
        item: item,
        variant: chosen,
        unitPrice: price,
        qty: 1,
      );
      state = PosCartState(lines: [...state.lines, newLine]);
    }
  }

  void incQty(int index) {
    if (index < 0 || index >= state.lines.length) return;
    final old = state.lines[index];
    final updated = old.copyWith(qty: old.qty + 1);
    final newLines = [...state.lines];
    newLines[index] = updated;
    state = PosCartState(lines: newLines);
  }

  void decQty(int index) {
    if (index < 0 || index >= state.lines.length) return;
    final old = state.lines[index];
    final newQty = old.qty - 1;
    if (newQty <= 0) {
      removeLine(index);
    } else {
      final updated = old.copyWith(qty: newQty);
      final newLines = [...state.lines];
      newLines[index] = updated;
      state = PosCartState(lines: newLines);
    }
  }

  void removeLine(int index) {
    if (index < 0 || index >= state.lines.length) return;
    final newLines = [...state.lines]..removeAt(index);
    state = PosCartState(lines: newLines);
  }

  void clear() {
    state = const PosCartState(lines: []);
  }
}

final posCartProvider =
NotifierProvider<PosCartNotifier, PosCartState>(PosCartNotifier.new);

/// ------------------------------------------------------------
/// CHECKOUT FLOW
/// ------------------------------------------------------------
/// This does:
/// 1. POST /orders/           -> create order
/// 2. POST /orders/{id}/items -> each cart line
/// 3. GET  /orders/{id}       -> totals
/// 4. POST /orders/{id}/pay   -> pay full due (CASH)
/// 5. POST /orders/{id}/invoice -> generate invoice
/// 6. Clear cart + snackbar
Future<void> performCheckout(BuildContext context, WidgetRef ref) async {
  final cartState = ref.read(posCartProvider);
  final lines = cartState.lines;

  if (lines.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cart is empty')),
    );
    return;
  }

  // show a spinner dialog so cashier doesn't spam
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final client = ref.read(apiClientProvider);

    // TODO: eventually pull real tenant/branch from auth/session
    const tenantId = '';
    const branchId = '';

    // Generate an order number; timestamp is okay for now
    final orderNo = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 1. Create order (status will default OPEN in backend)
    final newOrder = Order(
      id: null,
      tenantId: tenantId,
      branchId: branchId,
      orderNo: orderNo,
      channel: OrderChannel.TAKEAWAY, // using TAKEAWAY by default
      provider: null,
      status: OrderStatus.OPEN,
      tableId: null,
      customerId: null,
      openedByUserId: null,
      closedByUserId: null,
      pax: 1,
      sourceDeviceId: null,
      note: null,
      openedAt: DateTime.now(),
      closedAt: null,
    );

    Order created;
    try {
      created = await client.createOrder(newOrder);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create order: $e')),
      );
      return;
    }

    final orderId = created.id;
    if (orderId == null || orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No order ID from backend')),
      );
      return;
    }

    // 2. Add each cart line to the order
    for (final line in lines) {
      final itemId = line.item.id;
      final variantId = line.variant?.id;
      if (itemId == null) continue;

      final orderItem = OrderItem(
        id: null,
        orderId: orderId,
        itemId: itemId,
        variantId: variantId,
        parentLineId: null,
        qty: line.qty,
        unitPrice: line.unitPrice,
        lineDiscount: 0,
        gstRate: line.item.gstRate,
        cgst: 0,
        sgst: 0,
        igst: 0,
        taxableValue: 0,
      );

      try {
        await client.addOrderItem(orderId, orderItem);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add line item: $e')),
        );
        return;
      }
    }

    // 3. Fetch totals so we know how much is due
    OrderDetail detail;
    try {
      detail = await client.getOrderDetail(orderId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load totals: $e')),
      );
      return;
    }

    final amountDue = detail.totals.due;

    // 4. Pay full due in CASH
    try {
      await client.pay(orderId, PayMode.CASH, amountDue);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
      return;
    }

    // 5. Generate invoice
    try {
      await client.createInvoice(orderId);
    } catch (e) {
      // non-blocking: cashier can still hand over bill
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice issue: $e')),
      );
    }

    // 6. Clear cart
    ref.read(posCartProvider.notifier).clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Order #$orderNo complete (₹${amountDue.toStringAsFixed(2)})',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  } finally {
    // hide spinner
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

/// ------------------------------------------------------------
/// POS PAGE
/// ------------------------------------------------------------

class PosPage extends ConsumerWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(posCategoriesProvider);
    final itemsAsync = ref.watch(posItemsProvider);
    final cart = ref.watch(posCartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS'),
        actions: [
          IconButton(
            tooltip: 'Sync Online',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              final client = ref.read(apiClientProvider);
              try {
                await client.syncPush(
                  deviceId: 'flutter-pos',
                  ops: const [
                    {
                      'entity': 'ping',
                      'entity_id': 'flutter-pos',
                      'op': 'UPSERT',
                      'payload': {'hello': 'pos'}
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
            tooltip: 'Refresh menu',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(posCategoriesProvider);
              ref.invalidate(posItemsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // CATEGORIES BAR
          catsAsync.when(
            data: (cats) => _CategoryBar(categories: cats),
            loading: () => const SizedBox(
              height: 56,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => SizedBox(
              height: 56,
              child: Center(
                child: Text(
                  'Categories error: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),

          const Divider(height: 0),

          // MENU GRID
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No items in this category'),
                  );
                }
                // Grid of tappable menu items
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 4 / 3,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final it = items[i];
                    return _ItemCard(
                      item: it,
                      onTap: () async {
                        // Add to cart (async will also fetch variants/price)
                        await ref.read(posCartProvider.notifier).addItem(it);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${it.name} added to cart'),
                              duration: const Duration(milliseconds: 800),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
              loading: () =>
              const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Failed to load items:\n$e',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          ref.invalidate(posItemsProvider);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // CART SUMMARY
          _CartSummary(cart: cart),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------
/// WIDGETS
/// ------------------------------------------------------------

/// Horizontal scroll of category chips
class _CategoryBar extends ConsumerWidget {
  const _CategoryBar({required this.categories});
  final List<MenuCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(selectedCategoryIdProvider);

    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1, // + All chip
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            final bool active = (sel == null);
            return ChoiceChip(
              label: const Text('All'),
              selected: active,
              onSelected: (_) {
                ref.read(selectedCategoryIdProvider.notifier).state = null;
                ref.invalidate(posItemsProvider);
              },
            );
          }

          final c = categories[i - 1];
          final bool active = (sel == c.id);
          return ChoiceChip(
            label: Text(c.name),
            selected: active,
            onSelected: (_) {
              ref.read(selectedCategoryIdProvider.notifier).state = c.id;
              ref.invalidate(posItemsProvider);
            },
          );
        },
      ),
    );
  }
}

/// One menu item card in the grid
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});
  final MenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.brown.shade50,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.description != null &&
                  item.description!.trim().isNotEmpty)
                Text(
                  item.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.brown.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Add +',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom cart: shows lines, lets you +/-, shows total, and checkout
class _CartSummary extends ConsumerWidget {
  const _CartSummary({required this.cart});
  final PosCartState cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = cart.lines;
    final total = cart.subTotal;
    final isDisabled = lines.isEmpty;

    return Material(
      elevation: 8,
      color: Colors.brown.shade50,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          12,
          12,
          12,
          12 + 8,
        ), // a little extra bottom padding
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Line items (scroll if long)
            if (lines.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 200,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: lines.length,
                  separatorBuilder: (_, __) => const Divider(height: 8),
                  itemBuilder: (context, i) {
                    final ln = lines[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ln.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '₹ ${ln.unitPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                ref
                                    .read(posCartProvider.notifier)
                                    .decQty(i);
                              },
                            ),
                            Text(
                              ln.qty.toStringAsFixed(0),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                ref
                                    .read(posCartProvider.notifier)
                                    .incQty(i);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹ ${ln.lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            if (lines.isEmpty)
              const Text(
                'Cart is empty',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                ),
              ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // total row
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Subtotal',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '₹ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text(
                      'Clear',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.brown.shade200,
                    ),
                    onPressed: isDisabled
                        ? null
                        : () {
                      ref
                          .read(posCartProvider.notifier)
                          .clear();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.point_of_sale),
                    label: Text(
                      'Checkout ₹ ${total.toStringAsFixed(2)}',
                    ),
                    onPressed: isDisabled
                        ? null
                        : () async {
                      await performCheckout(context, ref);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
