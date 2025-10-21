class MenuCategoryCol {
  final int? id;
  final String name;
  final String? rid;
  final int position; // NEW

  MenuCategoryCol({
    this.id,
    required this.name,
    this.rid,
    this.position = 0, // default
  });
}

class MenuItemCol {
  final int? id;
  final int categoryId;
  final String name;
  final double price;
  final String? rid;

  MenuItemCol({
    this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    this.rid,
  });
}

class ItemVariantCol {
  final int? id;
  final int itemId;
  final String name;
  final double priceDelta;
  final String? rid;

  ItemVariantCol({
    this.id,
    required this.itemId,
    required this.name,
    required this.priceDelta,
    this.rid,
  });
}

class DiningTableCol {
  final int? id;
  final String name;
  final String status; // 'free' | 'occupied'

  DiningTableCol({
    this.id,
    required this.name,
    required this.status,
  });
}

class OpsJournalEntry {
  final int? id;
  final String kind;
  final String payload;
  final DateTime createdAt;

  OpsJournalEntry({
    this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
  });
}

class SyncMeta {
  final DateTime? lastSyncAt;
  SyncMeta({this.lastSyncAt});
}
