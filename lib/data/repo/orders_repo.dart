// lib/data/repos/orders_repo.dart
import 'package:drift/drift.dart' show Value;
import 'package:waah_frontend/data/api_client.dart';
import 'package:waah_frontend/data/local/app_db.dart';
import 'package:waah_frontend/data/models.dart';

class OrdersRepo {
  OrdersRepo(this._db, this._api);
  final AppDatabase _db;
  final ApiClient _api;

  // Local stream (fast)
  Stream<List<OrderRow>> watch(OrderStatus? status) =>
      _db.watchOrders(status: status?.name);

  // Merge a page from server into local cache
  Future<void> refresh({
    OrderStatus? status,
    String? tenantId,
    String? branchId,
    int size = 100,
  }) async {
    final page = await _api.fetchOrders(
      status: status,
      size: size,
      tenantId: tenantId,
      branchId: branchId,
    );

    await _db.transaction(() async {
      for (final o in page.items) {
        final opened = o.openedAt;
        await _db.upsertOrder(OrdersCompanion(
          remoteId: Value(o.id ?? ''),
          orderNo: Value('${o.orderNo ?? ''}'),
          status: Value(o.status.name),
          channel: Value(o.channel.name),
          tableId: Value(o.tableId),
          pax: Value(o.pax),
          note: Value(o.note),
          openedAt: Value(opened?.toLocal()),
          updatedAt: const Value(null),
          // totals untouched here; detail() updates them
        ));
      }
    });
  }

  // Detail with offline fallback:
  // 1) Try network -> upsert totals -> return network data.
  // 2) If offline, synthesize from local row using Order.fromJson (no enum imports needed).
  Future<OrderDetail> detail(
      String orderId, {
        // Optional overrides when offline:
        String? tenantId,
        String? branchId,
        String? sourceDeviceId,
        String? customerId,
        String? openedByUserId,
        String? closedByUserId,
        String providerIfString = 'INHOUSE', // used only if your model expects a String provider
      }) async {
    try {
      final d = await _api.getOrderDetail(orderId);
      final o = d.order;

      // cache totals locally for offline
      await _db.upsertOrder(OrdersCompanion(
        remoteId: Value(o.id ?? orderId),
        orderNo: Value('${o.orderNo ?? ''}'),
        status: Value(o.status.name),
        channel: Value(o.channel.name),
        tableId: Value(o.tableId),
        pax: Value(o.pax),
        note: Value(o.note),
        openedAt: Value(o.openedAt?.toLocal()),
        updatedAt: const Value(null),
        subtotal: Value(d.totals.subtotal),
        tax: Value(d.totals.tax),
        total: Value(d.totals.total),
        paid: Value(d.totals.paid),
        due: Value(d.totals.due),
      ));
      return d;
    } catch (_) {
      // ---- OFFLINE FALLBACK ----
      final row = await _db.findOrderByRid(orderId);
      if (row == null) rethrow;

      // Pull tenant/branch from local settings if not provided
      final settings =
      await _db.select(_db.restaurantSettings).getSingleOrNull();
      final _tenantId = tenantId ?? settings?.tenantId ?? '';
      final _branchId = branchId ?? settings?.branchId ?? '';

      // Safe defaults for required fields
      final _sourceDeviceId = sourceDeviceId ?? 'offline-device';
      final _customerId = customerId ?? 'OFFLINE';
      final _openedByUserId = openedByUserId ?? 'OFFLINE';
      final _closedByUserId = closedByUserId ?? 'OFFLINE';
      final _closedAt = row.updatedAt ?? row.openedAt ?? DateTime.now();

      // Build JSON that matches your Order.fromJson schema.
      // NOTE: status/channel are stored as enum names in DB → pass as strings so fromJson maps correctly.
      final orderJson = <String, dynamic>{
        'id': orderId,
        'tenantId': _tenantId,
        'branchId': _branchId,
        'orderNo': row.orderNo,
        'status': row.status,               // e.g. "open", "closed"
        'channel': row.channel,             // e.g. "dinein", "takeaway", "delivery"
        'provider': providerIfString,       // if your model expects String; if it expects enum, your fromJson will map
        'customerId': _customerId,
        'openedByUserId': _openedByUserId,
        'closedByUserId': _closedByUserId,
        'sourceDeviceId': _sourceDeviceId,
        'closedAt': _closedAt.toIso8601String(),
        // Optional fields:
        'tableId': row.tableId,
        'pax': row.pax,
        'note': row.note,
        'openedAt': row.openedAt?.toIso8601String(),
        'updatedAt': row.updatedAt?.toIso8601String(),
      };

      final order = Order.fromJson(orderJson);

      final totals = OrderTotals(
        subtotal: row.subtotal,
        tax: row.tax,
        total: row.total,
        paid: row.paid,
        due: row.due,
      );

      return OrderDetail(order: order, totals: totals);
    }
  }
}
