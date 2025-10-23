// lib/data/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiClient {
  ApiClient({required this.baseUrl});
  final String baseUrl;
  String? _token;

  void setToken(String? t) => _token = t;
  // Call this from providers.dart to refresh the bearer token
  void updateAuthToken(String? token) {
    _token = token;
  }
  // Merge Authorization + any extras
  Map<String, String> _headers([Map<String, String>? extra]) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
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

  // Decode + error handling for raw http calls (useful for endpoints
  // that don't fit your existing generic helpers)
  dynamic _decodeOrThrow(http.Response r) {
    final ok = r.statusCode >= 200 && r.statusCode < 300;
    final ct = r.headers['content-type'] ?? '';
    final body = ct.startsWith('application/json')
        ? json.decode(r.body)
        : r.body;
    if (!ok) {
      throw ApiException(
        body is Map && body['message'] is String ? body['message'] : r.body,
        r.statusCode,
      );
    }
    return body;
  }

  Future<dynamic> _parse(http.Response r) async {
    final ct = r.headers['content-type'] ?? '';
    final ok = r.statusCode >= 200 && r.statusCode < 300;
    final body = ct.startsWith('application/json')
        ? (r.body.isEmpty ? null : json.decode(r.body))
        : r.body;
    if (!ok) {
      throw Exception('HTTP ${r.statusCode}: $body');
    }
    return body;
  }

  Future<dynamic> _get(String p, {Map<String, dynamic>? params, Map<String, String>? headers}) async {
    final r = await http.get(_u(p, params), headers: _headers(headers));
    return _parse(r);
  }

  Future<dynamic> _post(String p, {dynamic body, Map<String, dynamic>? params, Map<String, String>? headers}) async {
    final r = await http.post(_u(p, params), headers: _headers(headers), body: body == null ? null : json.encode(body));
    return _parse(r);
  }

  Future<dynamic> _patch(String p, {dynamic body, Map<String, dynamic>? params, Map<String, String>? headers}) async {
    final r = await http.patch(_u(p, params), headers: _headers(headers), body: body == null ? null : json.encode(body));
    return _parse(r);
  }

  Future<void> _delete(String p, {Map<String, dynamic>? params, Map<String, String>? headers}) async {
    final r = await http.delete(_u(p, params), headers: _headers(headers));
    await _parse(r);
  }

  // -------- Generic list helpers --------

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
      final list = data.map((e) => fromJson(Map<String, dynamic>.from(e as Map))).toList();
      return PageResult(items: list, total: list.length);
    }
    if (data is Map) {
      final items = (data['items'] as List? ?? const [])
          .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final total = data['total'] is int ? data['total'] as int : items.length;
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

  // -------- Auth --------
  Future<String> login({required String mobile, required String password}) async {
    final uri = Uri.parse('$baseUrl/auth/login')
        .replace(queryParameters: {'mobile': mobile, 'password': password});
    final r = await http.post(uri, headers: _headers());
    final data = _decodeOrThrow(r);
    if (data is Map) {
      for (final k in ['access_token', 'token', 'jwt', 'id_token']) {
        final v = data[k];
        if (v is String && v.isNotEmpty) return v;
      }
    }
    throw ApiException('Token not found in login response', r.statusCode);
  }

  Future<dynamic> healthz() => _get('/healthz');

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


  // -------- Settings / Printers / Stations --------
  Future<Printer> createPrinter(Printer p) => createOne<Printer>(
    path: '/settings/printers',
    body: p.toJson(),
    fromJson: Printer.fromJson,
  );

  Future<KitchenStation> createStation(KitchenStation s) => createOne<KitchenStation>(
    path: '/settings/stations',
    body: s.toJson(),
    fromJson: KitchenStation.fromJson,
  );

  Future<RestaurantSettings?> getRestaurantSettings({required String tenantId, required String branchId}) async {
    final r = await _get('/settings/restaurant', params: {'tenant_id': tenantId, 'branch_id': branchId});
    if (r == null) return null;
    return RestaurantSettings.fromJson(Map<String, dynamic>.from(r as Map));
  }

  // -------- Menu --------
  // Always send tenant_id & branch_id (empty string if unknown)
  Future<List<MenuCategory>> fetchCategories({
    String? tenantId,
    String? branchId,
  }) {
    return listAll<MenuCategory>(
      path: '/menu/categories',
      params: <String, dynamic>{
        'tenant_id': tenantId ?? '',
        'branch_id': branchId ?? '',
      },
      fromJson: MenuCategory.fromJson,
    );
  }



  Future<MenuCategory> createCategory(MenuCategory data) => createOne<MenuCategory>(
    path: '/menu/categories',
    body: data.toJson(),
    fromJson: MenuCategory.fromJson,
  );

  Future<MenuCategory> updateCategory(String id, MenuCategory data) => updateOne<MenuCategory>(
    path: '/menu/categories/$id',
    body: data.toJson(),
    fromJson: MenuCategory.fromJson,
  );

  Future<void> deleteCategory(String id) => _delete('/menu/categories/$id');

  Future<List<MenuItem>> fetchItems({String? categoryId, String? tenantId}) => listAll<MenuItem>(
    path: '/menu/items',
    params: {'category_id': categoryId, 'tenant_id': tenantId}..removeWhere((k, v) => v == null),
    fromJson: MenuItem.fromJson,
  );

  Future<MenuItem> createItem(MenuItem data) => createOne<MenuItem>(
    path: '/menu/items',
    body: data.toJson(),
    fromJson: MenuItem.fromJson,
  );

  Future<MenuItem> updateItem(String id, MenuItem data) => updateOne<MenuItem>(
    path: '/menu/items/$id',
    body: data.toJson(),
    fromJson: MenuItem.fromJson,
  );

  Future<void> deleteItem(String id) => _delete('/menu/items/$id');

  Future<void> updateItemTax(String itemId, {required double gstRate, required bool taxInclusive}) async {
    await _post('/menu/items/$itemId/update_tax', params: {'gst_rate': gstRate, 'tax_inclusive': taxInclusive});
  }

  Future<List<ItemVariant>> fetchVariants(String itemId) {
    return listAll<ItemVariant>(
      path: '/menu/variants',
      params: {'item_id': itemId},
      fromJson: ItemVariant.fromJson,
    );
  }

  Future<ItemVariant> createVariant(String itemId, ItemVariant data) {
    return createOne<ItemVariant>(
      path: '/menu/variants',
      body: data.toJson(),
      fromJson: ItemVariant.fromJson,
    );
  }

  Future<ModifierGroup> createModifierGroup(ModifierGroup g) => createOne<ModifierGroup>(
    path: '/menu/modifier_groups',
    body: g.toJson(),
    fromJson: ModifierGroup.fromJson,
  );

  Future<Modifier> createModifier(Modifier m) => createOne<Modifier>(
    path: '/menu/modifiers',
    body: m.toJson(),
    fromJson: Modifier.fromJson,
  );

  Future<void> linkItemModifierGroup(String itemId, String groupId) async {
    await _post('/menu/items/$itemId/modifier_groups', body: {'group_id': groupId});
  }

  // -------- Dining & Customers --------
  Future<DiningTable> createTable(DiningTable t) =>
      createOne<DiningTable>(path: '/dining/tables', body: t.toJson(), fromJson: DiningTable.fromJson);

  Future<Customer> createCustomer(Customer c) =>
      createOne<Customer>(path: '/customers/', body: c.toJson(), fromJson: Customer.fromJson);

  Future<List<Customer>> listCustomers({String? tenantId}) => listAll<Customer>(
    path: '/customers/',
    params: {'tenant_id': tenantId}..removeWhere((k, v) => v == null),
    fromJson: Customer.fromJson,
  );

  // -------- Shift --------
  Future<Map<String, dynamic>> openShift({required String branchId, required double openingFloat}) async {
    final r = await _post('/shift/open', params: {'branch_id': branchId, 'opening_float': openingFloat});
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> payout(String shiftId, double amount, String reason) async {
    await _post('/shift/$shiftId/payout', params: {'amount': amount, 'reason': reason});
  }

  Future<void> closeShift(String shiftId, {required double expectedCash, required double actualCash, String? note}) async {
    await _post('/shift/$shiftId/close',
        params: {'expected_cash': expectedCash, 'actual_cash': actualCash, 'note': note}..removeWhere((k, v) => v == null));
  }

  // -------- Orders / Pay / Invoice --------
  Future<PageResult<Order>> fetchOrders({OrderStatus? status, int page = 1, int size = 20}) {
    return listPage<Order>(
      path: '/orders/',
      params: {'status': status?.name, 'page': page, 'size': size}..removeWhere((k, v) => v == null),
      fromJson: Order.fromJson,
    );
  }

  Future<Order> getOrder(String id) async {
    final r = await _get('/orders/$id');
    return Order.fromJson(Map<String, dynamic>.from(r as Map));
  }

  Future<Order> createOrder(Order data) {
    return createOne<Order>(
      path: '/orders/',
      body: data.toJson(),
      fromJson: Order.fromJson,
    );
  }

  Future<Order> patchOrderStatus(String id, OrderStatus status) async {
    final r = await _patch('/orders/$id', body: {'status': status.name});
    return Order.fromJson(Map<String, dynamic>.from(r as Map));
  }

  Future<Map<String, dynamic>> addOrderItem(String orderId, OrderItem line, {List<OrderItemModifier>? modifiers}) async {
    final body = line.toJson();
    if (modifiers != null && modifiers.isNotEmpty) {
      body['modifiers'] = modifiers.map((m) => m.toJson()).toList();
    }
    final r = await _post('/orders/$orderId/items', body: body);
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> deleteOrderLine(String orderId, String lineId, {String? reason}) async {
    await _delete('/orders/$orderId/items/$lineId', params: {'reason': reason});
  }

  Future<void> applyLineDiscount(String orderId, String lineId, double discount, String reason) async {
    await _post('/orders/$orderId/items/$lineId/apply_discount', body: {'discount': discount, 'reason': reason});
  }

  Future<void> pay(String orderId, PayMode mode, double amount, {String? refNo}) async {
    await _post('/orders/$orderId/pay', body: {'order_id': orderId, 'mode': mode.name, 'amount': amount, 'ref_no': refNo});
  }

  Future<Map<String, dynamic>> createInvoice(String orderId) async {
    final r = await _post('/orders/$orderId/invoice');
    return Map<String, dynamic>.from(r as Map);
  }

  // -------- Print / Drawer --------
  Future<void> printInvoice(String invoiceId, {String? reason}) async {
    await _post('/print/invoice/$invoiceId', params: {'reason': reason});
  }

  Future<void> openDrawer() async => _post('/print/open_drawer');

  // -------- Kitchen Tickets (KOT) --------
  Future<List<KitchenTicket>> fetchKitchenTickets({KOTStatus? status}) {
    return listAll<KitchenTicket>(
      path: '/kot/tickets',
      params: {'status': status?.name}..removeWhere((k, v) => v == null),
      fromJson: KitchenTicket.fromJson,
    );
  }

  Future<KitchenTicket> createKitchenTicket({required String orderId, required int ticketNo, String? targetStation}) async {
    final r = await _post('/kot/tickets', params: {
      'order_id': orderId,
      'ticket_no': ticketNo,
      'target_station': targetStation,
    }..removeWhere((k, v) => v == null));
    return KitchenTicket.fromJson(Map<String, dynamic>.from(r as Map));
  }

  Future<void> reprintKitchenTicket(String ticketId, {String? reason}) async {
    await _post('/kot/$ticketId/reprint', params: {'reason': reason});
  }

  Future<void> cancelKitchenTicket(String ticketId, {String? reason}) async {
    await _post('/kot/$ticketId/cancel', params: {'reason': reason});
  }

  Future<KitchenTicket> patchKitchenTicketStatus(String id, KOTStatus status) async {
    final r = await _patch('/kot/$id', body: {'status': status.name});
    return KitchenTicket.fromJson(Map<String, dynamic>.from(r as Map));
  }

  // -------- Inventory --------
  Future<Ingredient> createIngredient(Ingredient i) =>
      createOne<Ingredient>(path: '/inventory/ingredients', body: i.toJson(), fromJson: Ingredient.fromJson);

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

  Future<void> setRecipe({required String itemId, required List<Map<String, dynamic>> lines}) async {
    await _post('/inventory/recipe', body: {'item_id': itemId, 'lines': lines});
  }

  Future<List<Map<String, dynamic>>> lowStock() async {
    final r = await _get('/inventory/low_stock');
    if (r is List) return List<Map<String, dynamic>>.from(r.map((e) => Map<String, dynamic>.from(e as Map)));
    return <Map<String, dynamic>>[];
  }

  // -------- Reports / Backup --------
  Future<void> refreshDailySales({required String day, required String branchId}) async {
    await _post('/reports/daily_sales/refresh', params: {'day': day, 'branch_id': branchId});
  }

  Future<void> refreshStockSnapshot({required String day}) async {
    await _post('/reports/stock_snapshot/refresh', params: {'day': day});
  }

  Future<BackupConfig> createBackupConfig(BackupConfig cfg) =>
      createOne<BackupConfig>(path: '/backup/config', body: cfg.toJson(), fromJson: (j) => BackupConfig.fromJson(j));

  Future<void> createBackupRun({required String configId, required bool ok, required int bytesTotal, required String location}) async {
    await _post('/backup/run', params: {'config_id': configId, 'ok': ok, 'bytes_total': bytesTotal, 'location': location});
  }

  Future<List<Map<String, dynamic>>> listBackupRuns({required String configId}) async {
    final r = await _get('/backup/runs', params: {'config_id': configId});
    if (r is List) return List<Map<String, dynamic>>.from(r.map((e) => Map<String, dynamic>.from(e as Map)));
    return <Map<String, dynamic>>[];
  }

  // -------- Users / Roles --------
  Future<User> createUser(User u, {String? password, String? pin, List<String>? roles}) => createOne<User>(
    path: '/users/',
    body: {
      ...u.toJson(),
      if (password != null) 'password': password,
      if (pin != null) 'pin': pin,
      if (roles != null) 'roles': roles,
    },
    fromJson: User.fromJson,
  );

  Future<List<Role>> listRoles({required String tenantId}) => listAll<Role>(
    path: '/users/roles',
    params: {'tenant_id': tenantId},
    fromJson: Role.fromJson,
  );

  Future<void> grantRolePermissions(String roleId, List<String> permissions) async {
    await _post('/users/roles/$roleId/grant', body: {'permissions': permissions});
  }

  // -------- Sync --------
  Future<void> syncPush({required String deviceId, required List<Map<String, dynamic>> ops}) async {
    await _post('/sync/push', body: {'device_id': deviceId, 'ops': ops});
  }

  Future<Map<String, dynamic>> syncPull({required int since, required int limit}) async {
    final r = await _get('/sync/pull', params: {'since': since, 'limit': limit});
    return Map<String, dynamic>.from(r as Map);
  }
}

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => 'ApiException($status): $message';
}


