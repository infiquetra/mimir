// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sde_database.dart';

// ignore_for_file: type=lint
class $SdeTypesTable extends SdeTypes with TableInfo<$SdeTypesTable, SdeType> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<int> typeId = GeneratedColumn<int>(
      'type_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _typeNameMeta =
      const VerificationMeta('typeName');
  @override
  late final GeneratedColumn<String> typeName = GeneratedColumn<String>(
      'type_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
      'group_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [typeId, typeName, groupId, description];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_types';
  @override
  VerificationContext validateIntegrity(Insertable<SdeType> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('type_id')) {
      context.handle(_typeIdMeta,
          typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta));
    }
    if (data.containsKey('type_name')) {
      context.handle(_typeNameMeta,
          typeName.isAcceptableOrUnknown(data['type_name']!, _typeNameMeta));
    } else if (isInserting) {
      context.missing(_typeNameMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {typeId};
  @override
  SdeType map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeType(
      typeId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type_id'])!,
      typeName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type_name'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}group_id'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
    );
  }

  @override
  $SdeTypesTable createAlias(String alias) {
    return $SdeTypesTable(attachedDatabase, alias);
  }
}

class SdeType extends DataClass implements Insertable<SdeType> {
  /// Type ID (primary key) - matches EVE typeID.
  final int typeId;

  /// Type name (e.g., "Caldari Frigate", "Mining Barge").
  final String typeName;

  /// Group ID this type belongs to.
  final int groupId;

  /// Type description (optional).
  final String? description;
  const SdeType(
      {required this.typeId,
      required this.typeName,
      required this.groupId,
      this.description});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type_id'] = Variable<int>(typeId);
    map['type_name'] = Variable<String>(typeName);
    map['group_id'] = Variable<int>(groupId);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    return map;
  }

  SdeTypesCompanion toCompanion(bool nullToAbsent) {
    return SdeTypesCompanion(
      typeId: Value(typeId),
      typeName: Value(typeName),
      groupId: Value(groupId),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
    );
  }

  factory SdeType.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeType(
      typeId: serializer.fromJson<int>(json['typeId']),
      typeName: serializer.fromJson<String>(json['typeName']),
      groupId: serializer.fromJson<int>(json['groupId']),
      description: serializer.fromJson<String?>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'typeId': serializer.toJson<int>(typeId),
      'typeName': serializer.toJson<String>(typeName),
      'groupId': serializer.toJson<int>(groupId),
      'description': serializer.toJson<String?>(description),
    };
  }

  SdeType copyWith(
          {int? typeId,
          String? typeName,
          int? groupId,
          Value<String?> description = const Value.absent()}) =>
      SdeType(
        typeId: typeId ?? this.typeId,
        typeName: typeName ?? this.typeName,
        groupId: groupId ?? this.groupId,
        description: description.present ? description.value : this.description,
      );
  SdeType copyWithCompanion(SdeTypesCompanion data) {
    return SdeType(
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      typeName: data.typeName.present ? data.typeName.value : this.typeName,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      description:
          data.description.present ? data.description.value : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeType(')
          ..write('typeId: $typeId, ')
          ..write('typeName: $typeName, ')
          ..write('groupId: $groupId, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(typeId, typeName, groupId, description);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeType &&
          other.typeId == this.typeId &&
          other.typeName == this.typeName &&
          other.groupId == this.groupId &&
          other.description == this.description);
}

class SdeTypesCompanion extends UpdateCompanion<SdeType> {
  final Value<int> typeId;
  final Value<String> typeName;
  final Value<int> groupId;
  final Value<String?> description;
  const SdeTypesCompanion({
    this.typeId = const Value.absent(),
    this.typeName = const Value.absent(),
    this.groupId = const Value.absent(),
    this.description = const Value.absent(),
  });
  SdeTypesCompanion.insert({
    this.typeId = const Value.absent(),
    required String typeName,
    required int groupId,
    this.description = const Value.absent(),
  })  : typeName = Value(typeName),
        groupId = Value(groupId);
  static Insertable<SdeType> custom({
    Expression<int>? typeId,
    Expression<String>? typeName,
    Expression<int>? groupId,
    Expression<String>? description,
  }) {
    return RawValuesInsertable({
      if (typeId != null) 'type_id': typeId,
      if (typeName != null) 'type_name': typeName,
      if (groupId != null) 'group_id': groupId,
      if (description != null) 'description': description,
    });
  }

  SdeTypesCompanion copyWith(
      {Value<int>? typeId,
      Value<String>? typeName,
      Value<int>? groupId,
      Value<String?>? description}) {
    return SdeTypesCompanion(
      typeId: typeId ?? this.typeId,
      typeName: typeName ?? this.typeName,
      groupId: groupId ?? this.groupId,
      description: description ?? this.description,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (typeId.present) {
      map['type_id'] = Variable<int>(typeId.value);
    }
    if (typeName.present) {
      map['type_name'] = Variable<String>(typeName.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeTypesCompanion(')
          ..write('typeId: $typeId, ')
          ..write('typeName: $typeName, ')
          ..write('groupId: $groupId, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }
}

class $SdeGroupsTable extends SdeGroups
    with TableInfo<$SdeGroupsTable, SdeGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
      'group_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _groupNameMeta =
      const VerificationMeta('groupName');
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
      'group_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [groupId, groupName, categoryId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_groups';
  @override
  VerificationContext validateIntegrity(Insertable<SdeGroup> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    }
    if (data.containsKey('group_name')) {
      context.handle(_groupNameMeta,
          groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta));
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  SdeGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeGroup(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}group_id'])!,
      groupName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_name'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id'])!,
    );
  }

  @override
  $SdeGroupsTable createAlias(String alias) {
    return $SdeGroupsTable(attachedDatabase, alias);
  }
}

class SdeGroup extends DataClass implements Insertable<SdeGroup> {
  /// Group ID (primary key) - matches EVE groupID.
  final int groupId;

  /// Group name (e.g., "Spaceship Command", "Shield").
  final String groupName;

  /// Category ID this group belongs to.
  final int categoryId;
  const SdeGroup(
      {required this.groupId,
      required this.groupName,
      required this.categoryId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<int>(groupId);
    map['group_name'] = Variable<String>(groupName);
    map['category_id'] = Variable<int>(categoryId);
    return map;
  }

  SdeGroupsCompanion toCompanion(bool nullToAbsent) {
    return SdeGroupsCompanion(
      groupId: Value(groupId),
      groupName: Value(groupName),
      categoryId: Value(categoryId),
    );
  }

  factory SdeGroup.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeGroup(
      groupId: serializer.fromJson<int>(json['groupId']),
      groupName: serializer.fromJson<String>(json['groupName']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<int>(groupId),
      'groupName': serializer.toJson<String>(groupName),
      'categoryId': serializer.toJson<int>(categoryId),
    };
  }

  SdeGroup copyWith({int? groupId, String? groupName, int? categoryId}) =>
      SdeGroup(
        groupId: groupId ?? this.groupId,
        groupName: groupName ?? this.groupName,
        categoryId: categoryId ?? this.categoryId,
      );
  SdeGroup copyWithCompanion(SdeGroupsCompanion data) {
    return SdeGroup(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeGroup(')
          ..write('groupId: $groupId, ')
          ..write('groupName: $groupName, ')
          ..write('categoryId: $categoryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, groupName, categoryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeGroup &&
          other.groupId == this.groupId &&
          other.groupName == this.groupName &&
          other.categoryId == this.categoryId);
}

class SdeGroupsCompanion extends UpdateCompanion<SdeGroup> {
  final Value<int> groupId;
  final Value<String> groupName;
  final Value<int> categoryId;
  const SdeGroupsCompanion({
    this.groupId = const Value.absent(),
    this.groupName = const Value.absent(),
    this.categoryId = const Value.absent(),
  });
  SdeGroupsCompanion.insert({
    this.groupId = const Value.absent(),
    required String groupName,
    required int categoryId,
  })  : groupName = Value(groupName),
        categoryId = Value(categoryId);
  static Insertable<SdeGroup> custom({
    Expression<int>? groupId,
    Expression<String>? groupName,
    Expression<int>? categoryId,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (groupName != null) 'group_name': groupName,
      if (categoryId != null) 'category_id': categoryId,
    });
  }

  SdeGroupsCompanion copyWith(
      {Value<int>? groupId, Value<String>? groupName, Value<int>? categoryId}) {
    return SdeGroupsCompanion(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      categoryId: categoryId ?? this.categoryId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeGroupsCompanion(')
          ..write('groupId: $groupId, ')
          ..write('groupName: $groupName, ')
          ..write('categoryId: $categoryId')
          ..write(')'))
        .toString();
  }
}

class $SdeCategoriesTable extends SdeCategories
    with TableInfo<$SdeCategoriesTable, SdeCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _categoryNameMeta =
      const VerificationMeta('categoryName');
  @override
  late final GeneratedColumn<String> categoryName = GeneratedColumn<String>(
      'category_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [categoryId, categoryName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_categories';
  @override
  VerificationContext validateIntegrity(Insertable<SdeCategory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('category_name')) {
      context.handle(
          _categoryNameMeta,
          categoryName.isAcceptableOrUnknown(
              data['category_name']!, _categoryNameMeta));
    } else if (isInserting) {
      context.missing(_categoryNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {categoryId};
  @override
  SdeCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeCategory(
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id'])!,
      categoryName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_name'])!,
    );
  }

  @override
  $SdeCategoriesTable createAlias(String alias) {
    return $SdeCategoriesTable(attachedDatabase, alias);
  }
}

class SdeCategory extends DataClass implements Insertable<SdeCategory> {
  /// Category ID (primary key) - matches EVE categoryID.
  final int categoryId;

  /// Category name (e.g., "Skill", "Ship").
  final String categoryName;
  const SdeCategory({required this.categoryId, required this.categoryName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['category_id'] = Variable<int>(categoryId);
    map['category_name'] = Variable<String>(categoryName);
    return map;
  }

  SdeCategoriesCompanion toCompanion(bool nullToAbsent) {
    return SdeCategoriesCompanion(
      categoryId: Value(categoryId),
      categoryName: Value(categoryName),
    );
  }

  factory SdeCategory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeCategory(
      categoryId: serializer.fromJson<int>(json['categoryId']),
      categoryName: serializer.fromJson<String>(json['categoryName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'categoryId': serializer.toJson<int>(categoryId),
      'categoryName': serializer.toJson<String>(categoryName),
    };
  }

  SdeCategory copyWith({int? categoryId, String? categoryName}) => SdeCategory(
        categoryId: categoryId ?? this.categoryId,
        categoryName: categoryName ?? this.categoryName,
      );
  SdeCategory copyWithCompanion(SdeCategoriesCompanion data) {
    return SdeCategory(
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      categoryName: data.categoryName.present
          ? data.categoryName.value
          : this.categoryName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeCategory(')
          ..write('categoryId: $categoryId, ')
          ..write('categoryName: $categoryName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(categoryId, categoryName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeCategory &&
          other.categoryId == this.categoryId &&
          other.categoryName == this.categoryName);
}

class SdeCategoriesCompanion extends UpdateCompanion<SdeCategory> {
  final Value<int> categoryId;
  final Value<String> categoryName;
  const SdeCategoriesCompanion({
    this.categoryId = const Value.absent(),
    this.categoryName = const Value.absent(),
  });
  SdeCategoriesCompanion.insert({
    this.categoryId = const Value.absent(),
    required String categoryName,
  }) : categoryName = Value(categoryName);
  static Insertable<SdeCategory> custom({
    Expression<int>? categoryId,
    Expression<String>? categoryName,
  }) {
    return RawValuesInsertable({
      if (categoryId != null) 'category_id': categoryId,
      if (categoryName != null) 'category_name': categoryName,
    });
  }

  SdeCategoriesCompanion copyWith(
      {Value<int>? categoryId, Value<String>? categoryName}) {
    return SdeCategoriesCompanion(
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (categoryName.present) {
      map['category_name'] = Variable<String>(categoryName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeCategoriesCompanion(')
          ..write('categoryId: $categoryId, ')
          ..write('categoryName: $categoryName')
          ..write(')'))
        .toString();
  }
}

abstract class _$SdeDatabase extends GeneratedDatabase {
  _$SdeDatabase(QueryExecutor e) : super(e);
  $SdeDatabaseManager get managers => $SdeDatabaseManager(this);
  late final $SdeTypesTable sdeTypes = $SdeTypesTable(this);
  late final $SdeGroupsTable sdeGroups = $SdeGroupsTable(this);
  late final $SdeCategoriesTable sdeCategories = $SdeCategoriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [sdeTypes, sdeGroups, sdeCategories];
}

typedef $$SdeTypesTableCreateCompanionBuilder = SdeTypesCompanion Function({
  Value<int> typeId,
  required String typeName,
  required int groupId,
  Value<String?> description,
});
typedef $$SdeTypesTableUpdateCompanionBuilder = SdeTypesCompanion Function({
  Value<int> typeId,
  Value<String> typeName,
  Value<int> groupId,
  Value<String?> description,
});

class $$SdeTypesTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeTypesTable> {
  $$SdeTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get typeId => $composableBuilder(
      column: $table.typeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get typeName => $composableBuilder(
      column: $table.typeName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));
}

class $$SdeTypesTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeTypesTable> {
  $$SdeTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get typeId => $composableBuilder(
      column: $table.typeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get typeName => $composableBuilder(
      column: $table.typeName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));
}

class $$SdeTypesTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeTypesTable> {
  $$SdeTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<String> get typeName =>
      $composableBuilder(column: $table.typeName, builder: (column) => column);

  GeneratedColumn<int> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);
}

class $$SdeTypesTableTableManager extends RootTableManager<
    _$SdeDatabase,
    $SdeTypesTable,
    SdeType,
    $$SdeTypesTableFilterComposer,
    $$SdeTypesTableOrderingComposer,
    $$SdeTypesTableAnnotationComposer,
    $$SdeTypesTableCreateCompanionBuilder,
    $$SdeTypesTableUpdateCompanionBuilder,
    (SdeType, BaseReferences<_$SdeDatabase, $SdeTypesTable, SdeType>),
    SdeType,
    PrefetchHooks Function()> {
  $$SdeTypesTableTableManager(_$SdeDatabase db, $SdeTypesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> typeId = const Value.absent(),
            Value<String> typeName = const Value.absent(),
            Value<int> groupId = const Value.absent(),
            Value<String?> description = const Value.absent(),
          }) =>
              SdeTypesCompanion(
            typeId: typeId,
            typeName: typeName,
            groupId: groupId,
            description: description,
          ),
          createCompanionCallback: ({
            Value<int> typeId = const Value.absent(),
            required String typeName,
            required int groupId,
            Value<String?> description = const Value.absent(),
          }) =>
              SdeTypesCompanion.insert(
            typeId: typeId,
            typeName: typeName,
            groupId: groupId,
            description: description,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SdeTypesTableProcessedTableManager = ProcessedTableManager<
    _$SdeDatabase,
    $SdeTypesTable,
    SdeType,
    $$SdeTypesTableFilterComposer,
    $$SdeTypesTableOrderingComposer,
    $$SdeTypesTableAnnotationComposer,
    $$SdeTypesTableCreateCompanionBuilder,
    $$SdeTypesTableUpdateCompanionBuilder,
    (SdeType, BaseReferences<_$SdeDatabase, $SdeTypesTable, SdeType>),
    SdeType,
    PrefetchHooks Function()>;
typedef $$SdeGroupsTableCreateCompanionBuilder = SdeGroupsCompanion Function({
  Value<int> groupId,
  required String groupName,
  required int categoryId,
});
typedef $$SdeGroupsTableUpdateCompanionBuilder = SdeGroupsCompanion Function({
  Value<int> groupId,
  Value<String> groupName,
  Value<int> categoryId,
});

class $$SdeGroupsTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeGroupsTable> {
  $$SdeGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupName => $composableBuilder(
      column: $table.groupName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));
}

class $$SdeGroupsTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeGroupsTable> {
  $$SdeGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupName => $composableBuilder(
      column: $table.groupName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));
}

class $$SdeGroupsTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeGroupsTable> {
  $$SdeGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);
}

class $$SdeGroupsTableTableManager extends RootTableManager<
    _$SdeDatabase,
    $SdeGroupsTable,
    SdeGroup,
    $$SdeGroupsTableFilterComposer,
    $$SdeGroupsTableOrderingComposer,
    $$SdeGroupsTableAnnotationComposer,
    $$SdeGroupsTableCreateCompanionBuilder,
    $$SdeGroupsTableUpdateCompanionBuilder,
    (SdeGroup, BaseReferences<_$SdeDatabase, $SdeGroupsTable, SdeGroup>),
    SdeGroup,
    PrefetchHooks Function()> {
  $$SdeGroupsTableTableManager(_$SdeDatabase db, $SdeGroupsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> groupId = const Value.absent(),
            Value<String> groupName = const Value.absent(),
            Value<int> categoryId = const Value.absent(),
          }) =>
              SdeGroupsCompanion(
            groupId: groupId,
            groupName: groupName,
            categoryId: categoryId,
          ),
          createCompanionCallback: ({
            Value<int> groupId = const Value.absent(),
            required String groupName,
            required int categoryId,
          }) =>
              SdeGroupsCompanion.insert(
            groupId: groupId,
            groupName: groupName,
            categoryId: categoryId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SdeGroupsTableProcessedTableManager = ProcessedTableManager<
    _$SdeDatabase,
    $SdeGroupsTable,
    SdeGroup,
    $$SdeGroupsTableFilterComposer,
    $$SdeGroupsTableOrderingComposer,
    $$SdeGroupsTableAnnotationComposer,
    $$SdeGroupsTableCreateCompanionBuilder,
    $$SdeGroupsTableUpdateCompanionBuilder,
    (SdeGroup, BaseReferences<_$SdeDatabase, $SdeGroupsTable, SdeGroup>),
    SdeGroup,
    PrefetchHooks Function()>;
typedef $$SdeCategoriesTableCreateCompanionBuilder = SdeCategoriesCompanion
    Function({
  Value<int> categoryId,
  required String categoryName,
});
typedef $$SdeCategoriesTableUpdateCompanionBuilder = SdeCategoriesCompanion
    Function({
  Value<int> categoryId,
  Value<String> categoryName,
});

class $$SdeCategoriesTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeCategoriesTable> {
  $$SdeCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryName => $composableBuilder(
      column: $table.categoryName, builder: (column) => ColumnFilters(column));
}

class $$SdeCategoriesTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeCategoriesTable> {
  $$SdeCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryName => $composableBuilder(
      column: $table.categoryName,
      builder: (column) => ColumnOrderings(column));
}

class $$SdeCategoriesTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeCategoriesTable> {
  $$SdeCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<String> get categoryName => $composableBuilder(
      column: $table.categoryName, builder: (column) => column);
}

class $$SdeCategoriesTableTableManager extends RootTableManager<
    _$SdeDatabase,
    $SdeCategoriesTable,
    SdeCategory,
    $$SdeCategoriesTableFilterComposer,
    $$SdeCategoriesTableOrderingComposer,
    $$SdeCategoriesTableAnnotationComposer,
    $$SdeCategoriesTableCreateCompanionBuilder,
    $$SdeCategoriesTableUpdateCompanionBuilder,
    (
      SdeCategory,
      BaseReferences<_$SdeDatabase, $SdeCategoriesTable, SdeCategory>
    ),
    SdeCategory,
    PrefetchHooks Function()> {
  $$SdeCategoriesTableTableManager(_$SdeDatabase db, $SdeCategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> categoryId = const Value.absent(),
            Value<String> categoryName = const Value.absent(),
          }) =>
              SdeCategoriesCompanion(
            categoryId: categoryId,
            categoryName: categoryName,
          ),
          createCompanionCallback: ({
            Value<int> categoryId = const Value.absent(),
            required String categoryName,
          }) =>
              SdeCategoriesCompanion.insert(
            categoryId: categoryId,
            categoryName: categoryName,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SdeCategoriesTableProcessedTableManager = ProcessedTableManager<
    _$SdeDatabase,
    $SdeCategoriesTable,
    SdeCategory,
    $$SdeCategoriesTableFilterComposer,
    $$SdeCategoriesTableOrderingComposer,
    $$SdeCategoriesTableAnnotationComposer,
    $$SdeCategoriesTableCreateCompanionBuilder,
    $$SdeCategoriesTableUpdateCompanionBuilder,
    (
      SdeCategory,
      BaseReferences<_$SdeDatabase, $SdeCategoriesTable, SdeCategory>
    ),
    SdeCategory,
    PrefetchHooks Function()>;

class $SdeDatabaseManager {
  final _$SdeDatabase _db;
  $SdeDatabaseManager(this._db);
  $$SdeTypesTableTableManager get sdeTypes =>
      $$SdeTypesTableTableManager(_db, _db.sdeTypes);
  $$SdeGroupsTableTableManager get sdeGroups =>
      $$SdeGroupsTableTableManager(_db, _db.sdeGroups);
  $$SdeCategoriesTableTableManager get sdeCategories =>
      $$SdeCategoriesTableTableManager(_db, _db.sdeCategories);
}
