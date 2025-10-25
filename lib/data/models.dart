// lib/data/models.dart
import 'dart:convert';

/// ---------- Utilities ----------
DateTime? _dt(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  final s = v.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

T _enum<T>(String? s, List<T> values, String Function(T) nameOf, {T? orElse}) {
  if (s == null) return orElse as T;
  for (final v in values) {
    if (nameOf(v) == s) return v;
  }
  return orElse as T;
}

String? _str(dynamic v) => v?.toString();

double? _numToDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

int? _numToInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  final s = v.toString();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

Map<String, dynamic> _jsonMap(dynamic v) =>
    Map<String, dynamic>.from(v as Map);

/// Small page result (for list APIs that return {items,total} or a naked list).
class PageResult<T> {
  final List<T> items;
  final int? total;
  PageResult({required this.items, this.total});
}

/// ---------- Enums ----------
enum OrderChannel { DINE_IN, TAKEAWAY, DELIVERY, ONLINE }
enum OrderStatus { OPEN, KITCHEN, READY, SERVED, CLOSED, VOID }
enum PayMode { CASH, CARD, UPI, WALLET, COUPON }
enum PrinterType { BILLING, KITCHEN }
enum ChargeMode { NONE, PERCENT, FLAT }
enum KOTStatus { NEW, IN_PROGRESS, READY, DONE, CANCELLED }
enum StockMoveType { PURCHASE, SALE, ADJUST, WASTAGE }
enum OnlineProvider { ZOMATO, SWIGGY, CUSTOM }
enum BackupProvider { NONE, S3, GDRIVE, AZURE }

/// ---------- Identity ----------
class Tenant {
  final String? id;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Tenant({
    this.id,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory Tenant.fromJson(Map<String, dynamic> j) => Tenant(
    id: _str(j['id']),
    name: _str(j['name']) ?? '',
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}

class Branch {
  final String? id;
  final String tenantId;
  final String name;
  final String? gstin;
  final String? address;
  final String? phone;
  final String? stateCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Branch({
    this.id,
    required this.tenantId,
    required this.name,
    this.gstin,
    this.address,
    this.phone,
    this.stateCode,
    this.createdAt,
    this.updatedAt,
  });

  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
    id: _str(j['id']),
    tenantId: _str(j['tenant_id']) ?? '',
    name: _str(j['name']) ?? '',
    gstin: _str(j['gstin']),
    address: _str(j['address']),
    phone: _str(j['phone']),
    stateCode: _str(j['state_code']),
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'name': name,
    'gstin': gstin,
    'address': address,
    'phone': phone,
    'state_code': stateCode,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}

class User {
  final String? id;
  final String tenantId;
  final String name;
  final String? mobile;
  final String? email;
  final bool? active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    this.id,
    required this.tenantId,
    required this.name,
    this.mobile,
    this.email,
    this.active,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: _str(j['id']),
    tenantId: _str(j['tenant_id']) ?? '',
    name: _str(j['name']) ?? '',
    mobile: _str(j['mobile']),
    email: _str(j['email']),
    active: j['active'] == null ? null : (j['active'] as bool),
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'name': name,
    'mobile': mobile,
    'email': email,
    'active': active,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}

class Role {
  final String? id;
  final String tenantId;
  final String code;
  Role({this.id, required this.tenantId, required this.code});
  factory Role.fromJson(Map<String, dynamic> j) =>
      Role(id: _str(j['id']), tenantId: _str(j['tenant_id']) ?? '', code: _str(j['code']) ?? '');
  Map<String, dynamic> toJson() => {'id': id, 'tenant_id': tenantId, 'code': code};
}

class Permission {
  final String? id;
  final String code;
  final String? description;
  Permission({this.id, required this.code, this.description});
  factory Permission.fromJson(Map<String, dynamic> j) =>
      Permission(id: _str(j['id']), code: _str(j['code']) ?? '', description: _str(j['description']));
  Map<String, dynamic> toJson() => {'id': id, 'code': code, 'description': description};
}

/// ---------- Printers & Stations ----------
class Printer {
  final String? id;
  final String tenantId;
  final String branchId;
  final String name;
  final PrinterType type;
  final String? connectionUrl;
  final bool isDefault;
  final bool cashDrawerEnabled;
  final String? cashDrawerCode;

  Printer({
    this.id,
    required this.tenantId,
    required this.branchId,
    required this.name,
    required this.type,
    this.connectionUrl,
    this.isDefault = false,
    this.cashDrawerEnabled = false,
    this.cashDrawerCode,
  });

  factory Printer.fromJson(Map<String, dynamic> j) => Printer(
    id: _str(j['id']),
    tenantId: _str(j['tenant_id']) ?? '',
    branchId: _str(j['branch_id']) ?? '',
    name: _str(j['name']) ?? '',
    type: _enum<PrinterType>(_str(j['type']), PrinterType.values, (e) => e.name, orElse: PrinterType.BILLING),
    connectionUrl: _str(j['connection_url']),
    isDefault: (j['is_default'] as bool?) ?? false,
    cashDrawerEnabled: (j['cash_drawer_enabled'] as bool?) ?? false,
    cashDrawerCode: _str(j['cash_drawer_code']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'branch_id': branchId,
    'name': name,
    'type': type.name,
    'connection_url': connectionUrl,
    'is_default': isDefault,
    'cash_drawer_enabled': cashDrawerEnabled,
    'cash_drawer_code': cashDrawerCode,
  };
}

class KitchenStation {
  final String? id;
  final String tenantId;
  final String branchId;
  final String name;
  final String? printerId;

  KitchenStation({
    this.id,
    required this.tenantId,
    required this.branchId,
    required this.name,
    this.printerId,
  });

  factory KitchenStation.fromJson(Map<String, dynamic> j) => KitchenStation(
    id: _str(j['id']),
    tenantId: _str(j['tenant_id']) ?? '',
    branchId: _str(j['branch_id']) ?? '',
    name: _str(j['name']) ?? '',
    printerId: _str(j['printer_id']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'branch_id': branchId,
    'name': name,
    'printer_id': printerId,
  };
}

/// ---------- Settings ----------
class RestaurantSettings {
  final String? id;
  final String tenantId;
  final String branchId;
  final String name;
  final String? logoUrl;
  final String? address;
  final String? phone;
  final String? gstin;
  final String? fssai;
  final bool printFssaiOnInvoice;
  final bool gstInclusiveDefault;
  final ChargeMode serviceChargeMode;
  final double serviceChargeValue;
  final ChargeMode packingChargeMode;
  final double packingChargeValue;
  final String? billingPrinterId;
  final String? invoiceFooter;

  RestaurantSettings({
    this.id,
    required this.tenantId,
    required this.branchId,
    required this.name,
    this.logoUrl,
    this.address,
    this.phone,
    this.gstin,
    this.fssai,
    this.printFssaiOnInvoice = false,
    this.gstInclusiveDefault = true,
    this.serviceChargeMode = ChargeMode.NONE,
    this.serviceChargeValue = 0,
    this.packingChargeMode = ChargeMode.NONE,
    this.packingChargeValue = 0,
    this.billingPrinterId,
    this.invoiceFooter,
  });

  factory RestaurantSettings.fromJson(Map<String, dynamic> j) => RestaurantSettings(
    id: _str(j['id']),
    tenantId: _str(j['tenant_id']) ?? '',
    branchId: _str(j['branch_id']) ?? '',
    name: _str(j['name']) ?? '',
    logoUrl: _str(j['logo_url']),
    address: _str(j['address']),
    phone: _str(j['phone']),
    gstin: _str(j['gstin']),
    fssai: _str(j['fssai']),
    printFssaiOnInvoice: (j['print_fssai_on_invoice'] as bool?) ?? false,
    gstInclusiveDefault: (j['gst_inclusive_default'] as bool?) ?? true,
    serviceChargeMode:
    _enum<ChargeMode>(_str(j['service_charge_mode']), ChargeMode.values, (e) => e.name, orElse: ChargeMode.NONE),
    serviceChargeValue: _numToDouble(j['service_charge_value']) ?? 0,
    packingChargeMode:
    _enum<ChargeMode>(_str(j['packing_charge_mode']), ChargeMode.values, (e) => e.name, orElse: ChargeMode.NONE),
    packingChargeValue: _numToDouble(j['packing_charge_value']) ?? 0,
    billingPrinterId: _str(j['billing_printer_id']),
    invoiceFooter: _str(j['invoice_footer']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'branch_id': branchId,
    'name': name,
    'logo_url': logoUrl,
    'address': address,
    'phone': phone,
    'gstin': gstin,
    'fssai': fssai,
    'print_fssai_on_invoice': printFssaiOnInvoice,
    'gst_inclusive_default': gstInclusiveDefault,
    'service_charge_mode': serviceChargeMode.name,
    'service_charge_value': serviceChargeValue,
    'packing_charge_mode': packingChargeMode.name,
    'packing_charge_value': packingChargeValue,
    'billing_printer_id': billingPrinterId,
    'invoice_footer': invoiceFooter,
  };
}

/// ---------- Menu ----------
class MenuCategory {
  final String? id;
  final String tenantId;
  final String branchId;
  final String name;
  final int position;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MenuCategory({
    this.id,
    required this.tenantId,
    required this.branchId,
    required this.name,
    this.position = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> j) => MenuCategory(
    id: _str(j['id']),
    tenantId: _str(j['tenant_id']) ?? '',
    branchId: _str(j['branch_id']) ?? '',
    name: _str(j['name']) ?? '',
    position: _numToInt(j['position']) ?? 0,
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'branch_id': branchId,
    'name': name,
    'position': position,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}

class MenuItem {
  final String? id;
  final String tenantId;
  final String name;
  final String? description;
  final String categoryId;
  final String? sku;
  final String? hsn;
  final bool isActive;
  final bool stockOut;
  final bool taxInclusive;
  final double gstRate;
  final String? kitchenStationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MenuItem({
    this.id,
    required this.tenantId,
    required this.name,
    this.description,
    required this.categoryId,
    this.sku,
    this.hsn,
    this.isActive = true,
    this.stockOut = false,
    this.taxInclusive = true,
    this.gstRate = 5.0,
    this.kitchenStationId,
    this.createdAt,
    this.updatedAt,
  });

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
    id: _str(j['id']),
    tenantId: _str(j['tenant_id']) ?? '',
    name: _str(j['name']) ?? '',
    description: _str(j['description']),
    categoryId: _str(j['category_id']) ?? '',
    sku: _str(j['sku']),
    hsn: _str(j['hsn']),
    isActive: (j['is_active'] as bool?) ?? true,
    stockOut: (j['stock_out'] as bool?) ?? false,
    taxInclusive: (j['tax_inclusive'] as bool?) ?? true,
    gstRate: _numToDouble(j['gst_rate']) ?? 5.0,
    kitchenStationId: _str(j['kitchen_station_id']),
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'name': name,
    'description': description,
    'category_id': categoryId,
    'sku': sku,
    'hsn': hsn,
    'is_active': isActive,
    'stock_out': stockOut,
    'tax_inclusive': taxInclusive,
    'gst_rate': gstRate,
    'kitchen_station_id': kitchenStationId,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}

class ItemVariant {
  final String? id;
  final String itemId;
  final String label;
  final double? mrp;
  final double basePrice;
  final bool isDefault;

  ItemVariant({
    this.id,
    required this.itemId,
    required this.label,
    this.mrp,
    required this.basePrice,
    this.isDefault = false,
  });

  factory ItemVariant.fromJson(Map<String, dynamic> j) => ItemVariant(
    id: _str(j['id']),
    itemId: _str(j['item_id']) ?? '',
    label: _str(j['label']) ?? '',
    mrp: _numToDouble(j['mrp']),
    basePrice: _numToDouble(j['base_price']) ?? 0,
    isDefault: (j['is_default'] as bool?) ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'item_id': itemId,
    'label': label,
    'mrp': mrp,
    'base_price': basePrice,
    'is_default': isDefault,
  };
}

class ModifierGroup {
  final String? id;
  final String tenantId;
  final String name;
  final int minSel;
  final int? maxSel;
  final bool required;

  ModifierGroup({
    this.id,
    required this.tenantId,
    required this.name,
    this.minSel = 0,
    this.maxSel,
    this.required = false,
  });

  factory ModifierGroup.fromJson(Map<String, dynamic> j) => ModifierGroup(
    id: _str(j['id']),
    tenantId: _str(j['tenant_id']) ?? '',
    name: _str(j['name']) ?? '',
    minSel: _numToInt(j['min_sel']) ?? 0,
    maxSel: _numToInt(j['max_sel']),
    required: (j['required'] as bool?) ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'name': name,
    'min_sel': minSel,
    'max_sel': maxSel,
    'required': required,
  };
}

class Modifier {
  final String? id;
  final String groupId;
  final String name;
  final double priceDelta;

  Modifier({this.id, required this.groupId, required this.name, this.priceDelta = 0});

  factory Modifier.fromJson(Map<String, dynamic> j) => Modifier(
    id: _str(j['id']),
    groupId: _str(j['group_id']) ?? '',
    name: _str(j['name']) ?? '',
    priceDelta: _numToDouble(j['price_delta']) ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'group_id': groupId,
    'name': name,
    'price_delta': priceDelta,
  };
}

/// ---------- Dining & Customer ----------
class DiningTable {
  final String? id;
  final String branchId;
  final String code;
  final String? zone;
  final int? seats;
  DiningTable({this.id, required this.branchId, required this.code, this.zone, this.seats});
  factory DiningTable.fromJson(Map<String, dynamic> j) => DiningTable(
    id: _str(j['id']),
    branchId: _str(j['branch_id']) ?? '',
    code: _str(j['code']) ?? '',
    zone: _str(j['zone']),
    seats: _numToInt(j['seats']),
  );
  Map<String, dynamic> toJson() => {'id': id, 'branch_id': branchId, 'code': code, 'zone': zone, 'seats': seats};
}

class Customer {
  final String? id;
  final String tenantId;
  final String name;
  final String? phone;
  final String? stateCode;
  Customer({this.id, required this.tenantId, required this.name, this.phone, this.stateCode});
  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: _str(j['id']),
    tenantId: _str(j['tenant_id']) ?? '',
    name: _str(j['name']) ?? '',
    phone: _str(j['phone']),
    stateCode: _str(j['state_code']),
  );
  Map<String, dynamic> toJson() =>
      {'id': id, 'tenant_id': tenantId, 'name': name, 'phone': phone, 'state_code': stateCode};
}

/// ---------- Orders / Payments / Invoice ----------
class Order {
  final String? id;
  final String tenantId;
  final String branchId;
  final int orderNo;
  final OrderChannel channel;
  final OnlineProvider? provider;
  final OrderStatus status;
  final String? tableId;
  final String? customerId;
  final String? openedByUserId;
  final String? closedByUserId;
  final int? pax;
  final String? sourceDeviceId;
  final String? note;
  final DateTime? openedAt;
  final DateTime? closedAt;

  Order({
    this.id,
    required this.tenantId,
    required this.branchId,
    required this.orderNo,
    required this.channel,
    this.provider,
    this.status = OrderStatus.OPEN,
    this.tableId,
    this.customerId,
    this.openedByUserId,
    this.closedByUserId,
    this.pax,
    this.sourceDeviceId,
    this.note,
    this.openedAt,
    this.closedAt,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: _str(j['id']),
    tenantId: _str(j['tenant_id']) ?? '',
    branchId: _str(j['branch_id']) ?? '',
    orderNo: _numToInt(j['order_no']) ?? 0,
    channel: _enum<OrderChannel>(_str(j['channel']), OrderChannel.values, (e) => e.name,
        orElse: OrderChannel.DINE_IN),
    provider: j['provider'] == null
        ? null
        : _enum<OnlineProvider>(
      _str(j['provider']),
      OnlineProvider.values,
          (e) => e.name,
    ),
    status: _enum<OrderStatus>(_str(j['status']), OrderStatus.values, (e) => e.name,
        orElse: OrderStatus.OPEN),
    tableId: _str(j['table_id']),
    customerId: _str(j['customer_id']),
    openedByUserId: _str(j['opened_by_user_id']),
    closedByUserId: _str(j['closed_by_user_id']),
    pax: _numToInt(j['pax']),
    sourceDeviceId: _str(j['source_device_id']),
    note: _str(j['note']),
    openedAt: _dt(j['opened_at']),
    closedAt: _dt(j['closed_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'branch_id': branchId,
    'order_no': orderNo,
    'channel': channel.name,
    'provider': provider?.name,
    'status': status.name,
    'table_id': tableId,
    'customer_id': customerId,
    'opened_by_user_id': openedByUserId,
    'closed_by_user_id': closedByUserId,
    'pax': pax,
    'source_device_id': sourceDeviceId,
    'note': note,
    'opened_at': openedAt?.toIso8601String(),
    'closed_at': closedAt?.toIso8601String(),
  };
}

class OrderItem {
  final String? id;
  final String orderId;
  final String itemId;
  final String? variantId;
  final String? parentLineId;
  final double qty;
  final double unitPrice;
  final double lineDiscount;
  final double gstRate;
  final double cgst;
  final double sgst;
  final double igst;
  final double taxableValue;

  OrderItem({
    this.id,
    required this.orderId,
    required this.itemId,
    this.variantId,
    this.parentLineId,
    required this.qty,
    required this.unitPrice,
    this.lineDiscount = 0,
    this.gstRate = 5.0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.taxableValue = 0,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    id: _str(j['id']),
    orderId: _str(j['order_id']) ?? '',
    itemId: _str(j['item_id']) ?? '',
    variantId: _str(j['variant_id']),
    parentLineId: _str(j['parent_line_id']),
    qty: _numToDouble(j['qty']) ?? 0,
    unitPrice: _numToDouble(j['unit_price']) ?? 0,
    lineDiscount: _numToDouble(j['line_discount']) ?? 0,
    gstRate: _numToDouble(j['gst_rate']) ?? 0,
    cgst: _numToDouble(j['cgst']) ?? 0,
    sgst: _numToDouble(j['sgst']) ?? 0,
    igst: _numToDouble(j['igst']) ?? 0,
    taxableValue: _numToDouble(j['taxable_value']) ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId,
    'item_id': itemId,
    'variant_id': variantId,
    'parent_line_id': parentLineId,
    'qty': qty,
    'unit_price': unitPrice,
    'line_discount': lineDiscount,
    'gst_rate': gstRate,
    'cgst': cgst,
    'sgst': sgst,
    'igst': igst,
    'taxable_value': taxableValue,
  };
}

class OrderItemModifier {
  final String? id;
  final String orderItemId;
  final String modifierId;
  final double qty;
  final double priceDelta;

  OrderItemModifier({
    this.id,
    required this.orderItemId,
    required this.modifierId,
    this.qty = 1,
    this.priceDelta = 0,
  });

  factory OrderItemModifier.fromJson(Map<String, dynamic> j) => OrderItemModifier(
    id: _str(j['id']),
    orderItemId: _str(j['order_item_id']) ?? '',
    modifierId: _str(j['modifier_id']) ?? '',
    qty: _numToDouble(j['qty']) ?? 1,
    priceDelta: _numToDouble(j['price_delta']) ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_item_id': orderItemId,
    'modifier_id': modifierId,
    'qty': qty,
    'price_delta': priceDelta,
  };
}

class KitchenTicket {
  final String? id;
  final String orderId;
  final int ticketNo;
  final String? targetStation;
  final KOTStatus status;
  final DateTime? printedAt;
  final int reprintCount;
  final String? cancelReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  KitchenTicket({
    this.id,
    required this.orderId,
    required this.ticketNo,
    this.targetStation,
    this.status = KOTStatus.NEW,
    this.printedAt,
    this.reprintCount = 0,
    this.cancelReason,
    this.createdAt,
    this.updatedAt,
  });

  factory KitchenTicket.fromJson(Map<String, dynamic> j) => KitchenTicket(
    id: _str(j['id']),
    orderId: _str(j['order_id']) ?? '',
    ticketNo: _numToInt(j['ticket_no']) ?? 0,
    targetStation: _str(j['target_station']),
    status: _enum<KOTStatus>(_str(j['status']), KOTStatus.values, (e) => e.name, orElse: KOTStatus.NEW),
    printedAt: _dt(j['printed_at']),
    reprintCount: _numToInt(j['reprint_count']) ?? 0,
    cancelReason: _str(j['cancel_reason']),
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId,
    'ticket_no': ticketNo,
    'target_station': targetStation,
    'status': status.name,
    'printed_at': printedAt?.toIso8601String(),
    'reprint_count': reprintCount,
    'cancel_reason': cancelReason,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}

class Payment {
  final String? id;
  final String orderId;
  final PayMode mode;
  final double amount;
  final String? refNo;
  final DateTime? paidAt;

  Payment({this.id, required this.orderId, required this.mode, required this.amount, this.refNo, this.paidAt});

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
    id: _str(j['id']),
    orderId: _str(j['order_id']) ?? '',
    mode: _enum<PayMode>(_str(j['mode']), PayMode.values, (e) => e.name, orElse: PayMode.CASH),
    amount: _numToDouble(j['amount']) ?? 0,
    refNo: _str(j['ref_no']),
    paidAt: _dt(j['paid_at']),
  );

  Map<String, dynamic> toJson() =>
      {'id': id, 'order_id': orderId, 'mode': mode.name, 'amount': amount, 'ref_no': refNo, 'paid_at': paidAt?.toIso8601String()};
}

class Invoice {
  final String? id;
  final String orderId;
  final String invoiceNo;
  final DateTime? invoiceDt;
  final String? placeOfSupply;
  final double roundOff;
  final int reprintCount;
  final String? cashierUserId;

  Invoice({
    this.id,
    required this.orderId,
    required this.invoiceNo,
    this.invoiceDt,
    this.placeOfSupply,
    this.roundOff = 0,
    this.reprintCount = 0,
    this.cashierUserId,
  });

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
    id: _str(j['id']),
    orderId: _str(j['order_id']) ?? '',
    invoiceNo: _str(j['invoice_no']) ?? '',
    invoiceDt: _dt(j['invoice_dt']),
    placeOfSupply: _str(j['place_of_supply']),
    roundOff: _numToDouble(j['round_off']) ?? 0,
    reprintCount: _numToInt(j['reprint_count']) ?? 0,
    cashierUserId: _str(j['cashier_user_id']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId,
    'invoice_no': invoiceNo,
    'invoice_dt': invoiceDt?.toIso8601String(),
    'place_of_supply': placeOfSupply,
    'round_off': roundOff,
    'reprint_count': reprintCount,
    'cashier_user_id': cashierUserId,
  };
}

/// ---------- Inventory ----------
class Ingredient {
  final String? id;
  final String tenantId;
  final String name;
  final String uom;
  final double minLevel;
  Ingredient({this.id, required this.tenantId, required this.name, required this.uom, this.minLevel = 0});
  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
    id: _str(j['id']),
    tenantId: _str(j['tenant_id']) ?? '',
    name: _str(j['name']) ?? '',
    uom: _str(j['uom']) ?? '',
    minLevel: _numToDouble(j['min_level']) ?? 0,
  );
  Map<String, dynamic> toJson() =>
      {'id': id, 'tenant_id': tenantId, 'name': name, 'uom': uom, 'min_level': minLevel};
}

class Purchase {
  final String? id;
  final String tenantId;
  final String? supplier;
  final String? note;
  Purchase({this.id, required this.tenantId, this.supplier, this.note});
  factory Purchase.fromJson(Map<String, dynamic> j) =>
      Purchase(id: _str(j['id']), tenantId: _str(j['tenant_id']) ?? '', supplier: _str(j['supplier']), note: _str(j['note']));
  Map<String, dynamic> toJson() => {'id': id, 'tenant_id': tenantId, 'supplier': supplier, 'note': note};
}

class PurchaseLine {
  final String? id;
  final String purchaseId;
  final String ingredientId;
  final double qty;
  final double unitCost;
  PurchaseLine({this.id, required this.purchaseId, required this.ingredientId, required this.qty, required this.unitCost});
  factory PurchaseLine.fromJson(Map<String, dynamic> j) => PurchaseLine(
    id: _str(j['id']),
    purchaseId: _str(j['purchase_id']) ?? '',
    ingredientId: _str(j['ingredient_id']) ?? '',
    qty: _numToDouble(j['qty']) ?? 0,
    unitCost: _numToDouble(j['unit_cost']) ?? 0,
  );
  Map<String, dynamic> toJson() =>
      {'id': id, 'purchase_id': purchaseId, 'ingredient_id': ingredientId, 'qty': qty, 'unit_cost': unitCost};
}

/// ---------- Reports / Backup (light) ----------
class ReportDailySales {
  final String? id;
  final DateTime date;
  final String tenantId;
  final String branchId;
  final String? channel;
  final String? provider;
  final int ordersCount;
  final double gross, tax, cgst, sgst, igst, discounts, net;

  ReportDailySales({
    this.id,
    required this.date,
    required this.tenantId,
    required this.branchId,
    this.channel,
    this.provider,
    this.ordersCount = 0,
    this.gross = 0,
    this.tax = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.discounts = 0,
    this.net = 0,
  });

  factory ReportDailySales.fromJson(Map<String, dynamic> j) => ReportDailySales(
    id: _str(j['id']),
    date: _dt(j['date']) ?? DateTime.now(),
    tenantId: _str(j['tenant_id']) ?? '',
    branchId: _str(j['branch_id']) ?? '',
    channel: _str(j['channel']),
    provider: _str(j['provider']),
    ordersCount: _numToInt(j['orders_count']) ?? 0,
    gross: _numToDouble(j['gross']) ?? 0,
    tax: _numToDouble(j['tax']) ?? 0,
    cgst: _numToDouble(j['cgst']) ?? 0,
    sgst: _numToDouble(j['sgst']) ?? 0,
    igst: _numToDouble(j['igst']) ?? 0,
    discounts: _numToDouble(j['discounts']) ?? 0,
    net: _numToDouble(j['net']) ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'tenant_id': tenantId,
    'branch_id': branchId,
    'channel': channel,
    'provider': provider,
    'orders_count': ordersCount,
    'gross': gross,
    'tax': tax,
    'cgst': cgst,
    'sgst': sgst,
    'igst': igst,
    'discounts': discounts,
    'net': net,
  };
}

class BackupConfig {
  final String? id;
  final String tenantId;
  final String branchId;
  final BackupProvider provider;
  final String? localDir;
  final String? endpoint;
  final String? bucket;
  final String? accessKey;
  final String? secretKey;
  final String? scheduleCron;

  BackupConfig({
    this.id,
    required this.tenantId,
    required this.branchId,
    this.provider = BackupProvider.NONE,
    this.localDir,
    this.endpoint,
    this.bucket,
    this.accessKey,
    this.secretKey,
    this.scheduleCron,
  });

  factory BackupConfig.fromJson(Map<String, dynamic> j) => BackupConfig(
    id: _str(j['id']),
    tenantId: _str(j['tenant_id']) ?? '',
    branchId: _str(j['branch_id']) ?? '',
    provider: _enum<BackupProvider>(_str(j['provider']), BackupProvider.values, (e) => e.name,
        orElse: BackupProvider.NONE),
    localDir: _str(j['local_dir']),
    endpoint: _str(j['endpoint']),
    bucket: _str(j['bucket']),
    accessKey: _str(j['access_key']),
    secretKey: _str(j['secret_key']),
    scheduleCron: _str(j['schedule_cron']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'branch_id': branchId,
    'provider': provider.name,
    'local_dir': localDir,
    'endpoint': endpoint,
    'bucket': bucket,
    'access_key': accessKey,
    'secret_key': secretKey,
    'schedule_cron': scheduleCron,
  };
}

/// ---------- Order detail view (frontend only helper) ----------

class OrderTotals {
  final double subtotal;
  final double tax;
  final double total;
  final double paid;
  final double due;

  OrderTotals({
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.paid,
    required this.due,
  });

  factory OrderTotals.fromJson(Map<String, dynamic> j) => OrderTotals(
    // backend compute_bill may use slightly different keys, so we’re defensive
    subtotal: _numToDouble(j['subtotal']) ??
        _numToDouble(j['sub_total']) ??
        _numToDouble(j['subTotal']) ??
        0,
    tax: _numToDouble(j['tax']) ??
        _numToDouble(j['tax_total']) ??
        _numToDouble(j['taxTotal']) ??
        0,
    total: _numToDouble(j['total']) ??
        _numToDouble(j['grand_total']) ??
        _numToDouble(j['grandTotal']) ??
        0,
    paid: _numToDouble(j['paid']) ?? 0,
    due: _numToDouble(j['due']) ??
        _numToDouble(j['total_due']) ??
        _numToDouble(j['totalDue']) ??
        0,
  );
}

/// Wrapper for detail screen: high-level order + its totals
class OrderDetail {
  final Order order;
  final OrderTotals totals;
  OrderDetail({required this.order, required this.totals});
}

