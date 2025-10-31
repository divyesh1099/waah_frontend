// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $MenuCategoriesTable extends MenuCategories
    with TableInfo<$MenuCategoriesTable, MenuCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MenuCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'rid', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [id, remoteId, name, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'menu_categories';
  @override
  VerificationContext validateIntegrity(Insertable<MenuCategory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('rid')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['rid']!, _remoteIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MenuCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MenuCategory(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rid']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
    );
  }

  @override
  $MenuCategoriesTable createAlias(String alias) {
    return $MenuCategoriesTable(attachedDatabase, alias);
  }
}

class MenuCategory extends DataClass implements Insertable<MenuCategory> {
  final int id;
  final String? remoteId;
  final String name;
  final int position;
  const MenuCategory(
      {required this.id,
      this.remoteId,
      required this.name,
      required this.position});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || remoteId != null) {
      map['rid'] = Variable<String>(remoteId);
    }
    map['name'] = Variable<String>(name);
    map['position'] = Variable<int>(position);
    return map;
  }

  MenuCategoriesCompanion toCompanion(bool nullToAbsent) {
    return MenuCategoriesCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      name: Value(name),
      position: Value(position),
    );
  }

  factory MenuCategory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MenuCategory(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<String?>(remoteId),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<int>(position),
    };
  }

  MenuCategory copyWith(
          {int? id,
          Value<String?> remoteId = const Value.absent(),
          String? name,
          int? position}) =>
      MenuCategory(
        id: id ?? this.id,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        name: name ?? this.name,
        position: position ?? this.position,
      );
  MenuCategory copyWithCompanion(MenuCategoriesCompanion data) {
    return MenuCategory(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MenuCategory(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, remoteId, name, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MenuCategory &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.name == this.name &&
          other.position == this.position);
}

class MenuCategoriesCompanion extends UpdateCompanion<MenuCategory> {
  final Value<int> id;
  final Value<String?> remoteId;
  final Value<String> name;
  final Value<int> position;
  const MenuCategoriesCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
  });
  MenuCategoriesCompanion.insert({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    required String name,
    this.position = const Value.absent(),
  }) : name = Value(name);
  static Insertable<MenuCategory> custom({
    Expression<int>? id,
    Expression<String>? remoteId,
    Expression<String>? name,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'rid': remoteId,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
    });
  }

  MenuCategoriesCompanion copyWith(
      {Value<int>? id,
      Value<String?>? remoteId,
      Value<String>? name,
      Value<int>? position}) {
    return MenuCategoriesCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      name: name ?? this.name,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['rid'] = Variable<String>(remoteId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MenuCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

class $MenuItemsTable extends MenuItems
    with TableInfo<$MenuItemsTable, MenuItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MenuItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'rid', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES menu_categories (id) ON DELETE CASCADE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
      'sku', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _hsnMeta = const VerificationMeta('hsn');
  @override
  late final GeneratedColumn<String> hsn = GeneratedColumn<String>(
      'hsn', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _stockOutMeta =
      const VerificationMeta('stockOut');
  @override
  late final GeneratedColumn<bool> stockOut = GeneratedColumn<bool>(
      'stock_out', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("stock_out" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _taxInclusiveMeta =
      const VerificationMeta('taxInclusive');
  @override
  late final GeneratedColumn<bool> taxInclusive = GeneratedColumn<bool>(
      'tax_inclusive', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("tax_inclusive" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _gstRateMeta =
      const VerificationMeta('gstRate');
  @override
  late final GeneratedColumn<double> gstRate = GeneratedColumn<double>(
      'gst_rate', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(5.0));
  static const VerificationMeta _kitchenStationIdMeta =
      const VerificationMeta('kitchenStationId');
  @override
  late final GeneratedColumn<String> kitchenStationId = GeneratedColumn<String>(
      'kitchen_station_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        remoteId,
        categoryId,
        name,
        description,
        sku,
        hsn,
        isActive,
        stockOut,
        taxInclusive,
        gstRate,
        kitchenStationId,
        imageUrl
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'menu_items';
  @override
  VerificationContext validateIntegrity(Insertable<MenuItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('rid')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['rid']!, _remoteIdMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('sku')) {
      context.handle(
          _skuMeta, sku.isAcceptableOrUnknown(data['sku']!, _skuMeta));
    }
    if (data.containsKey('hsn')) {
      context.handle(
          _hsnMeta, hsn.isAcceptableOrUnknown(data['hsn']!, _hsnMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('stock_out')) {
      context.handle(_stockOutMeta,
          stockOut.isAcceptableOrUnknown(data['stock_out']!, _stockOutMeta));
    }
    if (data.containsKey('tax_inclusive')) {
      context.handle(
          _taxInclusiveMeta,
          taxInclusive.isAcceptableOrUnknown(
              data['tax_inclusive']!, _taxInclusiveMeta));
    }
    if (data.containsKey('gst_rate')) {
      context.handle(_gstRateMeta,
          gstRate.isAcceptableOrUnknown(data['gst_rate']!, _gstRateMeta));
    }
    if (data.containsKey('kitchen_station_id')) {
      context.handle(
          _kitchenStationIdMeta,
          kitchenStationId.isAcceptableOrUnknown(
              data['kitchen_station_id']!, _kitchenStationIdMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MenuItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MenuItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rid']),
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      sku: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sku']),
      hsn: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}hsn']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      stockOut: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}stock_out'])!,
      taxInclusive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}tax_inclusive'])!,
      gstRate: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}gst_rate'])!,
      kitchenStationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}kitchen_station_id']),
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
    );
  }

  @override
  $MenuItemsTable createAlias(String alias) {
    return $MenuItemsTable(attachedDatabase, alias);
  }
}

class MenuItem extends DataClass implements Insertable<MenuItem> {
  final int id;
  final String? remoteId;
  final int categoryId;
  final String name;
  final String? description;
  final String? sku;
  final String? hsn;
  final bool isActive;
  final bool stockOut;
  final bool taxInclusive;
  final double gstRate;
  final String? kitchenStationId;
  final String? imageUrl;
  const MenuItem(
      {required this.id,
      this.remoteId,
      required this.categoryId,
      required this.name,
      this.description,
      this.sku,
      this.hsn,
      required this.isActive,
      required this.stockOut,
      required this.taxInclusive,
      required this.gstRate,
      this.kitchenStationId,
      this.imageUrl});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || remoteId != null) {
      map['rid'] = Variable<String>(remoteId);
    }
    map['category_id'] = Variable<int>(categoryId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || sku != null) {
      map['sku'] = Variable<String>(sku);
    }
    if (!nullToAbsent || hsn != null) {
      map['hsn'] = Variable<String>(hsn);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['stock_out'] = Variable<bool>(stockOut);
    map['tax_inclusive'] = Variable<bool>(taxInclusive);
    map['gst_rate'] = Variable<double>(gstRate);
    if (!nullToAbsent || kitchenStationId != null) {
      map['kitchen_station_id'] = Variable<String>(kitchenStationId);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    return map;
  }

  MenuItemsCompanion toCompanion(bool nullToAbsent) {
    return MenuItemsCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      categoryId: Value(categoryId),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      sku: sku == null && nullToAbsent ? const Value.absent() : Value(sku),
      hsn: hsn == null && nullToAbsent ? const Value.absent() : Value(hsn),
      isActive: Value(isActive),
      stockOut: Value(stockOut),
      taxInclusive: Value(taxInclusive),
      gstRate: Value(gstRate),
      kitchenStationId: kitchenStationId == null && nullToAbsent
          ? const Value.absent()
          : Value(kitchenStationId),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
    );
  }

  factory MenuItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MenuItem(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      sku: serializer.fromJson<String?>(json['sku']),
      hsn: serializer.fromJson<String?>(json['hsn']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      stockOut: serializer.fromJson<bool>(json['stockOut']),
      taxInclusive: serializer.fromJson<bool>(json['taxInclusive']),
      gstRate: serializer.fromJson<double>(json['gstRate']),
      kitchenStationId: serializer.fromJson<String?>(json['kitchenStationId']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<String?>(remoteId),
      'categoryId': serializer.toJson<int>(categoryId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'sku': serializer.toJson<String?>(sku),
      'hsn': serializer.toJson<String?>(hsn),
      'isActive': serializer.toJson<bool>(isActive),
      'stockOut': serializer.toJson<bool>(stockOut),
      'taxInclusive': serializer.toJson<bool>(taxInclusive),
      'gstRate': serializer.toJson<double>(gstRate),
      'kitchenStationId': serializer.toJson<String?>(kitchenStationId),
      'imageUrl': serializer.toJson<String?>(imageUrl),
    };
  }

  MenuItem copyWith(
          {int? id,
          Value<String?> remoteId = const Value.absent(),
          int? categoryId,
          String? name,
          Value<String?> description = const Value.absent(),
          Value<String?> sku = const Value.absent(),
          Value<String?> hsn = const Value.absent(),
          bool? isActive,
          bool? stockOut,
          bool? taxInclusive,
          double? gstRate,
          Value<String?> kitchenStationId = const Value.absent(),
          Value<String?> imageUrl = const Value.absent()}) =>
      MenuItem(
        id: id ?? this.id,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        sku: sku.present ? sku.value : this.sku,
        hsn: hsn.present ? hsn.value : this.hsn,
        isActive: isActive ?? this.isActive,
        stockOut: stockOut ?? this.stockOut,
        taxInclusive: taxInclusive ?? this.taxInclusive,
        gstRate: gstRate ?? this.gstRate,
        kitchenStationId: kitchenStationId.present
            ? kitchenStationId.value
            : this.kitchenStationId,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
      );
  MenuItem copyWithCompanion(MenuItemsCompanion data) {
    return MenuItem(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      sku: data.sku.present ? data.sku.value : this.sku,
      hsn: data.hsn.present ? data.hsn.value : this.hsn,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      stockOut: data.stockOut.present ? data.stockOut.value : this.stockOut,
      taxInclusive: data.taxInclusive.present
          ? data.taxInclusive.value
          : this.taxInclusive,
      gstRate: data.gstRate.present ? data.gstRate.value : this.gstRate,
      kitchenStationId: data.kitchenStationId.present
          ? data.kitchenStationId.value
          : this.kitchenStationId,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MenuItem(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('sku: $sku, ')
          ..write('hsn: $hsn, ')
          ..write('isActive: $isActive, ')
          ..write('stockOut: $stockOut, ')
          ..write('taxInclusive: $taxInclusive, ')
          ..write('gstRate: $gstRate, ')
          ..write('kitchenStationId: $kitchenStationId, ')
          ..write('imageUrl: $imageUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      remoteId,
      categoryId,
      name,
      description,
      sku,
      hsn,
      isActive,
      stockOut,
      taxInclusive,
      gstRate,
      kitchenStationId,
      imageUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MenuItem &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.description == this.description &&
          other.sku == this.sku &&
          other.hsn == this.hsn &&
          other.isActive == this.isActive &&
          other.stockOut == this.stockOut &&
          other.taxInclusive == this.taxInclusive &&
          other.gstRate == this.gstRate &&
          other.kitchenStationId == this.kitchenStationId &&
          other.imageUrl == this.imageUrl);
}

class MenuItemsCompanion extends UpdateCompanion<MenuItem> {
  final Value<int> id;
  final Value<String?> remoteId;
  final Value<int> categoryId;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> sku;
  final Value<String?> hsn;
  final Value<bool> isActive;
  final Value<bool> stockOut;
  final Value<bool> taxInclusive;
  final Value<double> gstRate;
  final Value<String?> kitchenStationId;
  final Value<String?> imageUrl;
  const MenuItemsCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.sku = const Value.absent(),
    this.hsn = const Value.absent(),
    this.isActive = const Value.absent(),
    this.stockOut = const Value.absent(),
    this.taxInclusive = const Value.absent(),
    this.gstRate = const Value.absent(),
    this.kitchenStationId = const Value.absent(),
    this.imageUrl = const Value.absent(),
  });
  MenuItemsCompanion.insert({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    required int categoryId,
    required String name,
    this.description = const Value.absent(),
    this.sku = const Value.absent(),
    this.hsn = const Value.absent(),
    this.isActive = const Value.absent(),
    this.stockOut = const Value.absent(),
    this.taxInclusive = const Value.absent(),
    this.gstRate = const Value.absent(),
    this.kitchenStationId = const Value.absent(),
    this.imageUrl = const Value.absent(),
  })  : categoryId = Value(categoryId),
        name = Value(name);
  static Insertable<MenuItem> custom({
    Expression<int>? id,
    Expression<String>? remoteId,
    Expression<int>? categoryId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? sku,
    Expression<String>? hsn,
    Expression<bool>? isActive,
    Expression<bool>? stockOut,
    Expression<bool>? taxInclusive,
    Expression<double>? gstRate,
    Expression<String>? kitchenStationId,
    Expression<String>? imageUrl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'rid': remoteId,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (sku != null) 'sku': sku,
      if (hsn != null) 'hsn': hsn,
      if (isActive != null) 'is_active': isActive,
      if (stockOut != null) 'stock_out': stockOut,
      if (taxInclusive != null) 'tax_inclusive': taxInclusive,
      if (gstRate != null) 'gst_rate': gstRate,
      if (kitchenStationId != null) 'kitchen_station_id': kitchenStationId,
      if (imageUrl != null) 'image_url': imageUrl,
    });
  }

  MenuItemsCompanion copyWith(
      {Value<int>? id,
      Value<String?>? remoteId,
      Value<int>? categoryId,
      Value<String>? name,
      Value<String?>? description,
      Value<String?>? sku,
      Value<String?>? hsn,
      Value<bool>? isActive,
      Value<bool>? stockOut,
      Value<bool>? taxInclusive,
      Value<double>? gstRate,
      Value<String?>? kitchenStationId,
      Value<String?>? imageUrl}) {
    return MenuItemsCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      hsn: hsn ?? this.hsn,
      isActive: isActive ?? this.isActive,
      stockOut: stockOut ?? this.stockOut,
      taxInclusive: taxInclusive ?? this.taxInclusive,
      gstRate: gstRate ?? this.gstRate,
      kitchenStationId: kitchenStationId ?? this.kitchenStationId,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['rid'] = Variable<String>(remoteId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (hsn.present) {
      map['hsn'] = Variable<String>(hsn.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (stockOut.present) {
      map['stock_out'] = Variable<bool>(stockOut.value);
    }
    if (taxInclusive.present) {
      map['tax_inclusive'] = Variable<bool>(taxInclusive.value);
    }
    if (gstRate.present) {
      map['gst_rate'] = Variable<double>(gstRate.value);
    }
    if (kitchenStationId.present) {
      map['kitchen_station_id'] = Variable<String>(kitchenStationId.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MenuItemsCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('sku: $sku, ')
          ..write('hsn: $hsn, ')
          ..write('isActive: $isActive, ')
          ..write('stockOut: $stockOut, ')
          ..write('taxInclusive: $taxInclusive, ')
          ..write('gstRate: $gstRate, ')
          ..write('kitchenStationId: $kitchenStationId, ')
          ..write('imageUrl: $imageUrl')
          ..write(')'))
        .toString();
  }
}

class $ItemVariantsTable extends ItemVariants
    with TableInfo<$ItemVariantsTable, ItemVariant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemVariantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'rid', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
      'item_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES menu_items (id) ON DELETE CASCADE'));
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mrpMeta = const VerificationMeta('mrp');
  @override
  late final GeneratedColumn<double> mrp = GeneratedColumn<double>(
      'mrp', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _basePriceMeta =
      const VerificationMeta('basePrice');
  @override
  late final GeneratedColumn<double> basePrice = GeneratedColumn<double>(
      'base_price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _isDefaultMeta =
      const VerificationMeta('isDefault');
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
      'is_default', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_default" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, remoteId, itemId, label, mrp, basePrice, isDefault, imageUrl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_variants';
  @override
  VerificationContext validateIntegrity(Insertable<ItemVariant> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('rid')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['rid']!, _remoteIdMeta));
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('mrp')) {
      context.handle(
          _mrpMeta, mrp.isAcceptableOrUnknown(data['mrp']!, _mrpMeta));
    }
    if (data.containsKey('base_price')) {
      context.handle(_basePriceMeta,
          basePrice.isAcceptableOrUnknown(data['base_price']!, _basePriceMeta));
    } else if (isInserting) {
      context.missing(_basePriceMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(_isDefaultMeta,
          isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemVariant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemVariant(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rid']),
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}item_id'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      mrp: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}mrp']),
      basePrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}base_price'])!,
      isDefault: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_default'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
    );
  }

  @override
  $ItemVariantsTable createAlias(String alias) {
    return $ItemVariantsTable(attachedDatabase, alias);
  }
}

class ItemVariant extends DataClass implements Insertable<ItemVariant> {
  final int id;
  final String? remoteId;
  final int itemId;
  final String label;
  final double? mrp;
  final double basePrice;
  final bool isDefault;
  final String? imageUrl;
  const ItemVariant(
      {required this.id,
      this.remoteId,
      required this.itemId,
      required this.label,
      this.mrp,
      required this.basePrice,
      required this.isDefault,
      this.imageUrl});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || remoteId != null) {
      map['rid'] = Variable<String>(remoteId);
    }
    map['item_id'] = Variable<int>(itemId);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || mrp != null) {
      map['mrp'] = Variable<double>(mrp);
    }
    map['base_price'] = Variable<double>(basePrice);
    map['is_default'] = Variable<bool>(isDefault);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    return map;
  }

  ItemVariantsCompanion toCompanion(bool nullToAbsent) {
    return ItemVariantsCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      itemId: Value(itemId),
      label: Value(label),
      mrp: mrp == null && nullToAbsent ? const Value.absent() : Value(mrp),
      basePrice: Value(basePrice),
      isDefault: Value(isDefault),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
    );
  }

  factory ItemVariant.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemVariant(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      itemId: serializer.fromJson<int>(json['itemId']),
      label: serializer.fromJson<String>(json['label']),
      mrp: serializer.fromJson<double?>(json['mrp']),
      basePrice: serializer.fromJson<double>(json['basePrice']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<String?>(remoteId),
      'itemId': serializer.toJson<int>(itemId),
      'label': serializer.toJson<String>(label),
      'mrp': serializer.toJson<double?>(mrp),
      'basePrice': serializer.toJson<double>(basePrice),
      'isDefault': serializer.toJson<bool>(isDefault),
      'imageUrl': serializer.toJson<String?>(imageUrl),
    };
  }

  ItemVariant copyWith(
          {int? id,
          Value<String?> remoteId = const Value.absent(),
          int? itemId,
          String? label,
          Value<double?> mrp = const Value.absent(),
          double? basePrice,
          bool? isDefault,
          Value<String?> imageUrl = const Value.absent()}) =>
      ItemVariant(
        id: id ?? this.id,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        itemId: itemId ?? this.itemId,
        label: label ?? this.label,
        mrp: mrp.present ? mrp.value : this.mrp,
        basePrice: basePrice ?? this.basePrice,
        isDefault: isDefault ?? this.isDefault,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
      );
  ItemVariant copyWithCompanion(ItemVariantsCompanion data) {
    return ItemVariant(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      label: data.label.present ? data.label.value : this.label,
      mrp: data.mrp.present ? data.mrp.value : this.mrp,
      basePrice: data.basePrice.present ? data.basePrice.value : this.basePrice,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemVariant(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('itemId: $itemId, ')
          ..write('label: $label, ')
          ..write('mrp: $mrp, ')
          ..write('basePrice: $basePrice, ')
          ..write('isDefault: $isDefault, ')
          ..write('imageUrl: $imageUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, remoteId, itemId, label, mrp, basePrice, isDefault, imageUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemVariant &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.itemId == this.itemId &&
          other.label == this.label &&
          other.mrp == this.mrp &&
          other.basePrice == this.basePrice &&
          other.isDefault == this.isDefault &&
          other.imageUrl == this.imageUrl);
}

class ItemVariantsCompanion extends UpdateCompanion<ItemVariant> {
  final Value<int> id;
  final Value<String?> remoteId;
  final Value<int> itemId;
  final Value<String> label;
  final Value<double?> mrp;
  final Value<double> basePrice;
  final Value<bool> isDefault;
  final Value<String?> imageUrl;
  const ItemVariantsCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.label = const Value.absent(),
    this.mrp = const Value.absent(),
    this.basePrice = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.imageUrl = const Value.absent(),
  });
  ItemVariantsCompanion.insert({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    required int itemId,
    required String label,
    this.mrp = const Value.absent(),
    required double basePrice,
    this.isDefault = const Value.absent(),
    this.imageUrl = const Value.absent(),
  })  : itemId = Value(itemId),
        label = Value(label),
        basePrice = Value(basePrice);
  static Insertable<ItemVariant> custom({
    Expression<int>? id,
    Expression<String>? remoteId,
    Expression<int>? itemId,
    Expression<String>? label,
    Expression<double>? mrp,
    Expression<double>? basePrice,
    Expression<bool>? isDefault,
    Expression<String>? imageUrl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'rid': remoteId,
      if (itemId != null) 'item_id': itemId,
      if (label != null) 'label': label,
      if (mrp != null) 'mrp': mrp,
      if (basePrice != null) 'base_price': basePrice,
      if (isDefault != null) 'is_default': isDefault,
      if (imageUrl != null) 'image_url': imageUrl,
    });
  }

  ItemVariantsCompanion copyWith(
      {Value<int>? id,
      Value<String?>? remoteId,
      Value<int>? itemId,
      Value<String>? label,
      Value<double?>? mrp,
      Value<double>? basePrice,
      Value<bool>? isDefault,
      Value<String?>? imageUrl}) {
    return ItemVariantsCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      itemId: itemId ?? this.itemId,
      label: label ?? this.label,
      mrp: mrp ?? this.mrp,
      basePrice: basePrice ?? this.basePrice,
      isDefault: isDefault ?? this.isDefault,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['rid'] = Variable<String>(remoteId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (mrp.present) {
      map['mrp'] = Variable<double>(mrp.value);
    }
    if (basePrice.present) {
      map['base_price'] = Variable<double>(basePrice.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemVariantsCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('itemId: $itemId, ')
          ..write('label: $label, ')
          ..write('mrp: $mrp, ')
          ..write('basePrice: $basePrice, ')
          ..write('isDefault: $isDefault, ')
          ..write('imageUrl: $imageUrl')
          ..write(')'))
        .toString();
  }
}

class $DiningTablesTable extends DiningTables
    with TableInfo<$DiningTablesTable, DiningTable> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiningTablesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'rid', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('free'));
  @override
  List<GeneratedColumn> get $columns => [id, remoteId, name, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dining_tables';
  @override
  VerificationContext validateIntegrity(Insertable<DiningTable> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('rid')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['rid']!, _remoteIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiningTable map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiningTable(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rid']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
    );
  }

  @override
  $DiningTablesTable createAlias(String alias) {
    return $DiningTablesTable(attachedDatabase, alias);
  }
}

class DiningTable extends DataClass implements Insertable<DiningTable> {
  final int id;
  final String? remoteId;
  final String name;
  final String status;
  const DiningTable(
      {required this.id,
      this.remoteId,
      required this.name,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || remoteId != null) {
      map['rid'] = Variable<String>(remoteId);
    }
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    return map;
  }

  DiningTablesCompanion toCompanion(bool nullToAbsent) {
    return DiningTablesCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      name: Value(name),
      status: Value(status),
    );
  }

  factory DiningTable.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiningTable(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<String?>(remoteId),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
    };
  }

  DiningTable copyWith(
          {int? id,
          Value<String?> remoteId = const Value.absent(),
          String? name,
          String? status}) =>
      DiningTable(
        id: id ?? this.id,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        name: name ?? this.name,
        status: status ?? this.status,
      );
  DiningTable copyWithCompanion(DiningTablesCompanion data) {
    return DiningTable(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiningTable(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, remoteId, name, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiningTable &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.name == this.name &&
          other.status == this.status);
}

class DiningTablesCompanion extends UpdateCompanion<DiningTable> {
  final Value<int> id;
  final Value<String?> remoteId;
  final Value<String> name;
  final Value<String> status;
  const DiningTablesCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
  });
  DiningTablesCompanion.insert({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    required String name,
    this.status = const Value.absent(),
  }) : name = Value(name);
  static Insertable<DiningTable> custom({
    Expression<int>? id,
    Expression<String>? remoteId,
    Expression<String>? name,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'rid': remoteId,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
    });
  }

  DiningTablesCompanion copyWith(
      {Value<int>? id,
      Value<String?>? remoteId,
      Value<String>? name,
      Value<String>? status}) {
    return DiningTablesCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      name: name ?? this.name,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['rid'] = Variable<String>(remoteId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiningTablesCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $OpsJournalTable extends OpsJournal
    with TableInfo<$OpsJournalTable, OpsJournalEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OpsJournalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, kind, payload, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ops_journal';
  @override
  VerificationContext validateIntegrity(Insertable<OpsJournalEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OpsJournalEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OpsJournalEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $OpsJournalTable createAlias(String alias) {
    return $OpsJournalTable(attachedDatabase, alias);
  }
}

class OpsJournalEntry extends DataClass implements Insertable<OpsJournalEntry> {
  final int id;
  final String kind;
  final String payload;
  final DateTime createdAt;
  const OpsJournalEntry(
      {required this.id,
      required this.kind,
      required this.payload,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OpsJournalCompanion toCompanion(bool nullToAbsent) {
    return OpsJournalCompanion(
      id: Value(id),
      kind: Value(kind),
      payload: Value(payload),
      createdAt: Value(createdAt),
    );
  }

  factory OpsJournalEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OpsJournalEntry(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OpsJournalEntry copyWith(
          {int? id, String? kind, String? payload, DateTime? createdAt}) =>
      OpsJournalEntry(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
      );
  OpsJournalEntry copyWithCompanion(OpsJournalCompanion data) {
    return OpsJournalEntry(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OpsJournalEntry(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, payload, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OpsJournalEntry &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt);
}

class OpsJournalCompanion extends UpdateCompanion<OpsJournalEntry> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  const OpsJournalCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OpsJournalCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String payload,
    required DateTime createdAt,
  })  : kind = Value(kind),
        payload = Value(payload),
        createdAt = Value(createdAt);
  static Insertable<OpsJournalEntry> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OpsJournalCompanion copyWith(
      {Value<int>? id,
      Value<String>? kind,
      Value<String>? payload,
      Value<DateTime>? createdAt}) {
    return OpsJournalCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OpsJournalCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RestaurantSettingsTable extends RestaurantSettings
    with TableInfo<$RestaurantSettingsTable, RestaurantSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RestaurantSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'rid', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _tenantIdMeta =
      const VerificationMeta('tenantId');
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
      'tenant_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _logoUrlMeta =
      const VerificationMeta('logoUrl');
  @override
  late final GeneratedColumn<String> logoUrl = GeneratedColumn<String>(
      'logo_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _gstinMeta = const VerificationMeta('gstin');
  @override
  late final GeneratedColumn<String> gstin = GeneratedColumn<String>(
      'gstin', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fssaiMeta = const VerificationMeta('fssai');
  @override
  late final GeneratedColumn<String> fssai = GeneratedColumn<String>(
      'fssai', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _printFssaiOnInvoiceMeta =
      const VerificationMeta('printFssaiOnInvoice');
  @override
  late final GeneratedColumn<bool> printFssaiOnInvoice = GeneratedColumn<bool>(
      'print_fssai_on_invoice', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("print_fssai_on_invoice" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _gstInclusiveDefaultMeta =
      const VerificationMeta('gstInclusiveDefault');
  @override
  late final GeneratedColumn<bool> gstInclusiveDefault = GeneratedColumn<bool>(
      'gst_inclusive_default', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("gst_inclusive_default" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _serviceChargeModeMeta =
      const VerificationMeta('serviceChargeMode');
  @override
  late final GeneratedColumn<String> serviceChargeMode =
      GeneratedColumn<String>('service_charge_mode', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('NONE'));
  static const VerificationMeta _serviceChargeValueMeta =
      const VerificationMeta('serviceChargeValue');
  @override
  late final GeneratedColumn<double> serviceChargeValue =
      GeneratedColumn<double>('service_charge_value', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(0.0));
  static const VerificationMeta _packingChargeModeMeta =
      const VerificationMeta('packingChargeMode');
  @override
  late final GeneratedColumn<String> packingChargeMode =
      GeneratedColumn<String>('packing_charge_mode', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('NONE'));
  static const VerificationMeta _packingChargeValueMeta =
      const VerificationMeta('packingChargeValue');
  @override
  late final GeneratedColumn<double> packingChargeValue =
      GeneratedColumn<double>('packing_charge_value', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(0.0));
  static const VerificationMeta _billingPrinterIdMeta =
      const VerificationMeta('billingPrinterId');
  @override
  late final GeneratedColumn<String> billingPrinterId = GeneratedColumn<String>(
      'billing_printer_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _invoiceFooterMeta =
      const VerificationMeta('invoiceFooter');
  @override
  late final GeneratedColumn<String> invoiceFooter = GeneratedColumn<String>(
      'invoice_footer', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        remoteId,
        tenantId,
        branchId,
        name,
        logoUrl,
        address,
        phone,
        gstin,
        fssai,
        printFssaiOnInvoice,
        gstInclusiveDefault,
        serviceChargeMode,
        serviceChargeValue,
        packingChargeMode,
        packingChargeValue,
        billingPrinterId,
        invoiceFooter
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'restaurant_settings';
  @override
  VerificationContext validateIntegrity(Insertable<RestaurantSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('rid')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['rid']!, _remoteIdMeta));
    }
    if (data.containsKey('tenant_id')) {
      context.handle(_tenantIdMeta,
          tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta));
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('logo_url')) {
      context.handle(_logoUrlMeta,
          logoUrl.isAcceptableOrUnknown(data['logo_url']!, _logoUrlMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('gstin')) {
      context.handle(
          _gstinMeta, gstin.isAcceptableOrUnknown(data['gstin']!, _gstinMeta));
    }
    if (data.containsKey('fssai')) {
      context.handle(
          _fssaiMeta, fssai.isAcceptableOrUnknown(data['fssai']!, _fssaiMeta));
    }
    if (data.containsKey('print_fssai_on_invoice')) {
      context.handle(
          _printFssaiOnInvoiceMeta,
          printFssaiOnInvoice.isAcceptableOrUnknown(
              data['print_fssai_on_invoice']!, _printFssaiOnInvoiceMeta));
    }
    if (data.containsKey('gst_inclusive_default')) {
      context.handle(
          _gstInclusiveDefaultMeta,
          gstInclusiveDefault.isAcceptableOrUnknown(
              data['gst_inclusive_default']!, _gstInclusiveDefaultMeta));
    }
    if (data.containsKey('service_charge_mode')) {
      context.handle(
          _serviceChargeModeMeta,
          serviceChargeMode.isAcceptableOrUnknown(
              data['service_charge_mode']!, _serviceChargeModeMeta));
    }
    if (data.containsKey('service_charge_value')) {
      context.handle(
          _serviceChargeValueMeta,
          serviceChargeValue.isAcceptableOrUnknown(
              data['service_charge_value']!, _serviceChargeValueMeta));
    }
    if (data.containsKey('packing_charge_mode')) {
      context.handle(
          _packingChargeModeMeta,
          packingChargeMode.isAcceptableOrUnknown(
              data['packing_charge_mode']!, _packingChargeModeMeta));
    }
    if (data.containsKey('packing_charge_value')) {
      context.handle(
          _packingChargeValueMeta,
          packingChargeValue.isAcceptableOrUnknown(
              data['packing_charge_value']!, _packingChargeValueMeta));
    }
    if (data.containsKey('billing_printer_id')) {
      context.handle(
          _billingPrinterIdMeta,
          billingPrinterId.isAcceptableOrUnknown(
              data['billing_printer_id']!, _billingPrinterIdMeta));
    }
    if (data.containsKey('invoice_footer')) {
      context.handle(
          _invoiceFooterMeta,
          invoiceFooter.isAcceptableOrUnknown(
              data['invoice_footer']!, _invoiceFooterMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RestaurantSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RestaurantSetting(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rid']),
      tenantId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tenant_id']),
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      logoUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}logo_url']),
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      gstin: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gstin']),
      fssai: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fssai']),
      printFssaiOnInvoice: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}print_fssai_on_invoice'])!,
      gstInclusiveDefault: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}gst_inclusive_default'])!,
      serviceChargeMode: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}service_charge_mode'])!,
      serviceChargeValue: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}service_charge_value'])!,
      packingChargeMode: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}packing_charge_mode'])!,
      packingChargeValue: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}packing_charge_value'])!,
      billingPrinterId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}billing_printer_id']),
      invoiceFooter: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}invoice_footer']),
    );
  }

  @override
  $RestaurantSettingsTable createAlias(String alias) {
    return $RestaurantSettingsTable(attachedDatabase, alias);
  }
}

class RestaurantSetting extends DataClass
    implements Insertable<RestaurantSetting> {
  final int id;
  final String? remoteId;
  final String? tenantId;
  final String? branchId;
  final String name;
  final String? logoUrl;
  final String? address;
  final String? phone;
  final String? gstin;
  final String? fssai;
  final bool printFssaiOnInvoice;
  final bool gstInclusiveDefault;
  final String serviceChargeMode;
  final double serviceChargeValue;
  final String packingChargeMode;
  final double packingChargeValue;
  final String? billingPrinterId;
  final String? invoiceFooter;
  const RestaurantSetting(
      {required this.id,
      this.remoteId,
      this.tenantId,
      this.branchId,
      required this.name,
      this.logoUrl,
      this.address,
      this.phone,
      this.gstin,
      this.fssai,
      required this.printFssaiOnInvoice,
      required this.gstInclusiveDefault,
      required this.serviceChargeMode,
      required this.serviceChargeValue,
      required this.packingChargeMode,
      required this.packingChargeValue,
      this.billingPrinterId,
      this.invoiceFooter});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || remoteId != null) {
      map['rid'] = Variable<String>(remoteId);
    }
    if (!nullToAbsent || tenantId != null) {
      map['tenant_id'] = Variable<String>(tenantId);
    }
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<String>(branchId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || logoUrl != null) {
      map['logo_url'] = Variable<String>(logoUrl);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || gstin != null) {
      map['gstin'] = Variable<String>(gstin);
    }
    if (!nullToAbsent || fssai != null) {
      map['fssai'] = Variable<String>(fssai);
    }
    map['print_fssai_on_invoice'] = Variable<bool>(printFssaiOnInvoice);
    map['gst_inclusive_default'] = Variable<bool>(gstInclusiveDefault);
    map['service_charge_mode'] = Variable<String>(serviceChargeMode);
    map['service_charge_value'] = Variable<double>(serviceChargeValue);
    map['packing_charge_mode'] = Variable<String>(packingChargeMode);
    map['packing_charge_value'] = Variable<double>(packingChargeValue);
    if (!nullToAbsent || billingPrinterId != null) {
      map['billing_printer_id'] = Variable<String>(billingPrinterId);
    }
    if (!nullToAbsent || invoiceFooter != null) {
      map['invoice_footer'] = Variable<String>(invoiceFooter);
    }
    return map;
  }

  RestaurantSettingsCompanion toCompanion(bool nullToAbsent) {
    return RestaurantSettingsCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      tenantId: tenantId == null && nullToAbsent
          ? const Value.absent()
          : Value(tenantId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      name: Value(name),
      logoUrl: logoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(logoUrl),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      gstin:
          gstin == null && nullToAbsent ? const Value.absent() : Value(gstin),
      fssai:
          fssai == null && nullToAbsent ? const Value.absent() : Value(fssai),
      printFssaiOnInvoice: Value(printFssaiOnInvoice),
      gstInclusiveDefault: Value(gstInclusiveDefault),
      serviceChargeMode: Value(serviceChargeMode),
      serviceChargeValue: Value(serviceChargeValue),
      packingChargeMode: Value(packingChargeMode),
      packingChargeValue: Value(packingChargeValue),
      billingPrinterId: billingPrinterId == null && nullToAbsent
          ? const Value.absent()
          : Value(billingPrinterId),
      invoiceFooter: invoiceFooter == null && nullToAbsent
          ? const Value.absent()
          : Value(invoiceFooter),
    );
  }

  factory RestaurantSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RestaurantSetting(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      tenantId: serializer.fromJson<String?>(json['tenantId']),
      branchId: serializer.fromJson<String?>(json['branchId']),
      name: serializer.fromJson<String>(json['name']),
      logoUrl: serializer.fromJson<String?>(json['logoUrl']),
      address: serializer.fromJson<String?>(json['address']),
      phone: serializer.fromJson<String?>(json['phone']),
      gstin: serializer.fromJson<String?>(json['gstin']),
      fssai: serializer.fromJson<String?>(json['fssai']),
      printFssaiOnInvoice:
          serializer.fromJson<bool>(json['printFssaiOnInvoice']),
      gstInclusiveDefault:
          serializer.fromJson<bool>(json['gstInclusiveDefault']),
      serviceChargeMode: serializer.fromJson<String>(json['serviceChargeMode']),
      serviceChargeValue:
          serializer.fromJson<double>(json['serviceChargeValue']),
      packingChargeMode: serializer.fromJson<String>(json['packingChargeMode']),
      packingChargeValue:
          serializer.fromJson<double>(json['packingChargeValue']),
      billingPrinterId: serializer.fromJson<String?>(json['billingPrinterId']),
      invoiceFooter: serializer.fromJson<String?>(json['invoiceFooter']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<String?>(remoteId),
      'tenantId': serializer.toJson<String?>(tenantId),
      'branchId': serializer.toJson<String?>(branchId),
      'name': serializer.toJson<String>(name),
      'logoUrl': serializer.toJson<String?>(logoUrl),
      'address': serializer.toJson<String?>(address),
      'phone': serializer.toJson<String?>(phone),
      'gstin': serializer.toJson<String?>(gstin),
      'fssai': serializer.toJson<String?>(fssai),
      'printFssaiOnInvoice': serializer.toJson<bool>(printFssaiOnInvoice),
      'gstInclusiveDefault': serializer.toJson<bool>(gstInclusiveDefault),
      'serviceChargeMode': serializer.toJson<String>(serviceChargeMode),
      'serviceChargeValue': serializer.toJson<double>(serviceChargeValue),
      'packingChargeMode': serializer.toJson<String>(packingChargeMode),
      'packingChargeValue': serializer.toJson<double>(packingChargeValue),
      'billingPrinterId': serializer.toJson<String?>(billingPrinterId),
      'invoiceFooter': serializer.toJson<String?>(invoiceFooter),
    };
  }

  RestaurantSetting copyWith(
          {int? id,
          Value<String?> remoteId = const Value.absent(),
          Value<String?> tenantId = const Value.absent(),
          Value<String?> branchId = const Value.absent(),
          String? name,
          Value<String?> logoUrl = const Value.absent(),
          Value<String?> address = const Value.absent(),
          Value<String?> phone = const Value.absent(),
          Value<String?> gstin = const Value.absent(),
          Value<String?> fssai = const Value.absent(),
          bool? printFssaiOnInvoice,
          bool? gstInclusiveDefault,
          String? serviceChargeMode,
          double? serviceChargeValue,
          String? packingChargeMode,
          double? packingChargeValue,
          Value<String?> billingPrinterId = const Value.absent(),
          Value<String?> invoiceFooter = const Value.absent()}) =>
      RestaurantSetting(
        id: id ?? this.id,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        tenantId: tenantId.present ? tenantId.value : this.tenantId,
        branchId: branchId.present ? branchId.value : this.branchId,
        name: name ?? this.name,
        logoUrl: logoUrl.present ? logoUrl.value : this.logoUrl,
        address: address.present ? address.value : this.address,
        phone: phone.present ? phone.value : this.phone,
        gstin: gstin.present ? gstin.value : this.gstin,
        fssai: fssai.present ? fssai.value : this.fssai,
        printFssaiOnInvoice: printFssaiOnInvoice ?? this.printFssaiOnInvoice,
        gstInclusiveDefault: gstInclusiveDefault ?? this.gstInclusiveDefault,
        serviceChargeMode: serviceChargeMode ?? this.serviceChargeMode,
        serviceChargeValue: serviceChargeValue ?? this.serviceChargeValue,
        packingChargeMode: packingChargeMode ?? this.packingChargeMode,
        packingChargeValue: packingChargeValue ?? this.packingChargeValue,
        billingPrinterId: billingPrinterId.present
            ? billingPrinterId.value
            : this.billingPrinterId,
        invoiceFooter:
            invoiceFooter.present ? invoiceFooter.value : this.invoiceFooter,
      );
  RestaurantSetting copyWithCompanion(RestaurantSettingsCompanion data) {
    return RestaurantSetting(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      name: data.name.present ? data.name.value : this.name,
      logoUrl: data.logoUrl.present ? data.logoUrl.value : this.logoUrl,
      address: data.address.present ? data.address.value : this.address,
      phone: data.phone.present ? data.phone.value : this.phone,
      gstin: data.gstin.present ? data.gstin.value : this.gstin,
      fssai: data.fssai.present ? data.fssai.value : this.fssai,
      printFssaiOnInvoice: data.printFssaiOnInvoice.present
          ? data.printFssaiOnInvoice.value
          : this.printFssaiOnInvoice,
      gstInclusiveDefault: data.gstInclusiveDefault.present
          ? data.gstInclusiveDefault.value
          : this.gstInclusiveDefault,
      serviceChargeMode: data.serviceChargeMode.present
          ? data.serviceChargeMode.value
          : this.serviceChargeMode,
      serviceChargeValue: data.serviceChargeValue.present
          ? data.serviceChargeValue.value
          : this.serviceChargeValue,
      packingChargeMode: data.packingChargeMode.present
          ? data.packingChargeMode.value
          : this.packingChargeMode,
      packingChargeValue: data.packingChargeValue.present
          ? data.packingChargeValue.value
          : this.packingChargeValue,
      billingPrinterId: data.billingPrinterId.present
          ? data.billingPrinterId.value
          : this.billingPrinterId,
      invoiceFooter: data.invoiceFooter.present
          ? data.invoiceFooter.value
          : this.invoiceFooter,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RestaurantSetting(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('tenantId: $tenantId, ')
          ..write('branchId: $branchId, ')
          ..write('name: $name, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('address: $address, ')
          ..write('phone: $phone, ')
          ..write('gstin: $gstin, ')
          ..write('fssai: $fssai, ')
          ..write('printFssaiOnInvoice: $printFssaiOnInvoice, ')
          ..write('gstInclusiveDefault: $gstInclusiveDefault, ')
          ..write('serviceChargeMode: $serviceChargeMode, ')
          ..write('serviceChargeValue: $serviceChargeValue, ')
          ..write('packingChargeMode: $packingChargeMode, ')
          ..write('packingChargeValue: $packingChargeValue, ')
          ..write('billingPrinterId: $billingPrinterId, ')
          ..write('invoiceFooter: $invoiceFooter')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      remoteId,
      tenantId,
      branchId,
      name,
      logoUrl,
      address,
      phone,
      gstin,
      fssai,
      printFssaiOnInvoice,
      gstInclusiveDefault,
      serviceChargeMode,
      serviceChargeValue,
      packingChargeMode,
      packingChargeValue,
      billingPrinterId,
      invoiceFooter);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RestaurantSetting &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.tenantId == this.tenantId &&
          other.branchId == this.branchId &&
          other.name == this.name &&
          other.logoUrl == this.logoUrl &&
          other.address == this.address &&
          other.phone == this.phone &&
          other.gstin == this.gstin &&
          other.fssai == this.fssai &&
          other.printFssaiOnInvoice == this.printFssaiOnInvoice &&
          other.gstInclusiveDefault == this.gstInclusiveDefault &&
          other.serviceChargeMode == this.serviceChargeMode &&
          other.serviceChargeValue == this.serviceChargeValue &&
          other.packingChargeMode == this.packingChargeMode &&
          other.packingChargeValue == this.packingChargeValue &&
          other.billingPrinterId == this.billingPrinterId &&
          other.invoiceFooter == this.invoiceFooter);
}

class RestaurantSettingsCompanion extends UpdateCompanion<RestaurantSetting> {
  final Value<int> id;
  final Value<String?> remoteId;
  final Value<String?> tenantId;
  final Value<String?> branchId;
  final Value<String> name;
  final Value<String?> logoUrl;
  final Value<String?> address;
  final Value<String?> phone;
  final Value<String?> gstin;
  final Value<String?> fssai;
  final Value<bool> printFssaiOnInvoice;
  final Value<bool> gstInclusiveDefault;
  final Value<String> serviceChargeMode;
  final Value<double> serviceChargeValue;
  final Value<String> packingChargeMode;
  final Value<double> packingChargeValue;
  final Value<String?> billingPrinterId;
  final Value<String?> invoiceFooter;
  const RestaurantSettingsCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.name = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.address = const Value.absent(),
    this.phone = const Value.absent(),
    this.gstin = const Value.absent(),
    this.fssai = const Value.absent(),
    this.printFssaiOnInvoice = const Value.absent(),
    this.gstInclusiveDefault = const Value.absent(),
    this.serviceChargeMode = const Value.absent(),
    this.serviceChargeValue = const Value.absent(),
    this.packingChargeMode = const Value.absent(),
    this.packingChargeValue = const Value.absent(),
    this.billingPrinterId = const Value.absent(),
    this.invoiceFooter = const Value.absent(),
  });
  RestaurantSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.name = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.address = const Value.absent(),
    this.phone = const Value.absent(),
    this.gstin = const Value.absent(),
    this.fssai = const Value.absent(),
    this.printFssaiOnInvoice = const Value.absent(),
    this.gstInclusiveDefault = const Value.absent(),
    this.serviceChargeMode = const Value.absent(),
    this.serviceChargeValue = const Value.absent(),
    this.packingChargeMode = const Value.absent(),
    this.packingChargeValue = const Value.absent(),
    this.billingPrinterId = const Value.absent(),
    this.invoiceFooter = const Value.absent(),
  });
  static Insertable<RestaurantSetting> custom({
    Expression<int>? id,
    Expression<String>? remoteId,
    Expression<String>? tenantId,
    Expression<String>? branchId,
    Expression<String>? name,
    Expression<String>? logoUrl,
    Expression<String>? address,
    Expression<String>? phone,
    Expression<String>? gstin,
    Expression<String>? fssai,
    Expression<bool>? printFssaiOnInvoice,
    Expression<bool>? gstInclusiveDefault,
    Expression<String>? serviceChargeMode,
    Expression<double>? serviceChargeValue,
    Expression<String>? packingChargeMode,
    Expression<double>? packingChargeValue,
    Expression<String>? billingPrinterId,
    Expression<String>? invoiceFooter,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'rid': remoteId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (branchId != null) 'branch_id': branchId,
      if (name != null) 'name': name,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (gstin != null) 'gstin': gstin,
      if (fssai != null) 'fssai': fssai,
      if (printFssaiOnInvoice != null)
        'print_fssai_on_invoice': printFssaiOnInvoice,
      if (gstInclusiveDefault != null)
        'gst_inclusive_default': gstInclusiveDefault,
      if (serviceChargeMode != null) 'service_charge_mode': serviceChargeMode,
      if (serviceChargeValue != null)
        'service_charge_value': serviceChargeValue,
      if (packingChargeMode != null) 'packing_charge_mode': packingChargeMode,
      if (packingChargeValue != null)
        'packing_charge_value': packingChargeValue,
      if (billingPrinterId != null) 'billing_printer_id': billingPrinterId,
      if (invoiceFooter != null) 'invoice_footer': invoiceFooter,
    });
  }

  RestaurantSettingsCompanion copyWith(
      {Value<int>? id,
      Value<String?>? remoteId,
      Value<String?>? tenantId,
      Value<String?>? branchId,
      Value<String>? name,
      Value<String?>? logoUrl,
      Value<String?>? address,
      Value<String?>? phone,
      Value<String?>? gstin,
      Value<String?>? fssai,
      Value<bool>? printFssaiOnInvoice,
      Value<bool>? gstInclusiveDefault,
      Value<String>? serviceChargeMode,
      Value<double>? serviceChargeValue,
      Value<String>? packingChargeMode,
      Value<double>? packingChargeValue,
      Value<String?>? billingPrinterId,
      Value<String?>? invoiceFooter}) {
    return RestaurantSettingsCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      tenantId: tenantId ?? this.tenantId,
      branchId: branchId ?? this.branchId,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      gstin: gstin ?? this.gstin,
      fssai: fssai ?? this.fssai,
      printFssaiOnInvoice: printFssaiOnInvoice ?? this.printFssaiOnInvoice,
      gstInclusiveDefault: gstInclusiveDefault ?? this.gstInclusiveDefault,
      serviceChargeMode: serviceChargeMode ?? this.serviceChargeMode,
      serviceChargeValue: serviceChargeValue ?? this.serviceChargeValue,
      packingChargeMode: packingChargeMode ?? this.packingChargeMode,
      packingChargeValue: packingChargeValue ?? this.packingChargeValue,
      billingPrinterId: billingPrinterId ?? this.billingPrinterId,
      invoiceFooter: invoiceFooter ?? this.invoiceFooter,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['rid'] = Variable<String>(remoteId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (logoUrl.present) {
      map['logo_url'] = Variable<String>(logoUrl.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (gstin.present) {
      map['gstin'] = Variable<String>(gstin.value);
    }
    if (fssai.present) {
      map['fssai'] = Variable<String>(fssai.value);
    }
    if (printFssaiOnInvoice.present) {
      map['print_fssai_on_invoice'] = Variable<bool>(printFssaiOnInvoice.value);
    }
    if (gstInclusiveDefault.present) {
      map['gst_inclusive_default'] = Variable<bool>(gstInclusiveDefault.value);
    }
    if (serviceChargeMode.present) {
      map['service_charge_mode'] = Variable<String>(serviceChargeMode.value);
    }
    if (serviceChargeValue.present) {
      map['service_charge_value'] = Variable<double>(serviceChargeValue.value);
    }
    if (packingChargeMode.present) {
      map['packing_charge_mode'] = Variable<String>(packingChargeMode.value);
    }
    if (packingChargeValue.present) {
      map['packing_charge_value'] = Variable<double>(packingChargeValue.value);
    }
    if (billingPrinterId.present) {
      map['billing_printer_id'] = Variable<String>(billingPrinterId.value);
    }
    if (invoiceFooter.present) {
      map['invoice_footer'] = Variable<String>(invoiceFooter.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RestaurantSettingsCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('tenantId: $tenantId, ')
          ..write('branchId: $branchId, ')
          ..write('name: $name, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('address: $address, ')
          ..write('phone: $phone, ')
          ..write('gstin: $gstin, ')
          ..write('fssai: $fssai, ')
          ..write('printFssaiOnInvoice: $printFssaiOnInvoice, ')
          ..write('gstInclusiveDefault: $gstInclusiveDefault, ')
          ..write('serviceChargeMode: $serviceChargeMode, ')
          ..write('serviceChargeValue: $serviceChargeValue, ')
          ..write('packingChargeMode: $packingChargeMode, ')
          ..write('packingChargeValue: $packingChargeValue, ')
          ..write('billingPrinterId: $billingPrinterId, ')
          ..write('invoiceFooter: $invoiceFooter')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MenuCategoriesTable menuCategories = $MenuCategoriesTable(this);
  late final $MenuItemsTable menuItems = $MenuItemsTable(this);
  late final $ItemVariantsTable itemVariants = $ItemVariantsTable(this);
  late final $DiningTablesTable diningTables = $DiningTablesTable(this);
  late final $OpsJournalTable opsJournal = $OpsJournalTable(this);
  late final $RestaurantSettingsTable restaurantSettings =
      $RestaurantSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        menuCategories,
        menuItems,
        itemVariants,
        diningTables,
        opsJournal,
        restaurantSettings
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('menu_categories',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('menu_items', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('menu_items',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('item_variants', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$MenuCategoriesTableCreateCompanionBuilder = MenuCategoriesCompanion
    Function({
  Value<int> id,
  Value<String?> remoteId,
  required String name,
  Value<int> position,
});
typedef $$MenuCategoriesTableUpdateCompanionBuilder = MenuCategoriesCompanion
    Function({
  Value<int> id,
  Value<String?> remoteId,
  Value<String> name,
  Value<int> position,
});

final class $$MenuCategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $MenuCategoriesTable, MenuCategory> {
  $$MenuCategoriesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MenuItemsTable, List<MenuItem>>
      _menuItemsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.menuItems,
              aliasName: $_aliasNameGenerator(
                  db.menuCategories.id, db.menuItems.categoryId));

  $$MenuItemsTableProcessedTableManager get menuItemsRefs {
    final manager = $$MenuItemsTableTableManager($_db, $_db.menuItems)
        .filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_menuItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$MenuCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $MenuCategoriesTable> {
  $$MenuCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  Expression<bool> menuItemsRefs(
      Expression<bool> Function($$MenuItemsTableFilterComposer f) f) {
    final $$MenuItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.menuItems,
        getReferencedColumn: (t) => t.categoryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MenuItemsTableFilterComposer(
              $db: $db,
              $table: $db.menuItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$MenuCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MenuCategoriesTable> {
  $$MenuCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));
}

class $$MenuCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MenuCategoriesTable> {
  $$MenuCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  Expression<T> menuItemsRefs<T extends Object>(
      Expression<T> Function($$MenuItemsTableAnnotationComposer a) f) {
    final $$MenuItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.menuItems,
        getReferencedColumn: (t) => t.categoryId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MenuItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.menuItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$MenuCategoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MenuCategoriesTable,
    MenuCategory,
    $$MenuCategoriesTableFilterComposer,
    $$MenuCategoriesTableOrderingComposer,
    $$MenuCategoriesTableAnnotationComposer,
    $$MenuCategoriesTableCreateCompanionBuilder,
    $$MenuCategoriesTableUpdateCompanionBuilder,
    (MenuCategory, $$MenuCategoriesTableReferences),
    MenuCategory,
    PrefetchHooks Function({bool menuItemsRefs})> {
  $$MenuCategoriesTableTableManager(
      _$AppDatabase db, $MenuCategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MenuCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MenuCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MenuCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> position = const Value.absent(),
          }) =>
              MenuCategoriesCompanion(
            id: id,
            remoteId: remoteId,
            name: name,
            position: position,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            required String name,
            Value<int> position = const Value.absent(),
          }) =>
              MenuCategoriesCompanion.insert(
            id: id,
            remoteId: remoteId,
            name: name,
            position: position,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$MenuCategoriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({menuItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (menuItemsRefs) db.menuItems],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (menuItemsRefs)
                    await $_getPrefetchedData<MenuCategory,
                            $MenuCategoriesTable, MenuItem>(
                        currentTable: table,
                        referencedTable: $$MenuCategoriesTableReferences
                            ._menuItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$MenuCategoriesTableReferences(db, table, p0)
                                .menuItemsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.categoryId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$MenuCategoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MenuCategoriesTable,
    MenuCategory,
    $$MenuCategoriesTableFilterComposer,
    $$MenuCategoriesTableOrderingComposer,
    $$MenuCategoriesTableAnnotationComposer,
    $$MenuCategoriesTableCreateCompanionBuilder,
    $$MenuCategoriesTableUpdateCompanionBuilder,
    (MenuCategory, $$MenuCategoriesTableReferences),
    MenuCategory,
    PrefetchHooks Function({bool menuItemsRefs})>;
typedef $$MenuItemsTableCreateCompanionBuilder = MenuItemsCompanion Function({
  Value<int> id,
  Value<String?> remoteId,
  required int categoryId,
  required String name,
  Value<String?> description,
  Value<String?> sku,
  Value<String?> hsn,
  Value<bool> isActive,
  Value<bool> stockOut,
  Value<bool> taxInclusive,
  Value<double> gstRate,
  Value<String?> kitchenStationId,
  Value<String?> imageUrl,
});
typedef $$MenuItemsTableUpdateCompanionBuilder = MenuItemsCompanion Function({
  Value<int> id,
  Value<String?> remoteId,
  Value<int> categoryId,
  Value<String> name,
  Value<String?> description,
  Value<String?> sku,
  Value<String?> hsn,
  Value<bool> isActive,
  Value<bool> stockOut,
  Value<bool> taxInclusive,
  Value<double> gstRate,
  Value<String?> kitchenStationId,
  Value<String?> imageUrl,
});

final class $$MenuItemsTableReferences
    extends BaseReferences<_$AppDatabase, $MenuItemsTable, MenuItem> {
  $$MenuItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MenuCategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.menuCategories.createAlias(
          $_aliasNameGenerator(db.menuItems.categoryId, db.menuCategories.id));

  $$MenuCategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$MenuCategoriesTableTableManager($_db, $_db.menuCategories)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$ItemVariantsTable, List<ItemVariant>>
      _itemVariantsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.itemVariants,
          aliasName:
              $_aliasNameGenerator(db.menuItems.id, db.itemVariants.itemId));

  $$ItemVariantsTableProcessedTableManager get itemVariantsRefs {
    final manager = $$ItemVariantsTableTableManager($_db, $_db.itemVariants)
        .filter((f) => f.itemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemVariantsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$MenuItemsTableFilterComposer
    extends Composer<_$AppDatabase, $MenuItemsTable> {
  $$MenuItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hsn => $composableBuilder(
      column: $table.hsn, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get stockOut => $composableBuilder(
      column: $table.stockOut, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get taxInclusive => $composableBuilder(
      column: $table.taxInclusive, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get gstRate => $composableBuilder(
      column: $table.gstRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kitchenStationId => $composableBuilder(
      column: $table.kitchenStationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  $$MenuCategoriesTableFilterComposer get categoryId {
    final $$MenuCategoriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.menuCategories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MenuCategoriesTableFilterComposer(
              $db: $db,
              $table: $db.menuCategories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> itemVariantsRefs(
      Expression<bool> Function($$ItemVariantsTableFilterComposer f) f) {
    final $$ItemVariantsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.itemVariants,
        getReferencedColumn: (t) => t.itemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemVariantsTableFilterComposer(
              $db: $db,
              $table: $db.itemVariants,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$MenuItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $MenuItemsTable> {
  $$MenuItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hsn => $composableBuilder(
      column: $table.hsn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get stockOut => $composableBuilder(
      column: $table.stockOut, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get taxInclusive => $composableBuilder(
      column: $table.taxInclusive,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get gstRate => $composableBuilder(
      column: $table.gstRate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kitchenStationId => $composableBuilder(
      column: $table.kitchenStationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  $$MenuCategoriesTableOrderingComposer get categoryId {
    final $$MenuCategoriesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.menuCategories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MenuCategoriesTableOrderingComposer(
              $db: $db,
              $table: $db.menuCategories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MenuItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MenuItemsTable> {
  $$MenuItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get hsn =>
      $composableBuilder(column: $table.hsn, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get stockOut =>
      $composableBuilder(column: $table.stockOut, builder: (column) => column);

  GeneratedColumn<bool> get taxInclusive => $composableBuilder(
      column: $table.taxInclusive, builder: (column) => column);

  GeneratedColumn<double> get gstRate =>
      $composableBuilder(column: $table.gstRate, builder: (column) => column);

  GeneratedColumn<String> get kitchenStationId => $composableBuilder(
      column: $table.kitchenStationId, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  $$MenuCategoriesTableAnnotationComposer get categoryId {
    final $$MenuCategoriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $db.menuCategories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MenuCategoriesTableAnnotationComposer(
              $db: $db,
              $table: $db.menuCategories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> itemVariantsRefs<T extends Object>(
      Expression<T> Function($$ItemVariantsTableAnnotationComposer a) f) {
    final $$ItemVariantsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.itemVariants,
        getReferencedColumn: (t) => t.itemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ItemVariantsTableAnnotationComposer(
              $db: $db,
              $table: $db.itemVariants,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$MenuItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MenuItemsTable,
    MenuItem,
    $$MenuItemsTableFilterComposer,
    $$MenuItemsTableOrderingComposer,
    $$MenuItemsTableAnnotationComposer,
    $$MenuItemsTableCreateCompanionBuilder,
    $$MenuItemsTableUpdateCompanionBuilder,
    (MenuItem, $$MenuItemsTableReferences),
    MenuItem,
    PrefetchHooks Function({bool categoryId, bool itemVariantsRefs})> {
  $$MenuItemsTableTableManager(_$AppDatabase db, $MenuItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MenuItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MenuItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MenuItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> categoryId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> sku = const Value.absent(),
            Value<String?> hsn = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<bool> stockOut = const Value.absent(),
            Value<bool> taxInclusive = const Value.absent(),
            Value<double> gstRate = const Value.absent(),
            Value<String?> kitchenStationId = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
          }) =>
              MenuItemsCompanion(
            id: id,
            remoteId: remoteId,
            categoryId: categoryId,
            name: name,
            description: description,
            sku: sku,
            hsn: hsn,
            isActive: isActive,
            stockOut: stockOut,
            taxInclusive: taxInclusive,
            gstRate: gstRate,
            kitchenStationId: kitchenStationId,
            imageUrl: imageUrl,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            required int categoryId,
            required String name,
            Value<String?> description = const Value.absent(),
            Value<String?> sku = const Value.absent(),
            Value<String?> hsn = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<bool> stockOut = const Value.absent(),
            Value<bool> taxInclusive = const Value.absent(),
            Value<double> gstRate = const Value.absent(),
            Value<String?> kitchenStationId = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
          }) =>
              MenuItemsCompanion.insert(
            id: id,
            remoteId: remoteId,
            categoryId: categoryId,
            name: name,
            description: description,
            sku: sku,
            hsn: hsn,
            isActive: isActive,
            stockOut: stockOut,
            taxInclusive: taxInclusive,
            gstRate: gstRate,
            kitchenStationId: kitchenStationId,
            imageUrl: imageUrl,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$MenuItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {categoryId = false, itemVariantsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (itemVariantsRefs) db.itemVariants],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (categoryId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.categoryId,
                    referencedTable:
                        $$MenuItemsTableReferences._categoryIdTable(db),
                    referencedColumn:
                        $$MenuItemsTableReferences._categoryIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itemVariantsRefs)
                    await $_getPrefetchedData<MenuItem, $MenuItemsTable,
                            ItemVariant>(
                        currentTable: table,
                        referencedTable: $$MenuItemsTableReferences
                            ._itemVariantsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$MenuItemsTableReferences(db, table, p0)
                                .itemVariantsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.itemId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$MenuItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MenuItemsTable,
    MenuItem,
    $$MenuItemsTableFilterComposer,
    $$MenuItemsTableOrderingComposer,
    $$MenuItemsTableAnnotationComposer,
    $$MenuItemsTableCreateCompanionBuilder,
    $$MenuItemsTableUpdateCompanionBuilder,
    (MenuItem, $$MenuItemsTableReferences),
    MenuItem,
    PrefetchHooks Function({bool categoryId, bool itemVariantsRefs})>;
typedef $$ItemVariantsTableCreateCompanionBuilder = ItemVariantsCompanion
    Function({
  Value<int> id,
  Value<String?> remoteId,
  required int itemId,
  required String label,
  Value<double?> mrp,
  required double basePrice,
  Value<bool> isDefault,
  Value<String?> imageUrl,
});
typedef $$ItemVariantsTableUpdateCompanionBuilder = ItemVariantsCompanion
    Function({
  Value<int> id,
  Value<String?> remoteId,
  Value<int> itemId,
  Value<String> label,
  Value<double?> mrp,
  Value<double> basePrice,
  Value<bool> isDefault,
  Value<String?> imageUrl,
});

final class $$ItemVariantsTableReferences
    extends BaseReferences<_$AppDatabase, $ItemVariantsTable, ItemVariant> {
  $$ItemVariantsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MenuItemsTable _itemIdTable(_$AppDatabase db) =>
      db.menuItems.createAlias(
          $_aliasNameGenerator(db.itemVariants.itemId, db.menuItems.id));

  $$MenuItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<int>('item_id')!;

    final manager = $$MenuItemsTableTableManager($_db, $_db.menuItems)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ItemVariantsTableFilterComposer
    extends Composer<_$AppDatabase, $ItemVariantsTable> {
  $$ItemVariantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get mrp => $composableBuilder(
      column: $table.mrp, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get basePrice => $composableBuilder(
      column: $table.basePrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  $$MenuItemsTableFilterComposer get itemId {
    final $$MenuItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.menuItems,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MenuItemsTableFilterComposer(
              $db: $db,
              $table: $db.menuItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ItemVariantsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemVariantsTable> {
  $$ItemVariantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get mrp => $composableBuilder(
      column: $table.mrp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get basePrice => $composableBuilder(
      column: $table.basePrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  $$MenuItemsTableOrderingComposer get itemId {
    final $$MenuItemsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.menuItems,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MenuItemsTableOrderingComposer(
              $db: $db,
              $table: $db.menuItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ItemVariantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemVariantsTable> {
  $$ItemVariantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<double> get mrp =>
      $composableBuilder(column: $table.mrp, builder: (column) => column);

  GeneratedColumn<double> get basePrice =>
      $composableBuilder(column: $table.basePrice, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  $$MenuItemsTableAnnotationComposer get itemId {
    final $$MenuItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.itemId,
        referencedTable: $db.menuItems,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MenuItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.menuItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ItemVariantsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ItemVariantsTable,
    ItemVariant,
    $$ItemVariantsTableFilterComposer,
    $$ItemVariantsTableOrderingComposer,
    $$ItemVariantsTableAnnotationComposer,
    $$ItemVariantsTableCreateCompanionBuilder,
    $$ItemVariantsTableUpdateCompanionBuilder,
    (ItemVariant, $$ItemVariantsTableReferences),
    ItemVariant,
    PrefetchHooks Function({bool itemId})> {
  $$ItemVariantsTableTableManager(_$AppDatabase db, $ItemVariantsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemVariantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemVariantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemVariantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> itemId = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<double?> mrp = const Value.absent(),
            Value<double> basePrice = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
          }) =>
              ItemVariantsCompanion(
            id: id,
            remoteId: remoteId,
            itemId: itemId,
            label: label,
            mrp: mrp,
            basePrice: basePrice,
            isDefault: isDefault,
            imageUrl: imageUrl,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            required int itemId,
            required String label,
            Value<double?> mrp = const Value.absent(),
            required double basePrice,
            Value<bool> isDefault = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
          }) =>
              ItemVariantsCompanion.insert(
            id: id,
            remoteId: remoteId,
            itemId: itemId,
            label: label,
            mrp: mrp,
            basePrice: basePrice,
            isDefault: isDefault,
            imageUrl: imageUrl,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ItemVariantsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (itemId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.itemId,
                    referencedTable:
                        $$ItemVariantsTableReferences._itemIdTable(db),
                    referencedColumn:
                        $$ItemVariantsTableReferences._itemIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ItemVariantsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ItemVariantsTable,
    ItemVariant,
    $$ItemVariantsTableFilterComposer,
    $$ItemVariantsTableOrderingComposer,
    $$ItemVariantsTableAnnotationComposer,
    $$ItemVariantsTableCreateCompanionBuilder,
    $$ItemVariantsTableUpdateCompanionBuilder,
    (ItemVariant, $$ItemVariantsTableReferences),
    ItemVariant,
    PrefetchHooks Function({bool itemId})>;
typedef $$DiningTablesTableCreateCompanionBuilder = DiningTablesCompanion
    Function({
  Value<int> id,
  Value<String?> remoteId,
  required String name,
  Value<String> status,
});
typedef $$DiningTablesTableUpdateCompanionBuilder = DiningTablesCompanion
    Function({
  Value<int> id,
  Value<String?> remoteId,
  Value<String> name,
  Value<String> status,
});

class $$DiningTablesTableFilterComposer
    extends Composer<_$AppDatabase, $DiningTablesTable> {
  $$DiningTablesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));
}

class $$DiningTablesTableOrderingComposer
    extends Composer<_$AppDatabase, $DiningTablesTable> {
  $$DiningTablesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));
}

class $$DiningTablesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiningTablesTable> {
  $$DiningTablesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$DiningTablesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DiningTablesTable,
    DiningTable,
    $$DiningTablesTableFilterComposer,
    $$DiningTablesTableOrderingComposer,
    $$DiningTablesTableAnnotationComposer,
    $$DiningTablesTableCreateCompanionBuilder,
    $$DiningTablesTableUpdateCompanionBuilder,
    (
      DiningTable,
      BaseReferences<_$AppDatabase, $DiningTablesTable, DiningTable>
    ),
    DiningTable,
    PrefetchHooks Function()> {
  $$DiningTablesTableTableManager(_$AppDatabase db, $DiningTablesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiningTablesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiningTablesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiningTablesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> status = const Value.absent(),
          }) =>
              DiningTablesCompanion(
            id: id,
            remoteId: remoteId,
            name: name,
            status: status,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            required String name,
            Value<String> status = const Value.absent(),
          }) =>
              DiningTablesCompanion.insert(
            id: id,
            remoteId: remoteId,
            name: name,
            status: status,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DiningTablesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DiningTablesTable,
    DiningTable,
    $$DiningTablesTableFilterComposer,
    $$DiningTablesTableOrderingComposer,
    $$DiningTablesTableAnnotationComposer,
    $$DiningTablesTableCreateCompanionBuilder,
    $$DiningTablesTableUpdateCompanionBuilder,
    (
      DiningTable,
      BaseReferences<_$AppDatabase, $DiningTablesTable, DiningTable>
    ),
    DiningTable,
    PrefetchHooks Function()>;
typedef $$OpsJournalTableCreateCompanionBuilder = OpsJournalCompanion Function({
  Value<int> id,
  required String kind,
  required String payload,
  required DateTime createdAt,
});
typedef $$OpsJournalTableUpdateCompanionBuilder = OpsJournalCompanion Function({
  Value<int> id,
  Value<String> kind,
  Value<String> payload,
  Value<DateTime> createdAt,
});

class $$OpsJournalTableFilterComposer
    extends Composer<_$AppDatabase, $OpsJournalTable> {
  $$OpsJournalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$OpsJournalTableOrderingComposer
    extends Composer<_$AppDatabase, $OpsJournalTable> {
  $$OpsJournalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$OpsJournalTableAnnotationComposer
    extends Composer<_$AppDatabase, $OpsJournalTable> {
  $$OpsJournalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OpsJournalTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OpsJournalTable,
    OpsJournalEntry,
    $$OpsJournalTableFilterComposer,
    $$OpsJournalTableOrderingComposer,
    $$OpsJournalTableAnnotationComposer,
    $$OpsJournalTableCreateCompanionBuilder,
    $$OpsJournalTableUpdateCompanionBuilder,
    (
      OpsJournalEntry,
      BaseReferences<_$AppDatabase, $OpsJournalTable, OpsJournalEntry>
    ),
    OpsJournalEntry,
    PrefetchHooks Function()> {
  $$OpsJournalTableTableManager(_$AppDatabase db, $OpsJournalTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OpsJournalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OpsJournalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OpsJournalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              OpsJournalCompanion(
            id: id,
            kind: kind,
            payload: payload,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String kind,
            required String payload,
            required DateTime createdAt,
          }) =>
              OpsJournalCompanion.insert(
            id: id,
            kind: kind,
            payload: payload,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OpsJournalTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OpsJournalTable,
    OpsJournalEntry,
    $$OpsJournalTableFilterComposer,
    $$OpsJournalTableOrderingComposer,
    $$OpsJournalTableAnnotationComposer,
    $$OpsJournalTableCreateCompanionBuilder,
    $$OpsJournalTableUpdateCompanionBuilder,
    (
      OpsJournalEntry,
      BaseReferences<_$AppDatabase, $OpsJournalTable, OpsJournalEntry>
    ),
    OpsJournalEntry,
    PrefetchHooks Function()>;
typedef $$RestaurantSettingsTableCreateCompanionBuilder
    = RestaurantSettingsCompanion Function({
  Value<int> id,
  Value<String?> remoteId,
  Value<String?> tenantId,
  Value<String?> branchId,
  Value<String> name,
  Value<String?> logoUrl,
  Value<String?> address,
  Value<String?> phone,
  Value<String?> gstin,
  Value<String?> fssai,
  Value<bool> printFssaiOnInvoice,
  Value<bool> gstInclusiveDefault,
  Value<String> serviceChargeMode,
  Value<double> serviceChargeValue,
  Value<String> packingChargeMode,
  Value<double> packingChargeValue,
  Value<String?> billingPrinterId,
  Value<String?> invoiceFooter,
});
typedef $$RestaurantSettingsTableUpdateCompanionBuilder
    = RestaurantSettingsCompanion Function({
  Value<int> id,
  Value<String?> remoteId,
  Value<String?> tenantId,
  Value<String?> branchId,
  Value<String> name,
  Value<String?> logoUrl,
  Value<String?> address,
  Value<String?> phone,
  Value<String?> gstin,
  Value<String?> fssai,
  Value<bool> printFssaiOnInvoice,
  Value<bool> gstInclusiveDefault,
  Value<String> serviceChargeMode,
  Value<double> serviceChargeValue,
  Value<String> packingChargeMode,
  Value<double> packingChargeValue,
  Value<String?> billingPrinterId,
  Value<String?> invoiceFooter,
});

class $$RestaurantSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $RestaurantSettingsTable> {
  $$RestaurantSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get logoUrl => $composableBuilder(
      column: $table.logoUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gstin => $composableBuilder(
      column: $table.gstin, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fssai => $composableBuilder(
      column: $table.fssai, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get printFssaiOnInvoice => $composableBuilder(
      column: $table.printFssaiOnInvoice,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get gstInclusiveDefault => $composableBuilder(
      column: $table.gstInclusiveDefault,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serviceChargeMode => $composableBuilder(
      column: $table.serviceChargeMode,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get serviceChargeValue => $composableBuilder(
      column: $table.serviceChargeValue,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get packingChargeMode => $composableBuilder(
      column: $table.packingChargeMode,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get packingChargeValue => $composableBuilder(
      column: $table.packingChargeValue,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get billingPrinterId => $composableBuilder(
      column: $table.billingPrinterId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get invoiceFooter => $composableBuilder(
      column: $table.invoiceFooter, builder: (column) => ColumnFilters(column));
}

class $$RestaurantSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $RestaurantSettingsTable> {
  $$RestaurantSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get logoUrl => $composableBuilder(
      column: $table.logoUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gstin => $composableBuilder(
      column: $table.gstin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fssai => $composableBuilder(
      column: $table.fssai, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get printFssaiOnInvoice => $composableBuilder(
      column: $table.printFssaiOnInvoice,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get gstInclusiveDefault => $composableBuilder(
      column: $table.gstInclusiveDefault,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serviceChargeMode => $composableBuilder(
      column: $table.serviceChargeMode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get serviceChargeValue => $composableBuilder(
      column: $table.serviceChargeValue,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get packingChargeMode => $composableBuilder(
      column: $table.packingChargeMode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get packingChargeValue => $composableBuilder(
      column: $table.packingChargeValue,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get billingPrinterId => $composableBuilder(
      column: $table.billingPrinterId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get invoiceFooter => $composableBuilder(
      column: $table.invoiceFooter,
      builder: (column) => ColumnOrderings(column));
}

class $$RestaurantSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RestaurantSettingsTable> {
  $$RestaurantSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get logoUrl =>
      $composableBuilder(column: $table.logoUrl, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get gstin =>
      $composableBuilder(column: $table.gstin, builder: (column) => column);

  GeneratedColumn<String> get fssai =>
      $composableBuilder(column: $table.fssai, builder: (column) => column);

  GeneratedColumn<bool> get printFssaiOnInvoice => $composableBuilder(
      column: $table.printFssaiOnInvoice, builder: (column) => column);

  GeneratedColumn<bool> get gstInclusiveDefault => $composableBuilder(
      column: $table.gstInclusiveDefault, builder: (column) => column);

  GeneratedColumn<String> get serviceChargeMode => $composableBuilder(
      column: $table.serviceChargeMode, builder: (column) => column);

  GeneratedColumn<double> get serviceChargeValue => $composableBuilder(
      column: $table.serviceChargeValue, builder: (column) => column);

  GeneratedColumn<String> get packingChargeMode => $composableBuilder(
      column: $table.packingChargeMode, builder: (column) => column);

  GeneratedColumn<double> get packingChargeValue => $composableBuilder(
      column: $table.packingChargeValue, builder: (column) => column);

  GeneratedColumn<String> get billingPrinterId => $composableBuilder(
      column: $table.billingPrinterId, builder: (column) => column);

  GeneratedColumn<String> get invoiceFooter => $composableBuilder(
      column: $table.invoiceFooter, builder: (column) => column);
}

class $$RestaurantSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RestaurantSettingsTable,
    RestaurantSetting,
    $$RestaurantSettingsTableFilterComposer,
    $$RestaurantSettingsTableOrderingComposer,
    $$RestaurantSettingsTableAnnotationComposer,
    $$RestaurantSettingsTableCreateCompanionBuilder,
    $$RestaurantSettingsTableUpdateCompanionBuilder,
    (
      RestaurantSetting,
      BaseReferences<_$AppDatabase, $RestaurantSettingsTable, RestaurantSetting>
    ),
    RestaurantSetting,
    PrefetchHooks Function()> {
  $$RestaurantSettingsTableTableManager(
      _$AppDatabase db, $RestaurantSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RestaurantSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RestaurantSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RestaurantSettingsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<String?> tenantId = const Value.absent(),
            Value<String?> branchId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> logoUrl = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> gstin = const Value.absent(),
            Value<String?> fssai = const Value.absent(),
            Value<bool> printFssaiOnInvoice = const Value.absent(),
            Value<bool> gstInclusiveDefault = const Value.absent(),
            Value<String> serviceChargeMode = const Value.absent(),
            Value<double> serviceChargeValue = const Value.absent(),
            Value<String> packingChargeMode = const Value.absent(),
            Value<double> packingChargeValue = const Value.absent(),
            Value<String?> billingPrinterId = const Value.absent(),
            Value<String?> invoiceFooter = const Value.absent(),
          }) =>
              RestaurantSettingsCompanion(
            id: id,
            remoteId: remoteId,
            tenantId: tenantId,
            branchId: branchId,
            name: name,
            logoUrl: logoUrl,
            address: address,
            phone: phone,
            gstin: gstin,
            fssai: fssai,
            printFssaiOnInvoice: printFssaiOnInvoice,
            gstInclusiveDefault: gstInclusiveDefault,
            serviceChargeMode: serviceChargeMode,
            serviceChargeValue: serviceChargeValue,
            packingChargeMode: packingChargeMode,
            packingChargeValue: packingChargeValue,
            billingPrinterId: billingPrinterId,
            invoiceFooter: invoiceFooter,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<String?> tenantId = const Value.absent(),
            Value<String?> branchId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> logoUrl = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> gstin = const Value.absent(),
            Value<String?> fssai = const Value.absent(),
            Value<bool> printFssaiOnInvoice = const Value.absent(),
            Value<bool> gstInclusiveDefault = const Value.absent(),
            Value<String> serviceChargeMode = const Value.absent(),
            Value<double> serviceChargeValue = const Value.absent(),
            Value<String> packingChargeMode = const Value.absent(),
            Value<double> packingChargeValue = const Value.absent(),
            Value<String?> billingPrinterId = const Value.absent(),
            Value<String?> invoiceFooter = const Value.absent(),
          }) =>
              RestaurantSettingsCompanion.insert(
            id: id,
            remoteId: remoteId,
            tenantId: tenantId,
            branchId: branchId,
            name: name,
            logoUrl: logoUrl,
            address: address,
            phone: phone,
            gstin: gstin,
            fssai: fssai,
            printFssaiOnInvoice: printFssaiOnInvoice,
            gstInclusiveDefault: gstInclusiveDefault,
            serviceChargeMode: serviceChargeMode,
            serviceChargeValue: serviceChargeValue,
            packingChargeMode: packingChargeMode,
            packingChargeValue: packingChargeValue,
            billingPrinterId: billingPrinterId,
            invoiceFooter: invoiceFooter,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RestaurantSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RestaurantSettingsTable,
    RestaurantSetting,
    $$RestaurantSettingsTableFilterComposer,
    $$RestaurantSettingsTableOrderingComposer,
    $$RestaurantSettingsTableAnnotationComposer,
    $$RestaurantSettingsTableCreateCompanionBuilder,
    $$RestaurantSettingsTableUpdateCompanionBuilder,
    (
      RestaurantSetting,
      BaseReferences<_$AppDatabase, $RestaurantSettingsTable, RestaurantSetting>
    ),
    RestaurantSetting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MenuCategoriesTableTableManager get menuCategories =>
      $$MenuCategoriesTableTableManager(_db, _db.menuCategories);
  $$MenuItemsTableTableManager get menuItems =>
      $$MenuItemsTableTableManager(_db, _db.menuItems);
  $$ItemVariantsTableTableManager get itemVariants =>
      $$ItemVariantsTableTableManager(_db, _db.itemVariants);
  $$DiningTablesTableTableManager get diningTables =>
      $$DiningTablesTableTableManager(_db, _db.diningTables);
  $$OpsJournalTableTableManager get opsJournal =>
      $$OpsJournalTableTableManager(_db, _db.opsJournal);
  $$RestaurantSettingsTableTableManager get restaurantSettings =>
      $$RestaurantSettingsTableTableManager(_db, _db.restaurantSettings);
}
