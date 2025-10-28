import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/models.dart';
import 'package:waah_frontend/widgets/menu_media.dart';

/// ------------------------------------------------------------
/// PROVIDERS: categories, items, tables, cart
/// ------------------------------------------------------------

/// Which category is currently selected in POS? null means "All".
final selectedCategoryIdProvider = StateProvider<String?>((ref) => null);

/// Load menu categories for the ACTIVE tenant/branch.
final posCategoriesProvider =
FutureProvider.autoDispose<List<MenuCategory>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final tenantId = ref.watch(activeTenantIdProvider);
  final branchId = ref.watch(activeBranchIdProvider);

  if (tenantId.isEmpty || branchId.isEmpty) return <MenuCategory>[];

  final cats = await client.fetchCategories(
    tenantId: tenantId,
    branchId: branchId,
  );

  // stable sort by position for consistent UI
  cats.sort((a, b) => (a.position).compareTo(b.position));
  return cats;
});

/// Load menu items for currently selected category for the ACTIVE tenant.
final posItemsProvider =
FutureProvider.autoDispose<List<MenuItem>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final tenantId = ref.watch(activeTenantIdProvider);
  final catId = ref.watch(selectedCategoryIdProvider);

  if (tenantId.isEmpty) return <MenuItem>[];

  final items = await client.fetchItems(
    // treat empty-string like null
    categoryId: (catId == null || (catId.isNotEmpty && catId.trim().isEmpty))
        ? null
        : catId,
    tenantId: tenantId,
  );

  // Only active / not stock_out, just to keep POS clean.
  final filtered = items.where((i) => i.isActive && !i.stockOut).toList();

  // sort by name for predictable grid
  filtered.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return filtered;
});

/// Load dining tables for ACTIVE branch.
final diningTablesProvider = FutureProvider<List<DiningTable>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final branchId = ref.watch(activeBranchIdProvider);

  if (branchId.isEmpty) return <DiningTable>[];

  final tables = await client.fetchDiningTables(branchId: branchId);

  // local defensive sort by code just in case
  final sorted = [...tables]
    ..sort((a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()));

  return sorted;
});

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
  _CheckoutRequest({
    required this.channel,
    this.pax,
    this.tableId,
  });
}

/// ------------------------------------------------------------
/// POS PAGE
/// ------------------------------------------------------------

class PosPage extends ConsumerWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

                return LayoutBuilder(
                  builder: (context, cs) {
                    // Responsive grid: wider screens show more columns
                    final maxWidth = cs.maxWidth;
                    final cross = maxWidth >= 1200
                        ? 6
                        : maxWidth >= 992
                        ? 5
                        : maxWidth >= 768
                        ? 4
                        : maxWidth >= 560
                        ? 3
                        : 2;

                    return Scrollbar(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          // Compact card to avoid covering background visually
                          childAspectRatio: 3 / 4,
                        ),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final it = items[i];
                          return _ItemCard(
                            item: it,
                            onTap: () async {
                              final client = ref.read(apiClientProvider);

                              // 1. fetch variants
                              final variants =
                              await client.fetchVariants(it.id ?? '');

                              // 2. fetch modifier groups (+mods) from backend
                              final rawGroups =
                              await client.fetchItemModifierGroups(
                                  it.id ?? '');
                              final modifierGroups = rawGroups
                                  .map<_ItemModifierGroupData>(
                                    (g) => _ItemModifierGroupData.fromRaw(
                                  Map<String, dynamic>.from(g),
                                ),
                              )
                                  .toList();

                              // 3. bottom sheet (variant + modifiers + qty)
                              if (!context.mounted) return;
                              final res =
                              await showModalBottomSheet<_AddResult>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => _AddToCartSheet(
                                  item: it,
                                  variants: variants,
                                  modifierGroups: modifierGroups,
                                ),
                              );
                              if (res == null) return;

                              // 4. add to cart
                              ref.read(posCartProvider.notifier).addItem(
                                item: it,
                                variant: res.variant,
                                modifiers: res.modifiers,
                                qty: res.qty.toDouble(),
                              );

                              // 5. toast
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${it.name} x${res.qty} added to cart'),
                                    duration:
                                    const Duration(milliseconds: 800),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    );
                  },
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

          // CART SUMMARY (capped height so it never "covers" the screen)
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

/// One menu item card in the grid (shows image if available)
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});
  final MenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImg = (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty);

    return Material(
      color: Colors.brown.shade50,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            AspectRatio(
              aspectRatio: 4 / 3,
              child: hasImg
                  ? MenuBannerImage(
                path: item.imageUrl,
                // Banner widget already handles fit/placeholder
              )
                  : Container(
                color: Colors.brown.shade100,
                child: const Center(
                  child: Icon(Icons.image_outlined, size: 36),
                ),
              ),
            ),

            // Texts
            Expanded(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description != null &&
                        item.description!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
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
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image + Title / desc
              if (hasImg) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: MenuBannerImage(path: widget.item.imageUrl),
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
                    }).toList(),
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
                          }).toList(),
                          const SizedBox(height: 8),
                        ],
                      );
                    }).toList(),
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

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom cart: shows lines, lets you +/-/X, shows total, and checkout
class _CartSummary extends ConsumerStatefulWidget {
  const _CartSummary({required this.cart});
  final PosCartState cart;

  @override
  ConsumerState<_CartSummary> createState() => _CartSummaryState();
}

class _CartSummaryState extends ConsumerState<_CartSummary> {
  bool _busy = false;

  // guess pax from qty total
  int _paxGuess(PosCartState cart) {
    return cart.lines.fold<int>(0, (sum, l) => sum + l.qty.round());
  }

  // dialog to choose DINE_IN / TAKEAWAY / DELIVERY and pax and table
  Future<_CheckoutRequest?> _askCheckoutInfo(PosCartState cart) async {
    // Preload tables before showing dialog to avoid async gap inside the builder.
    final tables = await ref.read(diningTablesProvider.future);

    if (!mounted) return null;

    OrderChannel chosenChannel = OrderChannel.TAKEAWAY;
    String? chosenTableId;
    final paxCtl = TextEditingController(
      text: _paxGuess(cart).toString(),
    );

    return showDialog<_CheckoutRequest>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              title: const Text('Checkout details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<OrderChannel>(
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
                            chosenTableId = val;
                          });
                        },
                      ),

                    // TODO later:
                    // if DELIVERY -> ask phone/address
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

  // talk to backend: create order, add items, take cash, invoice, print
  // talk to backend: create order, add items, SEND KOT, take cash, invoice, print
  Future<void> _performCheckout(
      WidgetRef ref,
      PosCartState cart,
      _CheckoutRequest info,
      ) async {
    final client = ref.read(apiClientProvider);
    final tenantId = ref.read(activeTenantIdProvider);
    final branchId = ref.read(activeBranchIdProvider);

    if (tenantId.isEmpty || branchId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select tenant & branch first')),
      );
      return;
    }

    // 1. generate offline-friendly order number
    final orderNo = 'POS1-${DateTime.now().millisecondsSinceEpoch}';

    // pax fallback
    final paxFromCart = _paxGuess(cart);
    final int? paxToSend = (info.pax != null && info.pax! > 0)
        ? info.pax
        : (paxFromCart == 0 ? null : paxFromCart);

    // 2. create order using lightweight route
    late final String orderId;
    try {
      final created = await client.openOrderOffline(
        tenantId: tenantId,
        branchId: branchId,
        orderNo: orderNo,
        channel: info.channel.name, // "DINE_IN"/"TAKEAWAY"/etc.
        pax: paxToSend,
        tableId: info.tableId,
        customerId: null,
        note: null,
      );
      orderId = created['id']?.toString() ?? '';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create order: $e')),
      );
      return;
    }

    if (orderId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No order ID from backend')),
      );
      return;
    }

    // 3. add each cart line as an order_item (with modifiers!)
    for (final line in cart.lines) {
      final itemId = line.item.id;
      if (itemId == null) continue;

      final orderItem = OrderItem(
        id: null,
        orderId: orderId,
        itemId: itemId,
        variantId: line.variant?.id,
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

      // Convert selected Menu Modifiers -> OrderItemModifier payloads (qty=1)
      final mods = line.modifiers
          .map(
            (m) => OrderItemModifier(
          id: null,
          orderItemId: '', // ignored on create
          modifierId: m.id ?? '',
          qty: 1,
          priceDelta: m.priceDelta,
        ),
      )
          .toList();

      try {
        await client.addOrderItem(orderId, orderItem, modifiers: mods);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add line item: $e')),
        );
        return;
      }
    }

    // 4. SEND KOT TO KITCHEN (create /kot/tickets and print)
    try {
      await client.fireKotForOrder(
        orderId: orderId,
        stationId: null, // null => send ALL items in one ticket
      );
    } catch (e) {
      // Do NOT block billing if the kitchen printer is offline.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KOT not sent: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      // continue anyway
    }

    // 5. totals (to know how much to collect)
    late final OrderDetail detail;
    try {
      detail = await client.getOrderDetail(orderId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load totals: $e')),
      );
      return;
    }
    final amountDue = detail.totals.due;

    // 6. pay in full CASH
    try {
      await client.pay(orderId, PayMode.CASH, amountDue);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
      return;
    }

    // 7. create invoice (DB row + invoice number)
    Map<String, dynamic> invoiceResp = {};
    try {
      invoiceResp = await client.createInvoice(orderId);
    } catch (e) {
      // non-blocking
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice issue: $e')),
        );
      }
    }

    // 8. print invoice if we got invoice_id
    final invoiceId = invoiceResp['invoice_id']?.toString();
    if (invoiceId != null && invoiceId.isNotEmpty) {
      try {
        await client.printInvoice(invoiceId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Print issue: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }

    // 9. pop cash drawer (best-effort)
    try {
      await client.openDrawer(
        tenantId: tenantId,
        branchId: branchId,
      );
    } catch (_) {
      // drawer might not be configured; ignore
    }

    // 10. clear cart
    ref.read(posCartProvider.notifier).clear();

    // 11. success toast
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Paid ₹${amountDue.toStringAsFixed(2)} • '
              'Order $orderNo (${info.channel.name}) ✅',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _startCheckout() async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });

    try {
      final req = await _askCheckoutInfo(widget.cart);
      if (req == null) {
        return; // user cancelled
      }

      await _performCheckout(ref, widget.cart, req);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.cart.lines;
    final total = widget.cart.subTotal;

    return Material(
      elevation: 10,
      color: Colors.brown.shade50,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cart lines list (capped height so it never overgrows)
              if (lines.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 180,
                  ),
                  child: Scrollbar(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: lines.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (context, i) {
                        final ln = lines[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // optional thumbnail (uses item.imageUrl)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: (ln.item.imageUrl != null &&
                                    ln.item.imageUrl!.trim().isNotEmpty)
                                    ? MenuBannerImage(path: ln.item.imageUrl)
                                    : Container(
                                  color: Colors.brown.shade100,
                                  child: const Icon(
                                    Icons.fastfood_outlined,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // name + modifiers + unit price
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ln.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (ln.modifiers.isNotEmpty)
                                    Text(
                                      ln.modifiersSummary,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
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

                            // qty stepper
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon:
                                  const Icon(Icons.remove_circle_outline),
                                  onPressed: _busy
                                      ? null
                                      : () {
                                    ref
                                        .read(
                                        posCartProvider.notifier)
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
                                  onPressed: _busy
                                      ? null
                                      : () {
                                    ref
                                        .read(
                                        posCartProvider.notifier)
                                        .incQty(i);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),

                            // line total + delete button
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹ ${ln.lineTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Remove line',
                                  onPressed: _busy
                                      ? null
                                      : () {
                                    ref
                                        .read(
                                        posCartProvider.notifier)
                                        .removeLine(i);
                                  },
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                )
              else
                const Text(
                  'Cart is empty',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
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
                        child:
                        CircularProgressIndicator(strokeWidth: 2),
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
            ],
          ),
        ),
      ),
    );
  }
}
