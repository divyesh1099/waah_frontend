import 'dart:convert';
import 'dart:convert' as convert;
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'models.dart';

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Unauthorized']);
  @override
  String toString() => 'UnauthorizedException: $message';
}

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => 'ApiException($status): $message';
}

class ApiClient {
  ApiClient(this._dio, {
    required this.baseUrl,
    void Function()? onUnauthorized,
  }) : _onUnauthorized = onUnauthorized {
    // Keep Dio aligned with http.* base and auth for relative calls
    _dio.options.baseUrl = baseUrl;
    if (_token != null && _token!.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $_token';
    }
  }
  final Dio _dio;
  final String baseUrl;
  final void Function()? _onUnauthorized;

  String? _token;

  void setToken(String? t) => _token = t; // kept as-is for backward compatibility
  void updateAuthToken(String? token) {
    _token = token;

    // Keep Dio in sync for endpoints that use Dio directly
    try {
      _dio.options.headers.remove('Authorization');
      if (token != null && token.isNotEmpty) {
        _dio.options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // no-op: very defensive, shouldn't throw
    }
  }

  Map<String, String> _headers([Map<String, String>? extra]) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      if (_token != null && _token!.isNotEmpty)
        'Authorization': 'Bearer $_token',
    };
    if (extra != null) h.addAll(extra);
    return h;
  }

  Uri _u(String path, [Map<String, dynamic>? q]) {
    final uri = Uri.parse(baseUrl + path);
    if (q == null) return uri;
    final filtered = q.map((k, v) => MapEntry(k, v?.toString()));
    return uri.replace(queryParameters: filtered);
  }

  dynamic _decodeOrThrow(http.Response r) {
    final ct = r.headers['content-type'] ?? '';
    final body = ct.startsWith('application/json')
        ? (r.body.isEmpty ? null : json.decode(r.body))
        : r.body;

    if (r.statusCode == 401) {
      _onUnauthorized?.call();
    }

    final ok = r.statusCode >= 200 && r.statusCode < 300;
    if (!ok) {
      String msg;
      if (body is Map && body['detail'] != null) {
        msg = body['detail'].toString();
      } else if (body is Map && body['message'] is String) {
        msg = body['message'] as String;
      } else {
        msg = r.body;
      }
      throw ApiException(msg, r.statusCode);
    }

    return body;
  }

  Future<dynamic> _parse(http.Response r) async {
    final ct = r.headers['content-type'] ?? '';
    final body = ct.startsWith('application/json')
        ? (r.body.isEmpty ? null : json.decode(r.body))
        : r.body;

    if (r.statusCode == 401) {
      _onUnauthorized?.call();
    }

    final ok = r.statusCode >= 200 && r.statusCode < 300;
    if (!ok) {
      throw Exception('HTTP ${r.statusCode}: $body');
    }
    return body;
  }

  Future<dynamic> _get(
      String p, {
        Map<String, dynamic>? params,
        Map<String, String>? headers,
      }) async {
    final r = await http.get(
      _u(p, params),
      headers: _headers(headers),
    );
    return _parse(r);
  }

  Future<dynamic> _post(
      String p, {
        dynamic body,
        Map<String, dynamic>? params,
        Map<String, String>? headers,
      }) async {
    final r = await http.post(
      _u(p, params),
      headers: _headers(headers),
      body: body == null ? null : json.encode(body),
    );
    return _parse(r);
  }

  Future<dynamic> _patch(
      String p, {
        dynamic body,
        Map<String, dynamic>? params,
        Map<String, String>? headers,
      }) async {
    final r = await http.patch(
      _u(p, params),
      headers: _headers(headers),
      body: body == null ? null : json.encode(body),
    );
    return _parse(r);
  }

  Future<void> _delete(
      String p, {
        Map<String, dynamic>? params,
        Map<String, String>? headers,
      }) async {
    final r = await http.delete(
      _u(p, params),
      headers: _headers(headers),
    );
    await _parse(r);
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) {
      final parsed = double.tryParse(v);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  // ---------- Generic list helpers ----------

  Future<List<T>> listAll<T>({
    required String path,
    Map<String, dynamic>? params,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final data = await _get(path, params: params);
    if (data is List) {
      return data
          .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return <T>[];
  }

  Future<PageResult<T>> listPage<T>({
    required String path,
    Map<String, dynamic>? params,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final data = await _get(path, params: params);
    if (data is List) {
      final list = data
          .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return PageResult(items: list, total: list.length);
    }
    if (data is Map) {
      final items = (data['items'] as List? ?? const [])
          .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final total =
      data['total'] is int ? data['total'] as int : items.length;
      return PageResult(items: items, total: total);
    }
    return PageResult(items: <T>[], total: 0);
  }

  Future<T> createOne<T>({
    required String path,
    required dynamic body,
    required T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic>? params,
  }) async {
    final r = await _post(path, body: body, params: params);
    return fromJson(Map<String, dynamic>.from(r as Map));
  }

  Future<T> updateOne<T>({
    required String path,
    required dynamic body,
    required T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic>? params,
  }) async {
    final r = await _patch(path, body: body, params: params);
    return fromJson(Map<String, dynamic>.from(r as Map));
  }

  // ---------- Auth ----------

  Future<String> login({
    required String mobile,
    String? password,   // <- make optional
    String? pin,
  }) async {
    final qp = <String, String>{'mobile': mobile};
    if (password != null && password.isNotEmpty) qp['password'] = password;
    if (pin != null && pin.isNotEmpty) qp['pin'] = pin;

    final uri = Uri.parse('$baseUrl/auth/login').replace(queryParameters: qp);
    final r = await http.post(uri, headers: _headers());
    final data = _decodeOrThrow(r);
    if (data is Map) {
      for (final k in ['access_token','token','jwt','id_token']) {
        final v = data[k];
        if (v is String && v.isNotEmpty) return v;
      }
    }
    throw ApiException('Token not found in login response', r.statusCode);
  }

  Future<dynamic> healthz() => _get('/healthz');

  // ---------- Onboarding ----------

  Future<Map<String, dynamic>> onboardAdmin({
    required String appSecret,
    required String tenantName,
    required String adminName,
    required String mobile,
    String? email,
    required String password,
    required String pin,
  }) async {
    final uri = Uri.parse('$baseUrl/onboard/admin');
    final r = await http.post(
      uri,
      headers: _headers({'X-App-Secret': appSecret}),
      body: jsonEncode({
        'tenant_name': tenantName,
        'admin_name': adminName,
        'mobile': mobile,
        'email': email,
        'password': password,
        'pin': pin,
      }),
    );
    final data = _decodeOrThrow(r);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> onboardBranch({
    required String appSecret,
    required String tenantId,
    required String name,
    required String phone,
    required String gstin,
    required String stateCode,
    required String address,
  }) async {
    final uri = Uri.parse('$baseUrl/onboard/branch');
    final r = await http.post(
      uri,
      headers: _headers({'X-App-Secret': appSecret}),
      body: jsonEncode({
        'tenant_id': tenantId,
        'name': name,
        'phone': phone,
        'gstin': gstin,
        'state_code': stateCode,
        'address': address,
      }),
    );
    final data = _decodeOrThrow(r);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> onboardRestaurant({
    required String appSecret,
    required String tenantId,
    required String branchId,
    required String name,
    required String address,
    required String phone,
    required String gstin,
    required String fssai,
    required bool printFssaiOnInvoice,
    required bool gstInclusiveDefault,
  }) async {
    final uri = Uri.parse('$baseUrl/onboard/restaurant');
    final r = await http.post(
      uri,
      headers: _headers({'X-App-Secret': appSecret}),
      body: jsonEncode({
        'tenant_id': tenantId,
        'branch_id': branchId,
        'name': name,
        'address': address,
        'phone': phone,
        'gstin': gstin,
        'fssai': fssai,
        'print_fssai_on_invoice': printFssaiOnInvoice,
        'gst_inclusive_default': gstInclusiveDefault,
        'service_charge_mode': 'NONE',
        'service_charge_value': 0,
        'packing_charge_mode': 'NONE',
        'packing_charge_value': 0,
        'invoice_footer': 'Thank you!',
      }),
    );
    _decodeOrThrow(r);
  }

  Future<Map<String, dynamic>> onboardPrinters({
    required String appSecret,
    required String tenantId,
    required String branchId,
    required Map<String, dynamic> payload,
  }) async {
    final uri = Uri.parse('$baseUrl/onboard/printers');
    final r = await http.post(
      uri,
      headers: _headers({'X-App-Secret': appSecret}),
      body: jsonEncode({
        'tenant_id': tenantId,
        'branch_id': branchId,
        ...payload,
      }),
    );
    final data = _decodeOrThrow(r);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> onboardFinish({
    required String appSecret,
    required String tenantId,
  }) async {
    final uri = Uri.parse('$baseUrl/onboard/finish');
    final r = await http.post(
      uri,
      headers: _headers({'X-App-Secret': appSecret}),
      body: jsonEncode({'tenant_id': tenantId}),
    );
    _decodeOrThrow(r);
  }

  // ---------- Settings / Printers / Stations ----------

  Future<KitchenStation> createStation(
      KitchenStation s) =>
      createOne<KitchenStation>(
        path: '/settings/stations',
        body: s.toJson(),
        fromJson: KitchenStation.fromJson,
      );

  Future<RestaurantSettings?> getRestaurantSettings({
    required String tenantId,
    required String branchId,
  }) async {
    final r = await _get(
      '/settings/restaurant',
      params: {
        'tenant_id': tenantId,
        'branch_id': branchId,
      },
    );
    if (r == null) return null;
    return RestaurantSettings.fromJson(
      Map<String, dynamic>.from(r as Map),
    );
  }

  // ---------- Menu ----------

  Future<List<MenuCategory>> fetchCategories({
    required String tenantId,
    required String branchId,
  }) {
    return listAll<MenuCategory>(
      path: '/menu/categories',
      params: {
        'tenant_id': tenantId,
        'branch_id': branchId,
      },
      fromJson: MenuCategory.fromJson,
    );
  }

  Future<MenuCategory> createCategory(
      MenuCategory data) =>
      createOne<MenuCategory>(
        path: '/menu/categories',
        body: data.toJson(),
        fromJson: MenuCategory.fromJson,
      );

  Future<MenuCategory> updateCategory(
      String id, MenuCategory data) =>
      updateOne<MenuCategory>(
        path: '/menu/categories/$id',
        body: data.toJson(),
        fromJson: MenuCategory.fromJson,
      );

  Future<List<MenuItem>> fetchItems({
    String? categoryId,
    String? tenantId,
    String? branchId, // NEW
  }) {
    return listAll<MenuItem>(
      path: '/menu/items',
      params: {
        'category_id': categoryId,
        'tenant_id': tenantId,
        'branch_id': branchId, // NEW
      }..removeWhere((k, v) => v == null || (v is String && v.isEmpty)),
      fromJson: MenuItem.fromJson,
    );
  }

  Future<MenuItem> createItem(MenuItem data) =>
      createOne<MenuItem>(
        path: '/menu/items',
        body: data.toJson(),
        fromJson: MenuItem.fromJson,
      );

  Future<void> deleteItem(String id) =>
      _delete('/menu/items/$id');

  Future<void> updateItemTax(
      String itemId, {
        required double gstRate,
        required bool taxInclusive,
      }) async {
    await _post(
      '/menu/items/$itemId/update_tax',
      params: {
        'gst_rate': gstRate,
        'tax_inclusive': taxInclusive,
      },
    );
  }

  // GET /menu/items/{item_id}/modifiers_full
  Future<List<dynamic>> fetchItemModifierGroups(String itemId) async {
    // build URL like: /menu/items/<id>/modifiers_full
    final uri = Uri.parse('$baseUrl/menu/items/$itemId/modifiers_full');

    final res = await http.get(
      uri,
      headers: _headers(), // same auth/json headers you use elsewhere
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'HTTP ${res.statusCode}: ${res.body}',
      );
    }

    final decoded = jsonDecode(res.body);
    // backend returns an array of groups with their modifiers
    if (decoded is List) {
      return decoded;
    }
    return <dynamic>[];
  }

  // (optional future work)
  // POST /orders/{order_id}/items/{order_item_id}/modifiers
  // Future<void> addOrderItemModifiers(String orderId, String orderItemId, List<Modifier> mods)

  Future<List<ItemVariant>> fetchVariants(
      String itemId) {
    return listAll<ItemVariant>(
      path: '/menu/variants',
      params: {'item_id': itemId},
      fromJson: ItemVariant.fromJson,
    );
  }

  Future<ItemVariant> createVariant(
      String itemId,
      ItemVariant data,
      ) {
    return createOne<ItemVariant>(
      path: '/menu/variants',
      body: data.toJson(),
      fromJson: ItemVariant.fromJson,
    );
  }

  Future<ModifierGroup> createModifierGroup(
      ModifierGroup g) =>
      createOne<ModifierGroup>(
        path: '/menu/modifier_groups',
        body: g.toJson(),
        fromJson: ModifierGroup.fromJson,
      );

  Future<Modifier> createModifier(
      Modifier m) =>
      createOne<Modifier>(
        path: '/menu/modifiers',
        body: m.toJson(),
        fromJson: Modifier.fromJson,
      );

  Future<void> linkItemModifierGroup(
      String itemId,
      String groupId,
      ) async {
    await _post(
      '/menu/items/$itemId/modifier_groups',
      body: {'group_id': groupId},
    );
  }

  // ---------- Dining & Customers ----------

  Future<DiningTable> createTable(DiningTable t) =>
      createOne<DiningTable>(
        path: '/dining/tables',
        body: t.toJson(),
        fromJson: DiningTable.fromJson,
      );

  Future<Customer> createCustomer(Customer c) =>
      createOne<Customer>(
        path: '/customers/',
        body: c.toJson(),
        fromJson: Customer.fromJson,
      );

  Future<List<Customer>> listCustomers({
    String? tenantId,
  }) =>
      listAll<Customer>(
        path: '/customers/',
        params: {'tenant_id': tenantId}
          ..removeWhere((k, v) => v == null),
        fromJson: Customer.fromJson,
      );

  // ---------- Orders / Pay / Invoice ----------

  Future<PageResult<Order>> fetchOrders({
    OrderStatus? status,
    int page = 1,
    int size = 20,
    // NEW filters:
    OrderChannel? channel,            // e.g. OrderChannel.ONLINE
    String? tenantId,                 // current tenant
    String? branchId,                 // current branch
    OnlineProvider? provider,         // e.g. OnlineProvider.ZOMATO
  }) {
    final params = <String, dynamic>{
      'status': status?.name,
      'page': page,
      'size': size,
      if (channel != null) 'channel': channel.name,
      if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
      if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
      if (provider != null) 'provider': provider.name,
    };

    return listPage<Order>(
      path: '/orders/',
      params: params..removeWhere((k, v) => v == null),
      fromJson: Order.fromJson,
    );
  }

  Future<OrderDetail> getOrderDetail(String id) async {
    final r = await _get('/orders/$id');
    final map = Map<String, dynamic>.from(r as Map);

    final ord = Order.fromJson(map);

    final t = map['totals'];
    final totals = (t is Map)
        ? OrderTotals(
      subtotal: _toDouble(
        t['subtotal'] ??
            t['sub_total'] ??
            t['subTotal'],
      ),
      tax: _toDouble(
        t['tax'] ??
            t['tax_total'] ??
            t['taxTotal'],
      ),
      total: _toDouble(
        t['total'] ??
            t['grand_total'] ??
            t['grandTotal'],
      ),
      paid: _toDouble(t['paid']),
      due: _toDouble(
        t['due'] ??
            t['total_due'] ??
            t['totalDue'],
      ),
    )
        : OrderTotals(
      subtotal: 0,
      tax: 0,
      total: 0,
      paid: 0,
      due: 0,
    );

    return OrderDetail(order: ord, totals: totals);
  }

  Future<Order> getOrder(String id) async {
    final d = await getOrderDetail(id);
    return d.order;
  }

  // We keep this for other flows that pass a full Order object
  Future<Order> createOrder(Order data) {
    return createOne<Order>(
      path: '/orders/',
      body: data.toJson(),
      fromJson: Order.fromJson,
    );
  }

  Future<Order> patchOrderStatus(
      String id,
      OrderStatus status,
      ) async {
    final r = await _patch(
      '/orders/$id',
      body: {'status': status.name},
    );
    return Order.fromJson(
      Map<String, dynamic>.from(r as Map),
    );
  }

  Future<Map<String, dynamic>> addOrderItem(
      String orderId,
      OrderItem line, {
        List<OrderItemModifier>? modifiers,
      }) async {
    final body = line.toJson();
    if (modifiers != null && modifiers.isNotEmpty) {
      body['modifiers'] =
          modifiers.map((m) => m.toJson()).toList();
    }
    final r = await _post(
      '/orders/$orderId/items',
      body: body,
    );
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> deleteOrderLine(
      String orderId,
      String lineId, {
        String? reason,
      }) async {
    await _delete(
      '/orders/$orderId/items/$lineId',
      params: {'reason': reason},
    );
  }

  Future<void> applyLineDiscount(
      String orderId,
      String lineId,
      double discount,
      String reason,
      ) async {
    await _post(
      '/orders/$orderId/items/$lineId/apply_discount',
      body: {
        'discount': discount,
        'reason': reason,
      },
    );
  }

  Future<void> pay(
      String orderId,
      PayMode mode,
      double amount, {
        String? refNo,
      }) async {
    await _post(
      '/orders/$orderId/pay',
      body: {
        'order_id': orderId,
        'mode': mode.name,
        'amount': amount,
        'ref_no': refNo,
      },
    );
  }

  Future<Map<String, dynamic>> createInvoice(
      String orderId) async {
    final r = await _post('/orders/$orderId/invoice');
    return Map<String, dynamic>.from(r as Map);
  }

  // ---- NEW POS HELPERS (moved inside the class) ----
  // These are the primitive building blocks Checkout will call.

  Future<Map<String, dynamic>> openOrderOffline({
    required String tenantId,
    required String branchId,
    required String orderNo,
    required String channel, // "DINE_IN", etc.
    int? pax,
    String? tableId,
    String? customerId,
    String? note,
  }) async {
    final body = {
      'tenant_id': tenantId,
      'branch_id': branchId,
      'order_no': orderNo,
      'channel': channel,
      if (pax != null) 'pax': pax,
      if (tableId != null) 'table_id': tableId,
      if (customerId != null) 'customer_id': customerId,
      if (note != null) 'note': note,
    };
    final resp = await _post('/orders/', body: body);
    return Map<String, dynamic>.from(resp as Map);
  }

  Future<void> addItemToOrderPrimitive({
    required String orderId,
    required String itemId,
    String? variantId,
    required double qty,
    required double unitPrice,
  }) async {
    final body = {
      'order_id': orderId,
      'item_id': itemId,
      'variant_id': variantId,
      'qty': qty,
      'unit_price': unitPrice,
    };
    await _post('/orders/$orderId/items', body: body);
  }

  Future<void> payOrderPrimitive({
    required String orderId,
    required double amount,
    String mode = 'CASH',
    String? refNo,
  }) async {
    final body = {
      'order_id': orderId,
      'mode': mode,
      'amount': amount,
      'ref_no': refNo,
    };
    await _post('/orders/$orderId/pay', body: body);
  }

  Future<void> invoiceOrderPrimitive(String orderId) async {
    await _post('/orders/$orderId/invoice', body: {});
  }

  // ---------- Print / Drawer ----------


  Future<void> printInvoice(
      String invoiceId, {
        String? reason,
        String? tenantId,
        String? branchId,
        String? printerId,
      }) async {
    await _post(
      '/print/invoice/$invoiceId',
      params: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
        if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
        if (printerId != null && printerId.isNotEmpty) 'printer_id': printerId,
      },
    );
  }

  Future<void> printBill(
      String orderId, {
        String? reason,
        String? tenantId,
        String? branchId,
        String? printerId,
      }) async {
    await _post(
      '/print/bill/$orderId',
      params: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
        if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
        if (printerId != null && printerId.isNotEmpty) 'printer_id': printerId,
      },
    );
  }

  // ---------- Inventory ----------

  Future<Ingredient> createIngredient(Ingredient i) =>
      createOne<Ingredient>(
        path: '/inventory/ingredients',
        body: i.toJson(),
        fromJson: Ingredient.fromJson,
      );

  Future<void> createPurchase({
    required String tenantId,
    required String supplier,
    String? note,
    required List<Map<String, dynamic>> lines,
  }) async {
    await _post('/inventory/purchase', body: {
      'tenant_id': tenantId,
      'supplier': supplier,
      'note': note,
      'lines': lines,
    }..removeWhere((k, v) => v == null));
  }

  Future<void> setRecipe({
    required String itemId,
    required List<Map<String, dynamic>> lines,
  }) async {
    await _post('/inventory/recipe',
        body: {'item_id': itemId, 'lines': lines});
  }

  Future<List<Map<String, dynamic>>> lowStock() async {
    final r = await _get('/inventory/low_stock');
    if (r is List) {
      return List<Map<String, dynamic>>.from(
        r.map(
              (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
    }
    return <Map<String, dynamic>>[];
  }

  // ---------- Reports / Backup ----------

  Future<void> refreshDailySales({
    required String day,
    required String branchId,
  }) async {
    await _post(
      '/reports/daily_sales/refresh',
      params: {
        'day': day,
        'branch_id': branchId,
      },
    );
  }

  Future<void> refreshStockSnapshot({
    required String day,
  }) async {
    await _post(
      '/reports/stock_snapshot/refresh',
      params: {'day': day},
    );
  }

  Future<BackupConfig> createBackupConfig(
      BackupConfig cfg) =>
      createOne<BackupConfig>(
        path: '/backup/config',
        body: cfg.toJson(),
        fromJson: (j) => BackupConfig.fromJson(j),
      );

  Future<void> createBackupRun({
    required String configId,
    required bool ok,
    required int bytesTotal,
    required String location,
  }) async {
    await _post(
      '/backup/run',
      params: {
        'config_id': configId,
        'ok': ok,
        'bytes_total': bytesTotal,
        'location': location,
      },
    );
  }

  Future<List<Map<String, dynamic>>> listBackupRuns({
    required String configId,
  }) async {
    final r = await _get(
      '/backup/runs',
      params: {'config_id': configId},
    );
    if (r is List) {
      return List<Map<String, dynamic>>.from(
        r.map(
              (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
    }
    return <Map<String, dynamic>>[];
  }

  // ---------- Auth / Me ----------

  Future<MeInfo> fetchMe() async {
    // GET /auth/me
    final r = await _get('/auth/me');
    final map = Map<String, dynamic>.from(r as Map);
    return MeInfo.fromJson(map);
  }

  // ---------- Users / Roles / Permissions ----------

  /// List all users in this tenant (id, name, mobile, active, roles[])
  Future<List<UserSummary>> listUsers({String? tenantId}) async {
    final r = await _get(
      '/users/',
      params: {
        if (tenantId != null && tenantId.isNotEmpty)
          'tenant_id': tenantId,
      },
    );

    if (r is List) {
      return r
          .map(
            (row) => UserSummary.fromJson(
          Map<String, dynamic>.from(row as Map),
        ),
      )
          .toList();
    }

    return <UserSummary>[];
  }

  /// Create a user (optionally with password, pin, and initial roles).
  /// Returns new user id.
  Future<String> createUser({
    required String tenantId,
    required String name,
    String? mobile,
    String? email,
    String? password,
    String? pin,
    List<String>? roles,
  }) async {
    final body = <String, dynamic>{
      'tenant_id': tenantId,
      'name': name,
      if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
      if (email != null && email.isNotEmpty) 'email': email,
      if (password != null && password.isNotEmpty) 'password': password,
      if (pin != null && pin.isNotEmpty) 'pin': pin,
      if (roles != null && roles.isNotEmpty) 'roles': roles,
    };

    final resp = await _post('/users/', body: body);
    final map = Map<String, dynamic>.from(resp as Map);
    return map['id']?.toString() ?? '';
  }

  /// Optional helper if you later want to rename / deactivate a user
  Future<void> updateUserBasic(
      String userId, {
        String? name,
        String? mobile,
        String? email,
        bool? active,
      }) async {
    await _patch(
      '/users/$userId',
      body: {
        if (name != null) 'name': name,
        if (mobile != null) 'mobile': mobile,
        if (email != null) 'email': email,
        if (active != null) 'active': active,
      },
    );
  }

  /// Give this user 1+ role codes (["CASHIER","WAITER"])
  Future<void> assignUserRoles(
      String userId,
      List<String> roles,
      ) async {
    await _post(
      '/users/$userId/roles',
      body: {
        'roles': roles,
      },
    );
  }

  /// Remove a role code from a user
  Future<void> removeUserRole(String userId, String roleCode) async {
    await _delete('/users/$userId/roles/$roleCode');
  }

  // ---------- Sync ----------

  Future<Map<String, dynamic>> syncPush({
    required String deviceId,
    required List<Map<String, dynamic>> ops,
  }) async {
    final r = await _post(
      '/sync/push',
      body: {'device_id': deviceId, 'ops': ops},
    );
    if (r is Map<String, dynamic>) return r;
    if (r is Map) return Map<String, dynamic>.from(r);
    return const <String, dynamic>{}; // fallback if server returns nothing
  }

  Future<Map<String, dynamic>> syncPull({
    required int since,
    required int limit,
  }) async {
    final r = await _get(
      '/sync/pull',
      params: {
        'since': since,
        'limit': limit,
      },
    );
    return Map<String, dynamic>.from(r as Map);
  }

  /// Get dining tables for a branch.
  /// Frontend currently calls with branchId: ''.
  ///
  /// Backend: GET /dining/tables?branch_id=<branchId>
  /// Response: [
  ///   {
  ///     "id": "...",
  ///     "branch_id": "...",
  ///     "code": "T1",
  ///     "zone": "Patio",
  ///     "seats": 4
  ///   },
  ///   ...
  /// ]
  Future<List<DiningTable>> fetchDiningTables({
    required String branchId,
  }) async {
    final resp = await _dio.get(
      '/dining/tables',
      queryParameters: {
        'branch_id': branchId,
      },
    );

    final data = resp.data;
    final out = <DiningTable>[];

    if (data is List) {
      for (final row in data) {
        if (row is Map<String, dynamic>) {
          out.add(DiningTable.fromJson(row));
        } else {
          out.add(
            DiningTable.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          );
        }
      }
    }

    // stable sort by table code so UI looks nice
    out.sort(
          (a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()),
    );

    return out;
  }

  // GET /settings/restaurant?tenant_id=...&branch_id=...
  Future<Map<String, dynamic>> fetchRestaurantSettings({
    required String tenantId,
    required String branchId,
  }) async {
    final r = await _get(
      '/settings/restaurant',
      params: {
        'tenant_id': tenantId,
        'branch_id': branchId,
      },
    );
    if (r == null) return {};
    return Map<String, dynamic>.from(r as Map);
  }

  // POST /settings/restaurant  (upsert)
  Future<void> saveRestaurantSettings(Map<String, dynamic> body) async {
    await _post('/settings/restaurant', body: body);
  }

  // POST /settings/printers
  Future<String> createPrinter({
    required String tenantId,
    required String branchId,
    required String name,
    required String type,          // "BILLING" or "KITCHEN"
    required String connectionUrl, // e.g. http://192.168.0.50:9100/print
    bool cashDrawerEnabled = false,
    String? cashDrawerCode,
  }) async {
    final r = await _post(
      '/settings/printers',
      body: {
        'tenant_id': tenantId,
        'branch_id': branchId,
        'name': name,
        'type': type,
        'connection_url': connectionUrl,
        'is_default': type == 'BILLING', // first billing printer? feel free
        'cash_drawer_enabled': cashDrawerEnabled,
        'cash_drawer_code': cashDrawerCode,
      }..removeWhere((k, v) => v == null),
    );
    final map = Map<String, dynamic>.from(r as Map);
    return map['id'] as String;
  }

  // PATCH /settings/printers/{printer_id}
  Future<void> updatePrinter(
      String printerId, {
        String? name,
        String? connectionUrl,
        bool? isDefault,
        String? type,
        bool? cashDrawerEnabled,
        String? cashDrawerCode,
      }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (connectionUrl != null) 'connection_url': connectionUrl,
      if (isDefault != null) 'is_default': isDefault,
      if (type != null) 'type': type,
      if (cashDrawerEnabled != null)
        'cash_drawer_enabled': cashDrawerEnabled,
      if (cashDrawerCode != null) 'cash_drawer_code': cashDrawerCode,
    };
    await _patch('/settings/printers/$printerId', body: body);
  }

  Future<void> openDrawer({
    String? tenantId,
    String? branchId,
  }) async {
    await _post(
      '/print/open_drawer',
      params: {
        if (tenantId != null) 'tenant_id': tenantId,
        if (branchId != null) 'branch_id': branchId,
      },
    );
  }

  /// Print a GST invoice for an already-created invoice record.
  /// POST /print/invoice/{invoice_id}
  Future<void> printInvoiceById(String invoiceId, {String? reason, String? tenantId, String? branchId, String? printerId}) async {
    await _post(
      '/print/invoice/$invoiceId',
      params: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
        if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
        if (printerId != null && printerId.isNotEmpty) 'printer_id': printerId,
      },
    );
  }

  // ---------- KOT (Kitchen) ----------

  Future<List<KitchenTicket>> fetchKitchenTickets({
    KOTStatus? status,
    String? tenantId,
    String? branchId,
  }) {
    final params = <String, dynamic>{
      'status': status?.name,
    };

    // only include if it's a real value
    if (tenantId != null && tenantId.trim().isNotEmpty) {
      params['tenant_id'] = tenantId.trim();
    }
    if (branchId != null && branchId.trim().isNotEmpty) {
      params['branch_id'] = branchId.trim();
    }

    return listAll<KitchenTicket>(
      path: '/kot/tickets',
      params: params,
      fromJson: KitchenTicket.fromJson,
    );
  }

  Future<Map<String, dynamic>> createKitchenTicket({
    required String orderId,
    required int ticketNo,
    String? targetStation, // pass null to include ALL items regardless of station
  }) async {
    final params = <String, dynamic>{
      'order_id': orderId,
      'ticket_no': ticketNo,
      if (targetStation != null && targetStation.isNotEmpty)
        'target_station': targetStation,
    };

    final r = await _post(
      '/kot/tickets',
      params: params,
    );

    return Map<String, dynamic>.from(r as Map);
  }

  /// Convenience: generate a ticket number, call /kot/tickets,
  /// and mark the order as in-kitchen (optional last step below).
  Future<void> fireKotForOrder({
    required String orderId,
    String? stationId, // pass null to send all items in one ticket
  }) async {
    // ticket_no is required by backend right now.
    // We'll just use epoch seconds, which is monotonic enough for dev.
    final ticketNo = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await createKitchenTicket(
      orderId: orderId,
      ticketNo: ticketNo,
      targetStation: stationId,
    );

    // OPTIONAL BUT NICE:
    // flip the order status to KITCHEN so POS UI shows "sent"
    try {
      await patchOrderStatus(orderId, OrderStatus.KITCHEN);
    } catch (_) {
      // don't block KOT if this fails
    }
  }


  Future<void> reprintKitchenTicket(
      String ticketId, {
        String? reason,
        String? tenantId,
        String? branchId,
      }) async {
    await _post(
      '/kot/$ticketId/reprint',
      params: {
        if (reason != null) 'reason': reason,
        if (tenantId != null) 'tenant_id': tenantId,
        if (branchId != null) 'branch_id': branchId,
      }..removeWhere((k, v) => v == null),
    );
  }

  Future<void> cancelKitchenTicket(
      String ticketId, {
        String? reason,
        String? tenantId,
        String? branchId,
      }) async {
    await _post(
      '/kot/$ticketId/cancel',
      params: {
        if (reason != null) 'reason': reason,
        if (tenantId != null) 'tenant_id': tenantId,
        if (branchId != null) 'branch_id': branchId,
      }..removeWhere((k, v) => v == null),
    );
  }

  Future<void> patchKitchenTicketStatus(
      String id,
      KOTStatus status, {
        String? tenantId,
        String? branchId,
      }) async {
    await _patch(
      '/kot/$id',
      body: {
        'status': status.name,
        if (tenantId != null) 'tenant_id': tenantId,
        if (branchId != null) 'branch_id': branchId,
      }..removeWhere((k, v) => v == null),
    );
  }

  // ---------- Menu (extra helpers we now support) ----------

  Future<MenuCategory> patchCategory(String id, MenuCategory data) async {
    final r = await _patch(
      '/menu/categories/$id',
      body: data.toJson(),
    );
    return MenuCategory.fromJson(Map<String, dynamic>.from(r as Map));
  }

  Future<void> deleteCategory(String id) async {
    await _delete('/menu/categories/$id');
  }

  Future<MenuItem> updateItem(String id, MenuItem data) async {
    final r = await _patch(
      '/menu/items/$id',
      body: data.toJson(),
    );
    return MenuItem.fromJson(Map<String, dynamic>.from(r as Map));
  }

  // variants update/delete
  Future<ItemVariant> updateVariant(
      String variantId,
      ItemVariant data,
      ) async {
    final r = await _patch(
      '/menu/variants/$variantId',
      body: data.toJson(),
    );
    return ItemVariant.fromJson(Map<String, dynamic>.from(r as Map));
  }

  Future<void> deleteVariant(String variantId) async {
    await _delete('/menu/variants/$variantId');
  }

  // ---------- Inventory ----------

  Future<List<Ingredient>> fetchIngredients({
    String? tenantId,
  }) {
    return listAll<Ingredient>(
      path: '/inventory/ingredients',
      params: {
        'tenant_id': tenantId,
      }..removeWhere((k, v) => v == null),
      fromJson: Ingredient.fromJson,
    );
  }

  Future<Ingredient> updateIngredient(
      String ingredientId, {
        String? name,
        String? uom,
        double? minLevel,
      }) async {
    final r = await _patch(
      '/inventory/ingredients/$ingredientId',
      body: {
        if (name != null) 'name': name,
        if (uom != null) 'uom': uom,
        if (minLevel != null) 'min_level': minLevel,
      },
    );
    return Ingredient.fromJson(Map<String, dynamic>.from(r as Map));
  }

  // ---------- Identity / Branches ----------

  Future<List<BranchInfo>> fetchBranches({String? tenantId}) async {
    final r = await _get(
      '/identity/branches',
      params: {
        if (tenantId != null && tenantId.isNotEmpty)
          'tenant_id': tenantId,
      },
    );

    if (r is List) {
      return r
          .map((row) => BranchInfo.fromJson(
        Map<String, dynamic>.from(row as Map),
      ))
          .toList();
    }
    return <BranchInfo>[];
  }

  Future<String> createBranch({
    required String tenantId,
    required String name,
    String? phone,
    String? gstin,
    String? stateCode,
    String? address,
  }) async {
    final resp = await _post(
      '/identity/branches',
      body: {
        'tenant_id': tenantId,
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (gstin != null && gstin.isNotEmpty) 'gstin': gstin,
        if (stateCode != null && stateCode.isNotEmpty)
          'state_code': stateCode,
        if (address != null && address.isNotEmpty) 'address': address,
      },
    );

    final map = Map<String, dynamic>.from(resp as Map);
    return map['id']?.toString() ?? '';
  }

  // ---------- Shift ----------

  // GET /shift/status?branch_id=...
  Future<ShiftStatus?> fetchCurrentShift({
    required String branchId,
  }) async {
    final r = await _get(
      '/shift/status',
      params: {'branch_id': branchId},
    );

    if (r is Map && r.isNotEmpty && r['id'] != null) {
      return ShiftStatus.fromJson(
        Map<String, dynamic>.from(r),
      );
    }
    return null;
  }

  // POST /shift/open?branch_id=...&opening_float=...
  Future<void> openShift({
    required String branchId,
    required double openingFloat,
  }) async {
    await _post(
      '/shift/open',
      params: {
        'branch_id': branchId,
        'opening_float': openingFloat,
      },
    );
  }

  // POST /shift/{shift_id}/payin?amount=..&reason=..
  Future<void> cashIn({
    required String shiftId,
    required double amount,
    String? reason,
  }) async {
    await _post(
      '/shift/$shiftId/payin',
      params: {
        'amount': amount,
        if (reason != null) 'reason': reason,
      },
    );
  }

  // POST /shift/{shift_id}/payout?amount=..&reason=..
  Future<void> cashOut({
    required String shiftId,
    required double amount,
    String? reason,
  }) async {
    await _post(
      '/shift/$shiftId/payout',
      params: {
        'amount': amount,
        if (reason != null) 'reason': reason,
      },
    );
  }

  // POST /shift/{shift_id}/close?expected_cash=..&actual_cash=..&note=..
  Future<Map<String, dynamic>> closeShift({
    required String shiftId,
    required double expectedCash,
    required double actualCash,
    String? note,
  }) async {
    final r = await _post(
      '/shift/$shiftId/close',
      params: {
        'expected_cash': expectedCash,
        'actual_cash': actualCash,
        if (note != null) 'note': note,
      },
    );
    return Map<String, dynamic>.from(r as Map);
  }

  // ApiClient.dart  (add this)
  Future<List<Map<String, dynamic>>> listPrinters({
    required String tenantId,
    required String branchId,
  }) async {
    final r = await _get(
      '/settings/printers',
      params: {
        'tenant_id': tenantId,
        'branch_id': branchId,
      },
    );

    List<Map<String, dynamic>> asList(dynamic x) {
      if (x is List) {
        return x.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (x is Map && x['items'] is List) {
        return (x['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return <Map<String, dynamic>>[];
    }

    return asList(r);
  }

  Future<List<Map<String, dynamic>>> listStations({
    required String tenantId,
    required String branchId,
  }) async {
    final r = await _get('/settings/stations', params: {
      'tenant_id': tenantId,
      'branch_id': branchId,
    });

    if (r is List) {
      return List<Map<String, dynamic>>.from(
        r.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
    return <Map<String, dynamic>>[];
  }

  // ---------- Roles -------------------------------------------------------

  /// List roles in a tenant.
  /// Each role includes id, code, and a `permissions` list (may be empty).
  Future<List<RoleInfo>> listRoles({String? tenantId}) async {
    final r = await _get(
      '/users/roles',
      params: {
        if (tenantId != null && tenantId.isNotEmpty)
          'tenant_id': tenantId,
      },
    );

    if (r is List) {
      return r
          .map(
            (row) => RoleInfo.fromListJson(
          Map<String, dynamic>.from(row as Map),
        ),
      )
          .toList();
    }
    return <RoleInfo>[];
  }

  /// Create a new role code in this tenant.
  /// Returns the new role ID.
  Future<String> createRole({
    required String tenantId,
    required String code,
  }) async {
    final resp = await _post(
      '/users/roles',
      body: {
        'tenant_id': tenantId,
        'code': code,
      },
    );
    final map = Map<String, dynamic>.from(resp as Map);
    return map['id']?.toString() ?? '';
  }

  /// Fetch 1 role including its granted permissions[].
  /// Used in RoleDetailPage.
  Future<RoleInfo> fetchRole(String roleId) async {
    final r = await _get('/users/roles/$roleId');
    return RoleInfo.fromJson(Map<String, dynamic>.from(r as Map));
  }

  /// Grant 1+ permissions to a role.
  /// POST /users/roles/{role_id}/grant  { "permissions": ["SETTINGS_EDIT","..."] }
  Future<void> grantRolePermissions(
      String roleId,
      List<String> permissions,
      ) async {
    await _post(
      '/users/roles/$roleId/grant',
      body: {'permissions': permissions},
    );
  }

  /// Revoke a specific permission from a role.
  /// DELETE /users/roles/{role_id}/revoke/{perm_code}
  Future<void> revokeRolePermission(String roleId, String permCode) async {
    await _delete('/users/roles/$roleId/revoke/$permCode');
  }

  // ---------- Permissions --------------------------------------------------

  /// List all possible permissions system-wide.
  /// Each PermissionInfo has `code` and maybe `description`.
  Future<List<PermissionInfo>> listPermissions() async {
    final r = await _get('/users/permissions');
    if (r is List) {
      return r
          .map(
            (row) => PermissionInfo.fromJson(
          Map<String, dynamic>.from(row as Map),
        ),
      )
          .toList();
    }
    return <PermissionInfo>[];
  }
  /// Upload restaurant logo image and get back a public URL.
  /// - tenantId / branchId go as normal form fields
  /// - file goes as multipart
  /// - backend returns { "logo_url": "/media/..." }
  ///
  /// `bytes`: file bytes (e.g. pickedFile.readAsBytes())
  /// `filename`: something like "logo.png" or "logo.jpg"
  /// `contentType`: mime string like "image/png" or "image/jpeg"
  ///
  Future<String> uploadRestaurantLogo({
    required String tenantId,
    required String branchId,
    required List<int> bytes,
    required String filename,
    required String contentType, // make this required so backend validation passes
  }) async {
    // Build a MediaType ("image", "png") from "image/png"
    final mediaType = MediaType.parse(contentType);

    final formData = FormData.fromMap({
      'tenant_id': tenantId,
      'branch_id': branchId,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: mediaType,
      ),
    });

    final resp = await _dio.post(
      '/settings/restaurant/logo',
      data: formData,
      options: Options(
        headers: {
          // Dio will add the proper multipart boundary.
          'Content-Type': 'multipart/form-data',
          if (_token != null && _token!.isNotEmpty)
            'Authorization': 'Bearer $_token',
        },
      ),
    );

    final data = resp.data;
    if (data is Map && data['logo_url'] is String) {
      return data['logo_url'] as String;
    }

    throw ApiException(
      'uploadRestaurantLogo: unexpected response',
      resp.statusCode,
    );
  }

  // ===== Menu Item image =====
  Future<String> uploadItemImage({
    required String itemId,
    required List<int> bytes,
    required String filename,
    required String contentType, // e.g. "image/png"
  }) async {
    final mediaType = MediaType.parse(contentType);
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: mediaType),
    });

    final resp = await _dio.post(
      '/menu/items/$itemId/image',
      data: formData,
      options: Options(headers: {
        'Content-Type': 'multipart/form-data',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      }),
    );

    final data = resp.data;
    if (data is Map && data['image_url'] is String) {
      return data['image_url'] as String;
    }
    throw ApiException('uploadItemImage: unexpected response', resp.statusCode);
  }

  Future<void> deleteItemImage(String itemId) async {
    await _delete('/menu/items/$itemId/image');
  }

  // ===== Item Variant image =====
  Future<String> uploadVariantImage({
    required String variantId,
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final mediaType = MediaType.parse(contentType);
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: mediaType),
    });

    final resp = await _dio.post(
      '/menu/variants/$variantId/image',
      data: formData,
      options: Options(headers: {
        'Content-Type': 'multipart/form-data',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      }),
    );

    final data = resp.data;
    if (data is Map && data['image_url'] is String) {
      return data['image_url'] as String;
    }
    throw ApiException('uploadVariantImage: unexpected response', resp.statusCode);
  }

  Future<void> deleteVariantImage(String variantId) async {
    await _delete('/menu/variants/$variantId/image');
  }

  // ===== Ingredient image =====
  Future<String> uploadIngredientImage({
    required String ingredientId,
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final mediaType = MediaType.parse(contentType);
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: mediaType),
    });

    final resp = await _dio.post(
      '/inventory/ingredients/$ingredientId/image',
      data: formData,
      options: Options(headers: {
        'Content-Type': 'multipart/form-data',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      }),
    );

    final data = resp.data;
    if (data is Map && data['image_url'] is String) {
      return data['image_url'] as String;
    }
    throw ApiException('uploadIngredientImage: unexpected response', resp.statusCode);
  }

  Future<void> deleteIngredientImage(String ingredientId) async {
    await _delete('/inventory/ingredients/$ingredientId/image');
  }

  String _guessExt(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.gif')) return 'gif';
    if (lower.endsWith('.webp')) return 'webp';
    // default
    return 'jpeg';
  }

  /// Upload an image file to the backend.
  /// Returns the server path (e.g. "/media/items/xyz.jpg").
  Future<String> uploadMedia(PlatformFile file) async {
    // Build the MultipartFile:
    MultipartFile multipart;
    if (file.bytes != null) {
      // Works for Web and Desktop (bytes in memory)
      multipart = MultipartFile.fromBytes(
        file.bytes!,
        filename: file.name,
        contentType: MediaType('image', _guessExt(file.name)),
      );
    } else if (file.path != null) {
      // Works for mobile/desktop (has a temp path on disk)
      multipart = await MultipartFile.fromFile(
        file.path!,
        filename: file.name,
        contentType: MediaType('image', _guessExt(file.name)),
      );
    } else {
      throw Exception('No bytes/path for picked file');
    }

    final form = FormData.fromMap({
      'file': multipart, // <- match your backend field name
    });

    final resp = await _dio.post(
      '/media/upload',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    // Expecting { "path": "/media/items/abc.jpg" }
    final data = resp.data;
    if (data is Map && data['path'] is String) {
      return data['path'] as String;
    }
    throw Exception('Upload did not return a "path" field');
  }
  // --- Branch update/delete ---
  Future<void> updateBranch(String id, Map<String, dynamic> body) async {
    await _patch('/identity/branches/$id', body: body);
  }
  Future<void> deleteBranch(String id) async {
    await _delete('/identity/branches/$id');
  }

// --- DiningTable update/delete ---
  Future<void> updateTable(String id, Map<String, dynamic> body) async {
    await _patch('/dining/tables/$id', body: body);
  }
  Future<void> deleteTable(String id) async {
    await _delete('/dining/tables/$id');
  }

// --- Printer delete ---
  Future<void> deletePrinter(String id) async {
    await _delete('/settings/printers/$id');
  }


  Future<void> printKot({required String orderId, String? stationId, String? printerId}) async {
    final data = {
      'order_id': orderId,
      if (stationId != null) 'station_id': stationId,
      if (printerId != null) 'printer_id': printerId,
    };
    await _dio.post('/kot/print', data: data);
  }

// (Optional) simple test endpoint for PrinterSettings
  Future<void> testPrinter(String printerId) async {
    final uri = Uri.parse('$baseUrl/print/test').replace(queryParameters: {
      'printer_id': printerId,
    });
    final r = await http.post(uri, headers: _headers());
    _decodeOrThrow(r); // throws ApiException with parsed message if non-2xx
  }

  // --- In ApiClient class (near other helpers) ---
  Future<String?> resolveDefaultBillingPrinterId({
    required String tenantId,
    required String branchId,
  }) async {
    final list = await listPrinters(tenantId: tenantId, branchId: branchId);

    String? pickId(Map<String, dynamic> p) =>
        (p['id'] is String) ? p['id'] as String
            : p['id']?.toString();

    // 1) Explicit default BILLING
    for (final p in list) {
      final type = (p['type'] ?? '').toString().toUpperCase();
      if (type == 'BILLING' && p['is_default'] == true) return pickId(p);
    }
    // 2) Any BILLING
    for (final p in list) {
      final type = (p['type'] ?? '').toString().toUpperCase();
      if (type == 'BILLING') return pickId(p);
    }
    // 3) Single printer fallback
    if (list.length == 1) return pickId(list.first);

    return null; // nothing suitable
  }

  // --- Helper: first non-empty value among keys in a Map ---
  String? _firstNonEmptyStr(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  /// Resolve default billing printer from (in order):
  /// 1) Restaurant settings (billing_printer_id, billingPrinterId, default_billing_printer_id)
  /// 2) Any printer marked is_default and type=BILLING
  /// 3) Any BILLING printer
  /// 4) If only one printer exists, use that
  Future<String?> _resolveBillingPrinterIdFromBranch({
    required String tenantId,
    required String branchId,
  }) async {
    // Try settings map (lightweight)
    try {
      final rs = await fetchRestaurantSettings(tenantId: tenantId, branchId: branchId);
      if (rs.isNotEmpty) {
        final pid = _firstNonEmptyStr(rs, [
          'billing_printer_id',
          'billingPrinterId',
          'default_billing_printer_id',
        ]);
        if (pid != null) return pid;
      }
    } catch (_) {
      // ignore
    }

    // Try explicit default / any BILLING / single printer
    final list = await listPrinters(tenantId: tenantId, branchId: branchId);

    String? pickId(Map<String, dynamic> p) {
      final x = p['id'];
      return (x is String) ? x : x?.toString();
    }

    for (final p in list) {
      final isBilling = (p['type'] ?? '').toString().toUpperCase() == 'BILLING';
      if (isBilling && p['is_default'] == true) return pickId(p);
    }
    for (final p in list) {
      final isBilling = (p['type'] ?? '').toString().toUpperCase() == 'BILLING';
      if (isBilling) return pickId(p);
    }
    if (list.length == 1) return pickId(list.first);
    return null;
  }

  /// Smart Bill print (resolves printer if caller doesn't pass one)
  Future<void> printBillSmart({
    required String tenantId,
    required String branchId,
    required String orderId,
    String? printerId,
    String? reason,
  }) async {
    var pid = (printerId ?? '').trim();
    if (pid.isEmpty) {
      pid = await _resolveBillingPrinterIdFromBranch(tenantId: tenantId, branchId: branchId) ?? '';
    }
    if (pid.isEmpty) {
      throw ApiException('No default billing printer configured for this branch');
    }
    await printBill(
      orderId,
      reason: reason,
      tenantId: tenantId,
      branchId: branchId,
      printerId: pid,
    );
  }

  /// Smart Invoice print (resolves printer if caller doesn't pass one)
  Future<void> printInvoiceSmart({
    required String tenantId,
    required String branchId,
    required String invoiceId,
    String? printerId,
    String? reason,
  }) async {
    var pid = (printerId ?? '').trim();
    if (pid.isEmpty) {
      pid = await _resolveBillingPrinterIdFromBranch(tenantId: tenantId, branchId: branchId) ?? '';
    }
    if (pid.isEmpty) {
      throw ApiException('No default billing printer configured for this branch');
    }
    await printInvoice(
      invoiceId,
      reason: reason,
      tenantId: tenantId,
      branchId: branchId,
      printerId: pid,
    );
  }

}
