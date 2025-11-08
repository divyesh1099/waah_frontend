import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// UPDATED: No longer hiding ordersFutureProvider
import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/models.dart';
import 'package:waah_frontend/widgets/menu_media.dart';
import 'dart:convert' as convert;
import 'dart:math';
import '../debug/queue_diag.dart';
import '../../data/api_client.dart';
// REMOVED: This provider is now in app/providers.dart
// import '../../orders/orders_page.dart';
import '../kot/kot_page.dart'; // Keep this for kotTicketsProvider
import '../orders/pending_orders.dart';

typedef Read = T Function<T>(ProviderListenable<T> provider);

// --- FAST CACHES for variants & modifiers (cleared on app restart) ---
final Map<String, List<ItemVariant>> _variantsCache = {};
final Map<String, List<_ItemModifierGroupData>> _modsCache = {};

// ---------------- SPEED CONFIG ----------------
const bool _kAutoPrintKOT = true;
const bool _kAutoPrintInvoice = true;
const int _kAddItemsParallel = 8; // was 6
// UPDATED: Set back to false to enable offline-first path
const bool _kPreferFastPath = false;

// Cache printer IDs per branch to avoid listPrinters() each time
class _PrinterSnapshot {
  final List<String> kitchenPrinterIds;
  final List<String> billPrinterIds; // invoice / bill printers
  const _PrinterSnapshot({
    required this.kitchenPrinterIds,
    required this.billPrinterIds,
  });
}

// Fetch once per tenant/branch; invalidate when branch changes.
final printerSnapshotProvider = FutureProvider<_PrinterSnapshot>((ref) async {
  final client = ref.watch(apiClientProvider);
  final tenantId = ref.watch(activeTenantIdProvider);
  final branchId = ref.watch(activeBranchIdProvider);
  if (tenantId.isEmpty || branchId.isEmpty) {
    return const _PrinterSnapshot(kitchenPrinterIds: [], billPrinterIds: []);
  }
  final printers = await client.listPrinters(tenantId: tenantId, branchId: branchId);
  final kitchen = <String>[];
  final bill = <String>[];
  for (final p in printers) {
    final type = ((p['type'] as String?) ?? '').toUpperCase();
    final pid = (p['id'] as String?) ?? '';
    if (pid.isEmpty) continue;
    if (type == 'KITCHEN') kitchen.add(pid);
    if (type == 'BILLING' || type == 'RECEIPT' || type == 'FRONT') bill.add(pid);
  }
  return _PrinterSnapshot(kitchenPrinterIds: kitchen, billPrinterIds: bill);
});

Future<List<ItemVariant>> _getVariantsCached(WidgetRef ref, String itemId) async {
  final hit = _variantsCache[itemId];
  if (hit != null) return hit;
  final client = ref.read(apiClientProvider);
  final res = await client.fetchVariants(itemId);
  _variantsCache[itemId] = res;
  return res;
}

Future<List<_ItemModifierGroupData>> _getModsCached(WidgetRef ref, String itemId) async {
  final hit = _modsCache[itemId];
  if (hit != null) return hit;
  final client = ref.read(apiClientProvider);
  final raw = await client.fetchItemModifierGroups(itemId);
  final parsed = raw.map<_ItemModifierGroupData>(
        (g) => _ItemModifierGroupData.fromRaw(Map<String, dynamic>.from(g)),
  ).toList();
  _modsCache[itemId] = parsed;
  return parsed;
}

class _Gate {
  _Gate(this._max);
  final int _max;
  int _in = 0;
  final Queue<Completer<void>> _q = Queue();

  Future<T> withPermit<T>(Future<T> Function() run) async {
    if (_in >= _max) {
      final c = Completer<void>();
      _q.add(c);
      await c.future;
    }
    _in++;
    try { return await run(); }
    finally {
      _in--;
      if (_q.isNotEmpty) _q.removeFirst().complete();
    }
  }
}
final _prefetchGate = _Gate(3); // <=3 concurrent


class _BranchSwitcherAction extends ConsumerWidget {
  const _BranchSwitcherAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches$ = ref.watch(settingsRepoProvider).watchBranches();
    final activeBid = ref.watch(activeBranchIdProvider);
    return StreamBuilder<List<BranchInfo>>(
      stream: branches$,
      initialData: const [],
      builder: (c, s) {
        final branches = s.data ?? const [];
        if (branches.isEmpty) {
          return const SizedBox.shrink();
        }
        final activeName = branches.firstWhere(
              (b) => b.id == activeBid,
          orElse: () => branches.first,
        ).name;
        return PopupMenuButton<String>(
          tooltip: 'Switch Branch',
          icon: const Icon(Icons.store_mall_directory),
          itemBuilder: (_) => [
            for (final b in branches)
              PopupMenuItem<String>(
                value: b.id,
                child: Row(
                  children: [
                    if (b.id == activeBid) const Icon(Icons.check, size: 18),
                    if (b.id == activeBid) const SizedBox(width: 8),
                    Expanded(child: Text(b.name)),
                  ],
                ),
              ),
          ],
          onSelected: (bid) {
            final picked = branches.firstWhere((b) => b.id == bid, orElse: () => branches.first);
            ref.read(activeBranchIdProvider.notifier).state = bid;
            ref.read(selectedCategoryIdProvider.notifier).state = null;
            ref.invalidate(posCategoriesProvider);
            ref.invalidate(posItemsProvider);
            ref.invalidate(diningTablesProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Switched to branch: ${picked.name}')),
            );
          },
        );
      },
    );
  }
}
/// ------------------------------------------------------------
/// PROVIDERS: categories, items, tables, cart
/// ------------------------------------------------------------

/// Which category is currently selected in POS? null means "All".
final selectedCategoryIdProvider = StateProvider<String?>((ref) => null);

/// Load menu categories for the ACTIVE tenant/branch.
final posCategoriesProvider =
FutureProvider<List<MenuCategory>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final tenantId = ref.watch(activeTenantIdProvider);
  final branchId = ref.watch(activeBranchIdProvider);
  if (tenantId.isEmpty || branchId.isEmpty) return <MenuCategory>[];

  final cats = await client.fetchCategories(tenantId: tenantId, branchId: branchId);
  cats.sort((a, b) => (a.position).compareTo(b.position));
  return cats;
});

final posItemsProvider = FutureProvider<List<MenuItem>>((ref) async {
  final client   = ref.watch(apiClientProvider);
  final tenantId = ref.watch(activeTenantIdProvider);
  final branchId = ref.watch(activeBranchIdProvider); // NEW
  final catId    = ref.watch(selectedCategoryIdProvider);

  if (tenantId.isEmpty) return <MenuItem>[];

  final items = await client.fetchItems(
    categoryId: (catId == null || catId.trim().isEmpty) ? null : catId, // FIXED
    tenantId: tenantId,
    branchId: branchId.isEmpty ? null : branchId,                        // NEW
  );

  final filtered = items
      .where((i) => i.isActive && !i.stockOut)
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return filtered;
});

/// Load dining tables for ACTIVE branch.
final diningTablesProvider = StreamProvider<List<DiningTable>>((ref) {
  final repo = ref.watch(settingsRepoProvider);
  final branchId = ref.watch(activeBranchIdProvider);

  if (branchId.isEmpty) {
    // immediately emit empty list if no branch selected
    return Stream<List<DiningTable>>.value(<DiningTable>[]);
  }
  return repo.watchTables(branchId); // <-- same source as Settings page
});

// Top-level silent push that accepts a generic Ref (works with WidgetRef too)
Future<void> _silentPush(Ref ref) async {
  final client = ref.read(apiClientProvider);
  final ops = await _readQueuedOps(ref.read); // This helper still takes ref.read
  if (ops.isEmpty) return;
  final orderNos = _extractOrderNos(ops);
  try {
    await client.syncPush(deviceId: _kDeviceId, ops: ops);
    await _writeQueuedOps(ref.read, []); // This helper still takes ref.read
    ref.read(pendingOrdersProvider.notifier).removeByOrderNos(orderNos);

    // UPDATED: Invalidate providers on successful auto-sync
    ref.invalidate(ordersFutureProvider);
    for (final status in KOTStatus.values) {
      ref.invalidate(kotTicketsProvider(status));
    }

  } catch (_) {
    // ignore; autosync will retry
  }
}

final netBusyProvider = StateProvider<bool>((_) => false);

// Top-level autosync provider
final _queueAutoSyncProvider = Provider<void>((ref) {
  final t = Timer.periodic(const Duration(seconds: 20), (_) {
    if (!ref.read(netBusyProvider)) {
      unawaited(_silentPush(ref));
    }
  });
  ref.onDispose(t.cancel);
});

class _PhaseTimer {
  final _t0 = DateTime.now();
  DateTime _last = DateTime.now();
  void lap(String name) {
    final now = DateTime.now();
    final inc = now.difference(_last).inMilliseconds;
    final total = now.difference(_t0).inMilliseconds;
    dev.log('+$inc ms (total ${total} ms)', name: 'pos.timer.$name');
    _last = now;
  }
}

/// ------------------------------------------------------------
/// CART STATE
/// ------------------------------------------------------------

/// One line in the cart
class CartLine {
  final MenuItem item;
  final ItemVariant? variant;
  final List<Modifier> modifiers;
  final double unitPrice; // includes variant base + modifiers deltas
  final double qty;

  CartLine({
    required this.item,
    required this.variant,
    required this.modifiers,
    required this.unitPrice,
    required this.qty,
  });

  CartLine copyWith({
    MenuItem? item,
    ItemVariant? variant,
    List<Modifier>? modifiers,
    double? unitPrice,
    double? qty,
  }) {
    return CartLine(
      item: item ?? this.item,
      variant: variant ?? this.variant,
      modifiers: modifiers ?? this.modifiers,
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

  /// Human-friendly list of modifiers, e.g. "Extra Cheese (+₹20), No Onion"
  String get modifiersSummary {
    if (modifiers.isEmpty) return '';
    return modifiers.map((m) {
      final delta = m.priceDelta;
      if (delta == 0) return m.name;
      return '${m.name} (+₹${delta.toStringAsFixed(2)})';
    }).join(', ');
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

  bool _sameMods(List<Modifier> a, List<Modifier> b) {
    if (a.length != b.length) return false;
    final setA = a.map((m) => m.id ?? m.name).toSet();
    final setB = b.map((m) => m.id ?? m.name).toSet();
    return setA.length == setB.length && setA.containsAll(setB);

  }

  /// Internal helper: find matching line (item+variant+same modifiers).
  int _findLineIndex(
      MenuItem item,
      ItemVariant? variant,
      List<Modifier> mods,
      ) {
    for (var i = 0; i < state.lines.length; i++) {
      final ln = state.lines[i];
      if (ln.item.id == item.id &&
          (ln.variant?.id ?? '') == (variant?.id ?? '') &&
          _sameMods(ln.modifiers, mods)) {
        return i;
      }
    }
    return -1;
  }

  /// Add `qty` of this item with specific variant + modifiers.
  ///
  /// Per-unit price = variant.basePrice + sum(selected modifier priceDelta)
  void addItem({
    required MenuItem item,
    ItemVariant? variant,
    required List<Modifier> modifiers,
    double qty = 1,
  }) {
    double price = variant?.basePrice ?? 0;
    for (final m in modifiers) {
      price += m.priceDelta;
    }

    final idx = _findLineIndex(item, variant, modifiers);
    if (idx >= 0) {
      // already in cart → bump qty
      final old = state.lines[idx];
      final updated = old.copyWith(qty: old.qty + qty);
      final newLines = [...state.lines];
      newLines[idx] = updated;
      state = PosCartState(lines: newLines);
    } else {
      // new cart line
      final newLine = CartLine(
        item: item,
        variant: variant,
        modifiers: modifiers,
        unitPrice: price,
        qty: qty,
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
/// INTERNAL DATA CLASSES FOR SHEETS / DIALOGS
/// ------------------------------------------------------------

/// One modifier group + all its modifiers (parsed from backend /modifiers_full).
class _ItemModifierGroupData {
  final String groupId;
  final String name;
  final bool requiredGroup;
  final int minSel;
  final int? maxSel;
  final List<Modifier> modifiers;

  _ItemModifierGroupData({
    required this.groupId,
    required this.name,
    required this.requiredGroup,
    required this.minSel,
    required this.maxSel,
    required this.modifiers,
  });

  factory _ItemModifierGroupData.fromRaw(Map<String, dynamic> j) {
    final modsRaw = (j['modifiers'] as List<dynamic>? ?? []);
    final mods = modsRaw.map((m) {
      return Modifier.fromJson({
        'id': m['id'],
        'group_id': j['group_id'],
        'name': m['name'],
        'price_delta': m['price_delta'],
      });
    }).toList();

    int toInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      final s = v.toString();
      return int.tryParse(s) ?? fallback;
    }

    int? toIntOrNull(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      final s = v.toString();
      return int.tryParse(s);
    }

    return _ItemModifierGroupData(
      groupId: j['group_id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      requiredGroup: (j['required'] as bool?) ?? false,
      minSel: toInt(j['min_sel'], 0),
      maxSel: toIntOrNull(j['max_sel']),
      modifiers: mods,
    );
  }
}

/// Result of the "add to cart" bottom sheet.
class _AddResult {
  final ItemVariant? variant;
  final int qty;
  final List<Modifier> modifiers;
  _AddResult({
    required this.variant,
    required this.qty,
    required this.modifiers,
  });
}

/// Info we gather before sending checkout to backend (channel, pax, table).
class _CheckoutRequest {
  final OrderChannel channel;
  final int? pax;
  final String? tableId;
  final OrderStatus targetStatus; // NEW: Add status
  _CheckoutRequest({
    required this.channel,
    this.pax,
    this.tableId,
    required this.targetStatus, // NEW: Add status
  });
}

/// ------------------------------------------------------------
/// POS PAGE
/// ------------------------------------------------------------

class PosPage extends ConsumerWidget {
  const PosPage({super.key});

  // Define a breakpoint for switching between mobile and tablet layouts
  static const double kTabletBreakpoint = 600.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_queueAutoSyncProvider);
    final tenantId = ref.watch(activeTenantIdProvider);
    final branchId = ref.watch(activeBranchIdProvider);

    // Guard: require active tenant/branch
    if (tenantId.isEmpty || branchId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('POS')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Please select a Tenant and Branch in the app first.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final catsAsync = ref.watch(posCategoriesProvider);
    final itemsAsync = ref.watch(posItemsProvider);
    final cart = ref.watch(posCartProvider);

    // Check screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > kTabletBreakpoint;

    // Define AppBar actions so they can be reused
    final appBarActions = [
      _BranchSwitcherAction(),
      IconButton(
        tooltip: 'Sync queued ops',
        icon: const Icon(Icons.sync),
        onPressed: () async {
          // This 'ref' (WidgetRef) is assignable to 'Ref<dynamic>'
          await pushQueueNow(context, ref);
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
    ];

    // Build the Menu view (for mobile tab and tablet layout)
    final menuView = Column(
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

        // MENU LIST
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Text('No items in this category'),
                );
              }

              // Prefetch for the first few visible items (no await → non-blocking)
              for (final it in items.take(24)) {
                final id = it.id;
                if (id != null && id.isNotEmpty) {
                  unawaited(_prefetchGate.withPermit(() => _getVariantsCached(ref, id)));
                  unawaited(_prefetchGate.withPermit(() => _getModsCached(ref, id)));
                }
              }

              // Use ListView for "least scrolling"
              return Scrollbar(
                child: ListView.separated(
                  primary: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  cacheExtent: 800,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false, // Rows are simple
                  addSemanticIndexes: false,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return _MenuItemRow(
                      key: ValueKey(item.id ?? i),
                      item: item,
                      onTap: () async {
                        if ((item.id ?? '').isEmpty) return;

                        // fetch & cache in parallel
                        final results = await Future.wait([
                          _getVariantsCached(ref, item.id!),
                          _getModsCached(ref, item.id!),
                        ]);
                        final variants = results[0] as List<ItemVariant>;
                        final modifierGroups = results[1] as List<_ItemModifierGroupData>;

                        // QUICK ADD if: no required groups AND <=1 variant
                        final hasRequired = modifierGroups.any((g) => g.requiredGroup && (g.minSel > 0));
                        if (!hasRequired && variants.length <= 1) {
                          final chosen = variants.isEmpty ? null : variants.first;
                          ref.read(posCartProvider.notifier).addItem(
                            item: item,
                            variant: chosen,
                            modifiers: const [],
                            qty: 1,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${item.name} x1 added to cart'),
                                duration: const Duration(milliseconds: 700),
                              ),
                            );
                          }
                          return;
                        }

                        // otherwise, open chooser
                        if (!context.mounted) return;
                        final res = await showModalBottomSheet<_AddResult>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => _AddToCartSheet(
                            item: item,
                            variants: variants,
                            modifierGroups: modifierGroups,
                          ),
                        );
                        if (res == null) return;
                        ref.read(posCartProvider.notifier).addItem(
                          item: item,
                          variant: res.variant,
                          modifiers: res.modifiers,
                          qty: res.qty.toDouble(),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${item.name} x${res.qty} added to cart'),
                              duration: const Duration(milliseconds: 800),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Failed to load items:\n$e',
                      textAlign: TextAlign.center,
                    ),
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
      ],
    );

    // Build the Cart view
    final cartView = _VerticalCartView(cart: cart);

    if (isTablet) {
      // --- TABLET LAYOUT ---
      return Scaffold(
        appBar: AppBar(
          title: const Text('POS'),
          actions: appBarActions,
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- LEFT SIDE (MENU) ---
            Expanded(
              flex: 65, // 65% width
              child: menuView, // Use the extracted menuView
            ),
            // --- RIGHT SIDE (CART) ---
            Expanded(
              flex: 35, // 35% width
              child: cartView, // Use the extracted cartView
            ),
          ],
        ),
      );
    } else {
      // --- PHONE LAYOUT ---
      // Calculate cart item count for the badge
      final cartItemCount = cart.lines.fold<int>(0, (sum, line) => sum + line.qty.round());

      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('POS'),
            actions: appBarActions,
            bottom: TabBar(
              tabs: [
                const Tab(
                  icon: Icon(Icons.restaurant_menu),
                  text: 'Menu',
                ),
                Tab(
                  child: Badge(
                    label: Text('$cartItemCount'),
                    // isManagingSize: true, // This is the default
                    isLabelVisible: cartItemCount > 0,
                    child: const Icon(Icons.shopping_cart),
                  ),
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              // Tab 1: Menu
              menuView,
              // Tab 2: Cart
              cartView,
            ],
          ),
        ),
      );
    }
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
        primary: false,
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

/// NEW: One menu item row (replaces _ItemCard)
class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({Key? key, required this.item, required this.onTap}) : super(key: key);
  final MenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.brown.shade50,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Image (small)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: MenuBannerImage(
                    path: item.imageUrl,
                    borderRadius: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Text (prominent)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16, // Larger font
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description != null &&
                        item.description!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Add button
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.brown.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Add +',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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

/// Bottom sheet to pick variant + modifiers + qty before adding to cart
class _AddToCartSheet extends StatefulWidget {
  final MenuItem item;
  final List<ItemVariant> variants;
  final List<_ItemModifierGroupData> modifierGroups;
  const _AddToCartSheet({
    required this.item,
    required this.variants,
    required this.modifierGroups,
  });

  @override
  State<_AddToCartSheet> createState() => _AddToCartSheetState();
}

class _AddToCartSheetState extends State<_AddToCartSheet> {
  ItemVariant? _selectedVariant;
  int _qty = 1;

  /// per groupId -> set of selected modifier ids
  final Map<String, Set<String>> _selModsByGroup = {};

  @override
  void initState() {
    super.initState();

    // pick default variant if available
    if (widget.variants.isNotEmpty) {
      try {
        _selectedVariant =
            widget.variants.firstWhere((v) => v.isDefault, orElse: () {
              return widget.variants.first;
            });
      } catch (_) {
        _selectedVariant = widget.variants.first;
      }
    }

    // init modifier selection map
    for (final g in widget.modifierGroups) {
      _selModsByGroup[g.groupId] = <String>{};
    }
  }

  List<Modifier> _collectSelectedModifiers() {
    final out = <Modifier>[];
    for (final g in widget.modifierGroups) {
      final picked = _selModsByGroup[g.groupId] ?? <String>{};
      for (final m in g.modifiers) {
        final key = m.id ?? m.name;
        if (picked.contains(key)) {
          out.add(m);
        }
      }
    }
    return out;
  }

  double _perUnitPrice() {
    final base = _selectedVariant?.basePrice ?? 0;
    double extra = 0;
    for (final m in _collectSelectedModifiers()) {
      extra += m.priceDelta;
    }
    return base + extra;
  }

  double _totalPrice() => _perUnitPrice() * _qty;

  void _toggleModifier(
      _ItemModifierGroupData group,
      Modifier mod,
      bool newVal,
      ) {
    final key = mod.id ?? mod.name;
    final picked = _selModsByGroup[group.groupId] ?? <String>{};

    if (newVal) {
      // enforce max_sel if provided
      if (group.maxSel != null &&
          picked.length >= group.maxSel! &&
          !picked.contains(key)) {
        // hit the cap -> don't add more
        return;
      }
      picked.add(key);
    } else {
      picked.remove(key);
    }

    setState(() {
      _selModsByGroup[group.groupId] = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final perUnit = _perUnitPrice();
    final total = _totalPrice();

    final hasImg =
        widget.item.imageUrl != null && widget.item.imageUrl!.trim().isNotEmpty;

    // Make the sheet occupy a reasonable max height, e.g., 90% of the screen
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          // Use SingleChildScrollView for the content *within* the constrained box
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image + Title / desc
                if (hasImg) ...[
                  MenuBannerImage(
                    path: widget.item.imageUrl,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  widget.item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.item.description != null &&
                    widget.item.description!.trim().isNotEmpty)
                  Text(
                    widget.item.description!,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),

                const SizedBox(height: 16),

                // Variant picker
                if (widget.variants.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose Variant',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...widget.variants.map((v) {
                        return RadioListTile<ItemVariant>(
                          title: Text(
                            v.label.isEmpty ? 'Default' : v.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '₹ ${v.basePrice.toStringAsFixed(2)}',
                          ),
                          value: v,
                          groupValue: _selectedVariant,
                          onChanged: (val) {
                            setState(() {
                              _selectedVariant = val;
                            });
                          },
                        );
                      }),
                    ],
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No variants found.\nPrice will default to ₹0.00',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Modifier groups
                if (widget.modifierGroups.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add-ons / Choices',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...widget.modifierGroups.map((group) {
                        final pickedSet =
                            _selModsByGroup[group.groupId] ?? <String>{};

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            if (group.maxSel != null)
                              Text(
                                'Choose up to ${group.maxSel}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            const SizedBox(height: 4),
                            ...group.modifiers.map((m) {
                              final key = m.id ?? m.name;
                              final selected = pickedSet.contains(key);
                              final priceText = m.priceDelta == 0
                                  ? ''
                                  : ' (+₹${m.priceDelta.toStringAsFixed(2)})';

                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text(
                                  '${m.name}$priceText',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                value: selected,
                                onChanged: (val) {
                                  if (val == null) return;
                                  _toggleModifier(group, m, val);
                                },
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        );
                      }),
                    ],
                  ),

                const SizedBox(height: 8),

                // Qty row + per-unit + total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            setState(() {
                              if (_qty > 1) _qty--;
                            });
                          },
                        ),
                        Text(
                          '$_qty',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            setState(() {
                              _qty++;
                            });
                          },
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Per unit: ₹ ${perUnit.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Total: ₹ ${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Cancel / Add buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            _AddResult(
                              variant: _selectedVariant,
                              qty: _qty,
                              modifiers: _collectSelectedModifiers(),
                            ),
                          );
                        },
                        child: Text('Add • ₹ ${total.toStringAsFixed(2)}'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16), // Extra padding at the bottom
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// ---------------- OFFLINE QUEUE (Ops Journal) ----------------

const _kOpsQueueKey = 'pos_offline_ops_v1';
const _kDeviceId    = 'flutter-pos';

Future<List<Map<String, dynamic>>> _readQueuedOps(Read read) async {
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

Future<void> _writeQueuedOps(Read read, List<Map<String, dynamic>> ops) async {
  final prefs = read(prefsProvider);
  await prefs.setString(_kOpsQueueKey, convert.jsonEncode(ops));
}

Future<void> _enqueueOps(Read read, List<Map<String, dynamic>> newOps) async {
  final cur = await _readQueuedOps(read);
  cur.addAll(newOps);
  await _writeQueuedOps(read, cur);
}

Future<int> _queuedCount(Read read) async {
  final cur = await _readQueuedOps(read);
  return cur.length;
}

/// Pushes everything in one call to /sync/push. Clears queue on success.
Future<void> pushQueueNow(BuildContext ctx, WidgetRef ref) async {
  final client = ref.read(apiClientProvider);
  final ops = await _readQueuedOps(ref.read);
  if (ops.isEmpty) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Nothing to sync')));
    }
    return;
  }
  final orderNos = _extractOrderNos(ops);
  try {
    dev.log(convert.jsonEncode({'ops_preview': ops.take(3).toList(), 'count': ops.length}),
        name: 'pos.sync.request'); // 🔧
    final resp = await client.syncPush(deviceId: _kDeviceId, ops: ops);
    dev.log(convert.jsonEncode(resp), name: 'pos.sync.response');        // 🔧

    // Optional: show applied/error counts if backend returns them
    final applied = (resp['applied'] ?? 0).toString();
    final errors  = (resp['errors']  ?? 0).toString();

    await _writeQueuedOps(ref.read, []); // clear only on success
    ref.read(pendingOrdersProvider.notifier).removeByOrderNos(orderNos);

    // This now invalidates the filter-aware provider
    ref.invalidate(ordersFutureProvider);

    // This invalidates the KANBAN board provider from kot_page.dart
    for (final status in KOTStatus.values) {
      ref.invalidate(kotTicketsProvider(status));
    }

    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Synced ${ops.length} op(s) • applied: $applied • errors: $errors ✅')),
      );
    }
  } catch (e) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    }
  }
}

/// MODIFIED: This function now builds *both* an Order op and a KOT op.
List<Map<String, dynamic>> buildCheckoutOps({
  required String orderNo,
  required String tenantId,
  required String branchId,
  required OrderChannel channel,
  required OrderStatus targetStatus, // NEW
  required int? pax,
  required String? tableId,
  required List<CartLine> lines,
  required double amountDueHint, // unused here; backend recomputes anyway
}) {
  // 1. Build the list of items for the Order payload
  final orderItemsPayload = <Map<String, dynamic>>[];
  // 2. Build a separate list of lines for the KOT payload
  final kotLinesPayload = <Map<String, dynamic>>[];

  for (final l in lines) {
    // Generate a unique client-side ID for this line item
    final clientLineId = 'li-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999)}';

    orderItemsPayload.add({
      'client_id': clientLineId, // Send a client-side ID for linking
      'item_id': l.item.id,
      'variant_id': l.variant?.id,
      'qty': l.qty,
      'unit_price': l.unitPrice,
      'line_discount': 0.0,
      'gst_rate': l.item.gstRate,
      // ... any other fields your OrderItem op needs
    });

    // KOT line payload is simpler
    kotLinesPayload.add({
      'order_item_client_id': clientLineId, // Reference the client-side line ID
      'name': l.item.name, // Send name/qty for printing
      'qty': l.qty,
      'variant_label': l.variant?.label,
      'modifiers': l.modifiers.map((m) => m.name).toList(), // Send modifier names
    });
  }

  // NEW: Generate a client-side UUID for the KOT
  final String clientKotId = 'kot-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999)}';

  // Return a list of *two* operations
  return [
    // --- OP 1: The Order ---
    {
      'entity': 'Order',
      'entity_id': orderNo, // Use orderNo as the client-side ID
      'op': 'UPSERT',
      'payload': {
        'tenant_id': tenantId,
        'branch_id': branchId,
        'order_no': orderNo,
        'channel': channel.name,
        'status': targetStatus.name, // Use the selected status
        if (pax != null) 'pax': pax,
        if (tableId != null) 'table_id': tableId,
        'opened_at': DateTime.now().toUtc().toIso8601String(),
        'items': orderItemsPayload, // Use the detailed item list
      },
    },
    // --- OP 2: The Kitchen Ticket ---
    {
      'entity': 'KitchenTicket',
      'entity_id': clientKotId, // A new client-side ID for this KOT
      'op': 'UPSERT',
      'payload': {
        // We link by the client-side order_no.
        // The backend /sync/push *must* be smart enough to find the
        // Order.id from the first op and use it here.
        'order_no_ref': orderNo,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'ticket_no_client': Random().nextInt(9000) + 1000, // A temp ticket#
        'status': KOTStatus.NEW.name, // KOTs always start as NEW
        'printed_at': DateTime.now().toUtc().toIso8601String(),
        'lines': kotLinesPayload, // Send the simplified lines for printing
        // Note: We are only creating one KOT for all items.
        // A smarter implementation would group lines by 'kitchenStationId'
        // and create one KOT op *per station*.
      },
    },
  ];
}


Set<String> _extractOrderNos(List<Map<String, dynamic>> ops) {
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

/// ---------------- FAST ONLINE HELPERS (no queue, but much quicker) ----------------

Future<void> _addItemsBulkFast(
    ApiClient client,
    String orderId,
    List<CartLine> lines, {
      int parallel = _kAddItemsParallel, // ← uses SPEED CONFIG
    }) async {
  // limit concurrency to avoid server overload
  final chunks = <List<CartLine>>[];
  for (var i = 0; i < lines.length; i += parallel) {
    chunks.add(
      lines.sublist(i, i + parallel > lines.length ? lines.length : i + parallel),
    );
  }
  for (final chunk in chunks) {
    await Future.wait(chunk.map((l) {
      final orderItem = OrderItem(
        id: null,
        orderId: orderId,
        itemId: l.item.id!,
        variantId: l.variant?.id,
        parentLineId: null,
        qty: l.qty,
        unitPrice: l.unitPrice,
        lineDiscount: 0,
        gstRate: l.item.gstRate,
        cgst: 0,
        sgst: 0,
        igst: 0,
        taxableValue: 0,
      );
      final mods = l.modifiers
          .map((m) => OrderItemModifier(
        id: null,
        orderItemId: '',
        modifierId: m.id ?? '',
        qty: 1,
        priceDelta: m.priceDelta,
      ))
          .toList();
      // Add error handling inside the map to prevent one failure from
      // killing the whole batch.
      return client.addOrderItem(orderId, orderItem, modifiers: mods)
          .catchError((e) {
        debugPrint('Failed to add item ${l.item.name}: $e');
        // Continue regardless of error
      });
    }));
  }
}

/// NEW: Renamed from _CartSummary. This is now the vertical cart view.
class _VerticalCartView extends ConsumerStatefulWidget {
  const _VerticalCartView({required this.cart});
  final PosCartState cart;

  @override
  ConsumerState<_VerticalCartView> createState() => _VerticalCartViewState();
}

class _VerticalCartViewState extends ConsumerState<_VerticalCartView> {
  bool _busy = false;
  late final ScrollController _cartCtl;

  @override
  void initState() {
    super.initState();
    _cartCtl = ScrollController();
  }

  @override
  void dispose() {
    _cartCtl.dispose();
    super.dispose();
  }

  // guess pax from qty total
  int _paxGuess(PosCartState cart) {
    return cart.lines.fold<int>(0, (sum, l) => sum + l.qty.round());
  }

  // dialog to choose DINE_IN / TAKEAWAY / DELIVERY and pax and table
  Future<_CheckoutRequest?> _askCheckoutInfo(PosCartState cart) async {
    // Preload tables before showing dialog to avoid async gap inside the builder.
    // final tables = await ref.read(diningTablesProvider.future);

    if (!mounted) return null;

    OrderChannel chosenChannel = OrderChannel.TAKEAWAY;
    String? chosenTableId;
    // NEW: Add state for order status, default to KITCHEN
    OrderStatus chosenStatus = OrderStatus.KITCHEN;
    final paxCtl = TextEditingController(
      text: _paxGuess(cart).toString(),
    );

    return showDialog<_CheckoutRequest>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final tablesAsync = ref.watch(diningTablesProvider);
            final tables = tablesAsync.asData?.value ?? const <DiningTable>[];
            // final tablesLoading = tablesAsync.isLoading; // Not used, but good to know
            return AlertDialog(
              title: const Text('Checkout details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<OrderChannel>(
                      // Note: initialValue is deprecated, use value instead
                      value: chosenChannel,
                      decoration: const InputDecoration(labelText: 'Channel'),
                      items: OrderChannel.values.map((ch) {
                        return DropdownMenuItem<OrderChannel>(
                          value: ch,
                          child: Text(ch.name.replaceAll('_', ' ')),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setLocalState(() {
                            chosenChannel = val;
                            // if we're not dine-in, clear table
                            if (chosenChannel != OrderChannel.DINE_IN) {
                              chosenTableId = null;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: paxCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Pax / Guests',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Only show table picker for dine-in
                    if (chosenChannel == OrderChannel.DINE_IN)
                      DropdownButtonFormField<String?>(
                        // Note: initialValue is deprecated, use value instead
                        value: chosenTableId,
                        decoration: const InputDecoration(
                          labelText: 'Table',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No table'),
                          ),
                          ...tables.map(
                                (t) => DropdownMenuItem<String?>(
                              value: t.id,
                              child: Text(
                                t.seats != null
                                    ? '${t.code} (${t.seats} seats)'
                                    : t.code,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setLocalState(() {
                            // val is nullable, but chosenTableId is also nullable
                            chosenTableId = val;
                          });
                        },
                      ),

                    const SizedBox(height: 12),
                    // NEW: Add Order Status dropdown
                    DropdownButtonFormField<OrderStatus>(
                      value: chosenStatus,
                      decoration: const InputDecoration(labelText: 'Set Order Status'),
                      // Only allow setting to "KITCHEN" or "OPEN"
                      items: [
                        OrderStatus.KITCHEN,
                        OrderStatus.OPEN,
                        OrderStatus.READY,
                      ].map((st) {
                        return DropdownMenuItem<OrderStatus>(
                          value: st,
                          child: Text(st.name.replaceAll('_', ' ')),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setLocalState(() {
                            chosenStatus = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final paxVal = int.tryParse(paxCtl.text.trim());
                    Navigator.pop(
                      ctx,
                      _CheckoutRequest(
                        channel: chosenChannel,
                        pax: paxVal,
                        tableId: chosenTableId,
                        targetStatus: chosenStatus, // NEW: Pass status
                      ),
                    );
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// [OPTIMIZED]
  /// Runs KOT, Invoice, Print, and Drawer ops in the background
  /// *after* payment is successful. Does not block the UI.
  Future<void> _runPostCheckoutTasks(
      String orderId,
      String tenantId,
      String branchId, {
        required bool autoPrintKot,
        required bool autoPrintInvoice,
      }) async {
    // Use `ref.read` as this is a fire-and-forget task
    // and we shouldn't watch providers.
    final client = ref.read(apiClientProvider);

    // We can run KOT, Invoice, and Drawer in parallel
    final kotF = client
        .fireKotForOrder(orderId: orderId, stationId: null)
        .catchError((e) {
      debugPrint('[BG] Failed to fire KOT for $orderId: $e');
      return <String, dynamic>{}; // return dummy value
    });

    final invoiceF = client.createInvoice(orderId).catchError((e) {
      debugPrint('[BG] Failed to create invoice for $orderId: $e');
      return <String, dynamic>{}; // return dummy value
    });

    final drawerF = client
        .openDrawer(tenantId: tenantId, branchId: branchId)
        .catchError((e) {
      debugPrint('[BG] Failed to open drawer for $branchId: $e');
      return <String, dynamic>{}; // return dummy value
    });

    // Wait for the "primary" tasks to finish
    // We only truly need to wait for invoiceF to know the invoiceId
    final results = await Future.wait([kotF, invoiceF, drawerF]);
    final invoiceResp = results[1] as Map<String, dynamic>; // from invoiceF

    // --- Start "secondary" print tasks (which are also fire/forget) ---

    // 1. Print KOTs (depends on kotF succeeding, though not strictly)
    if (autoPrintKot) {
      try {
        // Use read, not watch, and get the future
        final snap = await ref.read(printerSnapshotProvider.future);
        for (final pid in snap.kitchenPrinterIds) {
          // No need to await these individual prints
          unawaited(client.printKot(orderId: orderId, printerId: pid)
              .catchError((e) {
            debugPrint('[BG] Failed to print KOT to $pid: $e');
          }));
        }
      } catch (e) {
        debugPrint('[BG] Failed to get printer snapshot for KOT: $e');
      }
    }

    // 2. Print Invoice (depends on invoiceF succeeding)
    final invoiceId = invoiceResp['invoice_id']?.toString();
    if (autoPrintInvoice && invoiceId != null && invoiceId.isNotEmpty) {
      // No need to await this
      unawaited(client.printInvoice(invoiceId).catchError((e) {
        debugPrint('[BG] Failed to print invoice $invoiceId: $e');
      }));
    }
  }


  /// [MODIFIED]
  /// talk to backend: create order, add items, SEND KOT, AND SET STATUS (no payment)
  Future<void> _performCheckout(
      PosCartState cart,
      _CheckoutRequest info, {
        bool preferFastPath = _kPreferFastPath,
        bool autoPrintKot = _kAutoPrintKOT,
        bool autoPrintInvoice = _kAutoPrintInvoice,
      }) async {
    final t = _PhaseTimer();
    final client = ref.read(apiClientProvider);
    final tenantId = ref.read(activeTenantIdProvider);
    final branchId = ref.read(activeBranchIdProvider);

    // Guard: must have tenant/branch
    if (tenantId.isEmpty || branchId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select tenant & branch first')),
      );
      return;
    }

    // Create a client-stable order number BEFORE using it anywhere.
    final String orderNo = 'POS1-${DateTime.now().millisecondsSinceEpoch}';

    // ---------------- OFFLINE-FIRST PATH (if requested) ----------------
    if (!preferFastPath) {
      final double amountHint = cart.subTotal; // server will recompute

      // UPDATED: Pass targetStatus and all cart lines to build the ops
      final ops = buildCheckoutOps(
        orderNo: orderNo,
        tenantId: tenantId,
        branchId: branchId,
        channel: info.channel,
        targetStatus: info.targetStatus, // Pass selected status
        pax: info.pax,
        tableId: info.tableId,
        lines: cart.lines, // Pass full cart lines
        amountDueHint: amountHint,
      );

      await _enqueueOps(ref.read, ops);
      unawaited(pushQueueNow(context, ref)); // This will sync and invalidate

      ref.read(pendingOrdersProvider.notifier).addQueued(
        orderNo: orderNo,
        channel: info.channel,
        tableId: info.tableId,
        openedAt: DateTime.now(),
      );

      ref.read(posCartProvider.notifier).clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $orderNo queued (${ops.length} ops). Tap 🔄 to sync.'),
          duration: const Duration(seconds: 3),
        ),
      );
      return; // Done (offline-first)
    }

    // ---------------- FAST ONLINE PATH ----------------

    // 1) Open order (single call)
    late final String orderId;
    try {
      final created = await client.openOrderOffline(
        tenantId: tenantId,
        branchId: branchId,
        orderNo: orderNo,
        channel: info.channel.name,
        pax: info.pax,
        tableId: info.tableId,
        customerId: null,
        note: null,
      );
      t.lap('open order');
      orderId = created['id']?.toString() ?? '';
    } catch (e) {
      // If open fails → fallback to offline queue so cashier isn’t blocked
      final fallbackOps = buildCheckoutOps(
        orderNo: orderNo,
        tenantId: tenantId,
        branchId: branchId,
        channel: info.channel,
        targetStatus: info.targetStatus, // Pass status
        pax: info.pax,
        tableId: info.tableId,
        lines: cart.lines,
        amountDueHint: cart.subTotal,
      );
      await _enqueueOps(ref.read, fallbackOps);
      ref.read(pendingOrdersProvider.notifier).addQueued(
        orderNo: orderNo,
        channel: info.channel,
        tableId: info.tableId,
        openedAt: DateTime.now(),
      );
      ref.read(posCartProvider.notifier).clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Went offline. Order queued as $orderNo.')),
        );
      }
      return;
    }

    if (orderId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No order ID from backend')),
      );
      return;
    }

    // 2) Add items in parallel (chunked)
    try {
      await _addItemsBulkFast(client, orderId, cart.lines);
      t.lap('add items (bulk)');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add items: $e')),
      );
      // Don't return; maybe some items were added. Try to proceed.
    }

    // 3) [NEW] Fire KOT immediately
    try {
      await client.fireKotForOrder(orderId: orderId, stationId: null);
      t.lap('fire KOT');
    } catch (e) {
      debugPrint('Failed to fire KOT for $orderId: $e');
      // Don't block on KOT failure, proceed to status update
    }

    // 4) [NEW] Update status to the one selected in the dialog
    try {
      await client.updateOrderStatus(
        orderId,
        OrderStatusUpdate(status: info.targetStatus),
      );
      t.lap('update status');
    } catch (e) {
      debugPrint('Failed to update status for $orderId: $e');
      // Don't block
    }

    // 5) [REMOVED] Get Totals → Pay
    // We are NOT paying here. The "pay" block is removed.

    // 6) [MODIFIED] After firing KOT, SHOW SUCCESS and clear cart IMMEDIATELY.
    ref.read(posCartProvider.notifier).clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order $orderNo (${info.channel.name}) sent to kitchen! ✅',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // 7) [MODIFIED] Invalidate caches
    ref.invalidate(ordersFutureProvider); // Update Orders page
    // Update KOT page
    for (final status in KOTStatus.values) {
      // Use the filter-aware provider from kot_page.dart
      ref.invalidate(kotTicketsProvider(status));
    }

    // 8) [REMOVED] Run all post-checkout tasks
    // We removed this as we already fired the KOT and are skipping payment/invoice.
    // unawaited(_runPostCheckoutTasks(...));
    t.lap('checkout complete (no payment)');

    // We are done. The UI is already updated and non-blocking.
  }

  Future<void> _startCheckout() async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });

    try {
      final req = await _askCheckoutInfo(widget.cart);
      if (req == null) return; // user cancelled
      ref.read(netBusyProvider.notifier).state = true;
      try {
        await _performCheckout(widget.cart, req);
      } finally {
        ref.read(netBusyProvider.notifier).state = false;
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // NEW BUILD METHOD for vertical cart
  @override
  Widget build(BuildContext context) {
    final lines = widget.cart.lines;
    final total = widget.cart.subTotal;

    // Use a light brown background for the cart area
    final cardColor = Colors.brown.shade50;

    // On mobile, this view is in a TabBarView and should fill the space.
    // On tablet, it's in an Expanded flex.
    // We'll wrap with Material to give it a consistent background and
    // optional elevation on tablet.
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > PosPage.kTabletBreakpoint;

    return Material(
      elevation: isTablet ? 4 : 0, // Side panel shadow on tablet only
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0), // Consistent padding
        child: Column(
          // mainAxisSize: MainAxisSize.min, // This is good for tablet
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              'Current Order',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Divider(height: 16),

            // Cart lines list (now expands)
            Expanded(
              child: lines.isEmpty
                  ? const Center(
                child: Text(
                  'Cart is empty',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
                  : Scrollbar(
                controller: _cartCtl,
                thumbVisibility: true, // Make scrollbar visible
                child: ListView.separated(
                  controller: _cartCtl,
                  primary: false,
                  itemCount: lines.length,
                  separatorBuilder: (_, __) => const Divider(height: 8),
                  itemBuilder: (context, i) {
                    final ln = lines[i];
                    // This is the new cart line item
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Name and Total Price
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                ln.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹ ${ln.lineTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        // Row 2: Modifiers
                        if (ln.modifiers.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              ln.modifiersSummary,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        // Row 3: Unit Price, Stepper, Delete
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Text(
                                '₹ ${ln.unitPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const Spacer(),
                              // Qty stepper (compact)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                iconSize: 20,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                onPressed: _busy
                                    ? null
                                    : () {
                                  ref.read(posCartProvider.notifier).decQty(i);
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
                                iconSize: 20,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                onPressed: _busy
                                    ? null
                                    : () {
                                  ref.read(posCartProvider.notifier).incQty(i);
                                },
                              ),
                              // Delete button (compact)
                              IconButton(
                                icon: const Icon(Icons.close),
                                iconSize: 20,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                tooltip: 'Remove line',
                                onPressed: _busy
                                    ? null
                                    : () {
                                  ref.read(posCartProvider.notifier).removeLine(i);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // subtotal row
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

            // Button row
            Row(
              children: [
                // CLEAR CART
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Clear'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.brown.shade200,
                    ),
                    onPressed: lines.isEmpty || _busy
                        ? null
                        : () {
                      ref.read(posCartProvider.notifier).clear();
                    },
                  ),
                ),

                const SizedBox(width: 12),

                // CHECKOUT
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    icon: _busy
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.point_of_sale),
                    label: Text(
                      _busy
                          ? 'Processing...'
                          : 'Checkout ₹ ${total.toStringAsFixed(2)}',
                    ),
                    onPressed: lines.isEmpty || _busy ? null : _startCheckout,
                  ),
                ),
              ],
            ),
            // Add padding for the bottom navigation bar on mobile
            if (!isTablet)
              SizedBox(height: kBottomNavigationBarHeight > 0 ? kBottomNavigationBarHeight / 2 : 12),
          ],
        ),
      ),
    );
  }
}