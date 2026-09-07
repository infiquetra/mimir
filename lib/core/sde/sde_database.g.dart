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
    'type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeNameMeta = const VerificationMeta(
    'typeName',
  );
  @override
  late final GeneratedColumn<String> typeName = GeneratedColumn<String>(
    'type_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rankMeta = const VerificationMeta('rank');
  @override
  late final GeneratedColumn<int> rank = GeneratedColumn<int>(
    'rank',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _primaryAttributeMeta = const VerificationMeta(
    'primaryAttribute',
  );
  @override
  late final GeneratedColumn<String> primaryAttribute = GeneratedColumn<String>(
    'primary_attribute',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _secondaryAttributeMeta =
      const VerificationMeta('secondaryAttribute');
  @override
  late final GeneratedColumn<String> secondaryAttribute =
      GeneratedColumn<String>(
        'secondary_attribute',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    typeId,
    typeName,
    groupId,
    description,
    rank,
    primaryAttribute,
    secondaryAttribute,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeType> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    }
    if (data.containsKey('type_name')) {
      context.handle(
        _typeNameMeta,
        typeName.isAcceptableOrUnknown(data['type_name']!, _typeNameMeta),
      );
    } else if (isInserting) {
      context.missing(_typeNameMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('rank')) {
      context.handle(
        _rankMeta,
        rank.isAcceptableOrUnknown(data['rank']!, _rankMeta),
      );
    }
    if (data.containsKey('primary_attribute')) {
      context.handle(
        _primaryAttributeMeta,
        primaryAttribute.isAcceptableOrUnknown(
          data['primary_attribute']!,
          _primaryAttributeMeta,
        ),
      );
    }
    if (data.containsKey('secondary_attribute')) {
      context.handle(
        _secondaryAttributeMeta,
        secondaryAttribute.isAcceptableOrUnknown(
          data['secondary_attribute']!,
          _secondaryAttributeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {typeId};
  @override
  SdeType map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeType(
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_id'],
      )!,
      typeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type_name'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      rank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rank'],
      ),
      primaryAttribute: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_attribute'],
      ),
      secondaryAttribute: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_attribute'],
      ),
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

  /// Skill rank (training time multiplier) - only for skills.
  /// Null for non-skill types.
  final int? rank;

  /// Primary attribute for skill training - only for skills.
  /// One of: perception, willpower, intelligence, memory, charisma.
  /// Null for non-skill types.
  final String? primaryAttribute;

  /// Secondary attribute for skill training - only for skills.
  /// One of: perception, willpower, intelligence, memory, charisma.
  /// Null for non-skill types.
  final String? secondaryAttribute;
  const SdeType({
    required this.typeId,
    required this.typeName,
    required this.groupId,
    this.description,
    this.rank,
    this.primaryAttribute,
    this.secondaryAttribute,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type_id'] = Variable<int>(typeId);
    map['type_name'] = Variable<String>(typeName);
    map['group_id'] = Variable<int>(groupId);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || rank != null) {
      map['rank'] = Variable<int>(rank);
    }
    if (!nullToAbsent || primaryAttribute != null) {
      map['primary_attribute'] = Variable<String>(primaryAttribute);
    }
    if (!nullToAbsent || secondaryAttribute != null) {
      map['secondary_attribute'] = Variable<String>(secondaryAttribute);
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
      rank: rank == null && nullToAbsent ? const Value.absent() : Value(rank),
      primaryAttribute: primaryAttribute == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryAttribute),
      secondaryAttribute: secondaryAttribute == null && nullToAbsent
          ? const Value.absent()
          : Value(secondaryAttribute),
    );
  }

  factory SdeType.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeType(
      typeId: serializer.fromJson<int>(json['typeId']),
      typeName: serializer.fromJson<String>(json['typeName']),
      groupId: serializer.fromJson<int>(json['groupId']),
      description: serializer.fromJson<String?>(json['description']),
      rank: serializer.fromJson<int?>(json['rank']),
      primaryAttribute: serializer.fromJson<String?>(json['primaryAttribute']),
      secondaryAttribute: serializer.fromJson<String?>(
        json['secondaryAttribute'],
      ),
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
      'rank': serializer.toJson<int?>(rank),
      'primaryAttribute': serializer.toJson<String?>(primaryAttribute),
      'secondaryAttribute': serializer.toJson<String?>(secondaryAttribute),
    };
  }

  SdeType copyWith({
    int? typeId,
    String? typeName,
    int? groupId,
    Value<String?> description = const Value.absent(),
    Value<int?> rank = const Value.absent(),
    Value<String?> primaryAttribute = const Value.absent(),
    Value<String?> secondaryAttribute = const Value.absent(),
  }) => SdeType(
    typeId: typeId ?? this.typeId,
    typeName: typeName ?? this.typeName,
    groupId: groupId ?? this.groupId,
    description: description.present ? description.value : this.description,
    rank: rank.present ? rank.value : this.rank,
    primaryAttribute: primaryAttribute.present
        ? primaryAttribute.value
        : this.primaryAttribute,
    secondaryAttribute: secondaryAttribute.present
        ? secondaryAttribute.value
        : this.secondaryAttribute,
  );
  SdeType copyWithCompanion(SdeTypesCompanion data) {
    return SdeType(
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      typeName: data.typeName.present ? data.typeName.value : this.typeName,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      description: data.description.present
          ? data.description.value
          : this.description,
      rank: data.rank.present ? data.rank.value : this.rank,
      primaryAttribute: data.primaryAttribute.present
          ? data.primaryAttribute.value
          : this.primaryAttribute,
      secondaryAttribute: data.secondaryAttribute.present
          ? data.secondaryAttribute.value
          : this.secondaryAttribute,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeType(')
          ..write('typeId: $typeId, ')
          ..write('typeName: $typeName, ')
          ..write('groupId: $groupId, ')
          ..write('description: $description, ')
          ..write('rank: $rank, ')
          ..write('primaryAttribute: $primaryAttribute, ')
          ..write('secondaryAttribute: $secondaryAttribute')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    typeId,
    typeName,
    groupId,
    description,
    rank,
    primaryAttribute,
    secondaryAttribute,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeType &&
          other.typeId == this.typeId &&
          other.typeName == this.typeName &&
          other.groupId == this.groupId &&
          other.description == this.description &&
          other.rank == this.rank &&
          other.primaryAttribute == this.primaryAttribute &&
          other.secondaryAttribute == this.secondaryAttribute);
}

class SdeTypesCompanion extends UpdateCompanion<SdeType> {
  final Value<int> typeId;
  final Value<String> typeName;
  final Value<int> groupId;
  final Value<String?> description;
  final Value<int?> rank;
  final Value<String?> primaryAttribute;
  final Value<String?> secondaryAttribute;
  const SdeTypesCompanion({
    this.typeId = const Value.absent(),
    this.typeName = const Value.absent(),
    this.groupId = const Value.absent(),
    this.description = const Value.absent(),
    this.rank = const Value.absent(),
    this.primaryAttribute = const Value.absent(),
    this.secondaryAttribute = const Value.absent(),
  });
  SdeTypesCompanion.insert({
    this.typeId = const Value.absent(),
    required String typeName,
    required int groupId,
    this.description = const Value.absent(),
    this.rank = const Value.absent(),
    this.primaryAttribute = const Value.absent(),
    this.secondaryAttribute = const Value.absent(),
  }) : typeName = Value(typeName),
       groupId = Value(groupId);
  static Insertable<SdeType> custom({
    Expression<int>? typeId,
    Expression<String>? typeName,
    Expression<int>? groupId,
    Expression<String>? description,
    Expression<int>? rank,
    Expression<String>? primaryAttribute,
    Expression<String>? secondaryAttribute,
  }) {
    return RawValuesInsertable({
      if (typeId != null) 'type_id': typeId,
      if (typeName != null) 'type_name': typeName,
      if (groupId != null) 'group_id': groupId,
      if (description != null) 'description': description,
      if (rank != null) 'rank': rank,
      if (primaryAttribute != null) 'primary_attribute': primaryAttribute,
      if (secondaryAttribute != null) 'secondary_attribute': secondaryAttribute,
    });
  }

  SdeTypesCompanion copyWith({
    Value<int>? typeId,
    Value<String>? typeName,
    Value<int>? groupId,
    Value<String?>? description,
    Value<int?>? rank,
    Value<String?>? primaryAttribute,
    Value<String?>? secondaryAttribute,
  }) {
    return SdeTypesCompanion(
      typeId: typeId ?? this.typeId,
      typeName: typeName ?? this.typeName,
      groupId: groupId ?? this.groupId,
      description: description ?? this.description,
      rank: rank ?? this.rank,
      primaryAttribute: primaryAttribute ?? this.primaryAttribute,
      secondaryAttribute: secondaryAttribute ?? this.secondaryAttribute,
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
    if (rank.present) {
      map['rank'] = Variable<int>(rank.value);
    }
    if (primaryAttribute.present) {
      map['primary_attribute'] = Variable<String>(primaryAttribute.value);
    }
    if (secondaryAttribute.present) {
      map['secondary_attribute'] = Variable<String>(secondaryAttribute.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeTypesCompanion(')
          ..write('typeId: $typeId, ')
          ..write('typeName: $typeName, ')
          ..write('groupId: $groupId, ')
          ..write('description: $description, ')
          ..write('rank: $rank, ')
          ..write('primaryAttribute: $primaryAttribute, ')
          ..write('secondaryAttribute: $secondaryAttribute')
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
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [groupId, groupName, categoryId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
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
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
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
  const SdeGroup({
    required this.groupId,
    required this.groupName,
    required this.categoryId,
  });
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

  factory SdeGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
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
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
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
  }) : groupName = Value(groupName),
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

  SdeGroupsCompanion copyWith({
    Value<int>? groupId,
    Value<String>? groupName,
    Value<int>? categoryId,
  }) {
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
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryNameMeta = const VerificationMeta(
    'categoryName',
  );
  @override
  late final GeneratedColumn<String> categoryName = GeneratedColumn<String>(
    'category_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [categoryId, categoryName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('category_name')) {
      context.handle(
        _categoryNameMeta,
        categoryName.isAcceptableOrUnknown(
          data['category_name']!,
          _categoryNameMeta,
        ),
      );
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
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      categoryName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_name'],
      )!,
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

  factory SdeCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
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
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
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

  SdeCategoriesCompanion copyWith({
    Value<int>? categoryId,
    Value<String>? categoryName,
  }) {
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

class $SdeMetadataTable extends SdeMetadata
    with TableInfo<$SdeMetadataTable, SdeMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SdeMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeMetadataData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SdeMetadataTable createAlias(String alias) {
    return $SdeMetadataTable(attachedDatabase, alias);
  }
}

class SdeMetadataData extends DataClass implements Insertable<SdeMetadataData> {
  /// Key for the metadata entry.
  final String key;

  /// Value for the metadata entry.
  final String value;
  const SdeMetadataData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SdeMetadataCompanion toCompanion(bool nullToAbsent) {
    return SdeMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory SdeMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SdeMetadataData copyWith({String? key, String? value}) =>
      SdeMetadataData(key: key ?? this.key, value: value ?? this.value);
  SdeMetadataData copyWithCompanion(SdeMetadataCompanion data) {
    return SdeMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeMetadataData &&
          other.key == this.key &&
          other.value == this.value);
}

class SdeMetadataCompanion extends UpdateCompanion<SdeMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SdeMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SdeMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SdeMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SdeMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SdeMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SdeSkillRequirementsTable extends SdeSkillRequirements
    with TableInfo<$SdeSkillRequirementsTable, SdeSkillRequirement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeSkillRequirementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _skillIdMeta = const VerificationMeta(
    'skillId',
  );
  @override
  late final GeneratedColumn<int> skillId = GeneratedColumn<int>(
    'skill_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requiredSkillIdMeta = const VerificationMeta(
    'requiredSkillId',
  );
  @override
  late final GeneratedColumn<int> requiredSkillId = GeneratedColumn<int>(
    'required_skill_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requiredLevelMeta = const VerificationMeta(
    'requiredLevel',
  );
  @override
  late final GeneratedColumn<int> requiredLevel = GeneratedColumn<int>(
    'required_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    skillId,
    requiredSkillId,
    requiredLevel,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_skill_requirements';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeSkillRequirement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('skill_id')) {
      context.handle(
        _skillIdMeta,
        skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta),
      );
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('required_skill_id')) {
      context.handle(
        _requiredSkillIdMeta,
        requiredSkillId.isAcceptableOrUnknown(
          data['required_skill_id']!,
          _requiredSkillIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requiredSkillIdMeta);
    }
    if (data.containsKey('required_level')) {
      context.handle(
        _requiredLevelMeta,
        requiredLevel.isAcceptableOrUnknown(
          data['required_level']!,
          _requiredLevelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requiredLevelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {skillId, requiredSkillId};
  @override
  SdeSkillRequirement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeSkillRequirement(
      skillId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skill_id'],
      )!,
      requiredSkillId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}required_skill_id'],
      )!,
      requiredLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}required_level'],
      )!,
    );
  }

  @override
  $SdeSkillRequirementsTable createAlias(String alias) {
    return $SdeSkillRequirementsTable(attachedDatabase, alias);
  }
}

class SdeSkillRequirement extends DataClass
    implements Insertable<SdeSkillRequirement> {
  /// The skill that has the requirement (e.g., "Medium Hybrid Turret").
  final int skillId;

  /// The required skill (e.g., "Gunnery").
  final int requiredSkillId;

  /// The required level (1-5).
  final int requiredLevel;
  const SdeSkillRequirement({
    required this.skillId,
    required this.requiredSkillId,
    required this.requiredLevel,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['skill_id'] = Variable<int>(skillId);
    map['required_skill_id'] = Variable<int>(requiredSkillId);
    map['required_level'] = Variable<int>(requiredLevel);
    return map;
  }

  SdeSkillRequirementsCompanion toCompanion(bool nullToAbsent) {
    return SdeSkillRequirementsCompanion(
      skillId: Value(skillId),
      requiredSkillId: Value(requiredSkillId),
      requiredLevel: Value(requiredLevel),
    );
  }

  factory SdeSkillRequirement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeSkillRequirement(
      skillId: serializer.fromJson<int>(json['skillId']),
      requiredSkillId: serializer.fromJson<int>(json['requiredSkillId']),
      requiredLevel: serializer.fromJson<int>(json['requiredLevel']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'skillId': serializer.toJson<int>(skillId),
      'requiredSkillId': serializer.toJson<int>(requiredSkillId),
      'requiredLevel': serializer.toJson<int>(requiredLevel),
    };
  }

  SdeSkillRequirement copyWith({
    int? skillId,
    int? requiredSkillId,
    int? requiredLevel,
  }) => SdeSkillRequirement(
    skillId: skillId ?? this.skillId,
    requiredSkillId: requiredSkillId ?? this.requiredSkillId,
    requiredLevel: requiredLevel ?? this.requiredLevel,
  );
  SdeSkillRequirement copyWithCompanion(SdeSkillRequirementsCompanion data) {
    return SdeSkillRequirement(
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      requiredSkillId: data.requiredSkillId.present
          ? data.requiredSkillId.value
          : this.requiredSkillId,
      requiredLevel: data.requiredLevel.present
          ? data.requiredLevel.value
          : this.requiredLevel,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeSkillRequirement(')
          ..write('skillId: $skillId, ')
          ..write('requiredSkillId: $requiredSkillId, ')
          ..write('requiredLevel: $requiredLevel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(skillId, requiredSkillId, requiredLevel);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeSkillRequirement &&
          other.skillId == this.skillId &&
          other.requiredSkillId == this.requiredSkillId &&
          other.requiredLevel == this.requiredLevel);
}

class SdeSkillRequirementsCompanion
    extends UpdateCompanion<SdeSkillRequirement> {
  final Value<int> skillId;
  final Value<int> requiredSkillId;
  final Value<int> requiredLevel;
  final Value<int> rowid;
  const SdeSkillRequirementsCompanion({
    this.skillId = const Value.absent(),
    this.requiredSkillId = const Value.absent(),
    this.requiredLevel = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SdeSkillRequirementsCompanion.insert({
    required int skillId,
    required int requiredSkillId,
    required int requiredLevel,
    this.rowid = const Value.absent(),
  }) : skillId = Value(skillId),
       requiredSkillId = Value(requiredSkillId),
       requiredLevel = Value(requiredLevel);
  static Insertable<SdeSkillRequirement> custom({
    Expression<int>? skillId,
    Expression<int>? requiredSkillId,
    Expression<int>? requiredLevel,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (skillId != null) 'skill_id': skillId,
      if (requiredSkillId != null) 'required_skill_id': requiredSkillId,
      if (requiredLevel != null) 'required_level': requiredLevel,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SdeSkillRequirementsCompanion copyWith({
    Value<int>? skillId,
    Value<int>? requiredSkillId,
    Value<int>? requiredLevel,
    Value<int>? rowid,
  }) {
    return SdeSkillRequirementsCompanion(
      skillId: skillId ?? this.skillId,
      requiredSkillId: requiredSkillId ?? this.requiredSkillId,
      requiredLevel: requiredLevel ?? this.requiredLevel,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (skillId.present) {
      map['skill_id'] = Variable<int>(skillId.value);
    }
    if (requiredSkillId.present) {
      map['required_skill_id'] = Variable<int>(requiredSkillId.value);
    }
    if (requiredLevel.present) {
      map['required_level'] = Variable<int>(requiredLevel.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeSkillRequirementsCompanion(')
          ..write('skillId: $skillId, ')
          ..write('requiredSkillId: $requiredSkillId, ')
          ..write('requiredLevel: $requiredLevel, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SdeTypeAttributesTable extends SdeTypeAttributes
    with TableInfo<$SdeTypeAttributesTable, SdeTypeAttribute> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeTypeAttributesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<int> typeId = GeneratedColumn<int>(
    'type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attributeIdMeta = const VerificationMeta(
    'attributeId',
  );
  @override
  late final GeneratedColumn<int> attributeId = GeneratedColumn<int>(
    'attribute_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [typeId, attributeId, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_type_attributes';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeTypeAttribute> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('attribute_id')) {
      context.handle(
        _attributeIdMeta,
        attributeId.isAcceptableOrUnknown(
          data['attribute_id']!,
          _attributeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attributeIdMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {typeId, attributeId};
  @override
  SdeTypeAttribute map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeTypeAttribute(
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_id'],
      )!,
      attributeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attribute_id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SdeTypeAttributesTable createAlias(String alias) {
    return $SdeTypeAttributesTable(attachedDatabase, alias);
  }
}

class SdeTypeAttribute extends DataClass
    implements Insertable<SdeTypeAttribute> {
  final int typeId;
  final int attributeId;
  final double value;
  const SdeTypeAttribute({
    required this.typeId,
    required this.attributeId,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type_id'] = Variable<int>(typeId);
    map['attribute_id'] = Variable<int>(attributeId);
    map['value'] = Variable<double>(value);
    return map;
  }

  SdeTypeAttributesCompanion toCompanion(bool nullToAbsent) {
    return SdeTypeAttributesCompanion(
      typeId: Value(typeId),
      attributeId: Value(attributeId),
      value: Value(value),
    );
  }

  factory SdeTypeAttribute.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeTypeAttribute(
      typeId: serializer.fromJson<int>(json['typeId']),
      attributeId: serializer.fromJson<int>(json['attributeId']),
      value: serializer.fromJson<double>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'typeId': serializer.toJson<int>(typeId),
      'attributeId': serializer.toJson<int>(attributeId),
      'value': serializer.toJson<double>(value),
    };
  }

  SdeTypeAttribute copyWith({int? typeId, int? attributeId, double? value}) =>
      SdeTypeAttribute(
        typeId: typeId ?? this.typeId,
        attributeId: attributeId ?? this.attributeId,
        value: value ?? this.value,
      );
  SdeTypeAttribute copyWithCompanion(SdeTypeAttributesCompanion data) {
    return SdeTypeAttribute(
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      attributeId: data.attributeId.present
          ? data.attributeId.value
          : this.attributeId,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeTypeAttribute(')
          ..write('typeId: $typeId, ')
          ..write('attributeId: $attributeId, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(typeId, attributeId, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeTypeAttribute &&
          other.typeId == this.typeId &&
          other.attributeId == this.attributeId &&
          other.value == this.value);
}

class SdeTypeAttributesCompanion extends UpdateCompanion<SdeTypeAttribute> {
  final Value<int> typeId;
  final Value<int> attributeId;
  final Value<double> value;
  final Value<int> rowid;
  const SdeTypeAttributesCompanion({
    this.typeId = const Value.absent(),
    this.attributeId = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SdeTypeAttributesCompanion.insert({
    required int typeId,
    required int attributeId,
    required double value,
    this.rowid = const Value.absent(),
  }) : typeId = Value(typeId),
       attributeId = Value(attributeId),
       value = Value(value);
  static Insertable<SdeTypeAttribute> custom({
    Expression<int>? typeId,
    Expression<int>? attributeId,
    Expression<double>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (typeId != null) 'type_id': typeId,
      if (attributeId != null) 'attribute_id': attributeId,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SdeTypeAttributesCompanion copyWith({
    Value<int>? typeId,
    Value<int>? attributeId,
    Value<double>? value,
    Value<int>? rowid,
  }) {
    return SdeTypeAttributesCompanion(
      typeId: typeId ?? this.typeId,
      attributeId: attributeId ?? this.attributeId,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (typeId.present) {
      map['type_id'] = Variable<int>(typeId.value);
    }
    if (attributeId.present) {
      map['attribute_id'] = Variable<int>(attributeId.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeTypeAttributesCompanion(')
          ..write('typeId: $typeId, ')
          ..write('attributeId: $attributeId, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SdeTypeEffectsTable extends SdeTypeEffects
    with TableInfo<$SdeTypeEffectsTable, SdeTypeEffect> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeTypeEffectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<int> typeId = GeneratedColumn<int>(
    'type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _effectIdMeta = const VerificationMeta(
    'effectId',
  );
  @override
  late final GeneratedColumn<int> effectId = GeneratedColumn<int>(
    'effect_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [typeId, effectId, isDefault];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_type_effects';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeTypeEffect> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('effect_id')) {
      context.handle(
        _effectIdMeta,
        effectId.isAcceptableOrUnknown(data['effect_id']!, _effectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_effectIdMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {typeId, effectId};
  @override
  SdeTypeEffect map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeTypeEffect(
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_id'],
      )!,
      effectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}effect_id'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
    );
  }

  @override
  $SdeTypeEffectsTable createAlias(String alias) {
    return $SdeTypeEffectsTable(attachedDatabase, alias);
  }
}

class SdeTypeEffect extends DataClass implements Insertable<SdeTypeEffect> {
  final int typeId;
  final int effectId;
  final bool isDefault;
  const SdeTypeEffect({
    required this.typeId,
    required this.effectId,
    required this.isDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type_id'] = Variable<int>(typeId);
    map['effect_id'] = Variable<int>(effectId);
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  SdeTypeEffectsCompanion toCompanion(bool nullToAbsent) {
    return SdeTypeEffectsCompanion(
      typeId: Value(typeId),
      effectId: Value(effectId),
      isDefault: Value(isDefault),
    );
  }

  factory SdeTypeEffect.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeTypeEffect(
      typeId: serializer.fromJson<int>(json['typeId']),
      effectId: serializer.fromJson<int>(json['effectId']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'typeId': serializer.toJson<int>(typeId),
      'effectId': serializer.toJson<int>(effectId),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  SdeTypeEffect copyWith({int? typeId, int? effectId, bool? isDefault}) =>
      SdeTypeEffect(
        typeId: typeId ?? this.typeId,
        effectId: effectId ?? this.effectId,
        isDefault: isDefault ?? this.isDefault,
      );
  SdeTypeEffect copyWithCompanion(SdeTypeEffectsCompanion data) {
    return SdeTypeEffect(
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      effectId: data.effectId.present ? data.effectId.value : this.effectId,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeTypeEffect(')
          ..write('typeId: $typeId, ')
          ..write('effectId: $effectId, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(typeId, effectId, isDefault);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeTypeEffect &&
          other.typeId == this.typeId &&
          other.effectId == this.effectId &&
          other.isDefault == this.isDefault);
}

class SdeTypeEffectsCompanion extends UpdateCompanion<SdeTypeEffect> {
  final Value<int> typeId;
  final Value<int> effectId;
  final Value<bool> isDefault;
  final Value<int> rowid;
  const SdeTypeEffectsCompanion({
    this.typeId = const Value.absent(),
    this.effectId = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SdeTypeEffectsCompanion.insert({
    required int typeId,
    required int effectId,
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : typeId = Value(typeId),
       effectId = Value(effectId);
  static Insertable<SdeTypeEffect> custom({
    Expression<int>? typeId,
    Expression<int>? effectId,
    Expression<bool>? isDefault,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (typeId != null) 'type_id': typeId,
      if (effectId != null) 'effect_id': effectId,
      if (isDefault != null) 'is_default': isDefault,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SdeTypeEffectsCompanion copyWith({
    Value<int>? typeId,
    Value<int>? effectId,
    Value<bool>? isDefault,
    Value<int>? rowid,
  }) {
    return SdeTypeEffectsCompanion(
      typeId: typeId ?? this.typeId,
      effectId: effectId ?? this.effectId,
      isDefault: isDefault ?? this.isDefault,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (typeId.present) {
      map['type_id'] = Variable<int>(typeId.value);
    }
    if (effectId.present) {
      map['effect_id'] = Variable<int>(effectId.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeTypeEffectsCompanion(')
          ..write('typeId: $typeId, ')
          ..write('effectId: $effectId, ')
          ..write('isDefault: $isDefault, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SdeEffectModifiersTable extends SdeEffectModifiers
    with TableInfo<$SdeEffectModifiersTable, SdeEffectModifier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeEffectModifiersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _effectIdMeta = const VerificationMeta(
    'effectId',
  );
  @override
  late final GeneratedColumn<int> effectId = GeneratedColumn<int>(
    'effect_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _funcMeta = const VerificationMeta('func');
  @override
  late final GeneratedColumn<String> func = GeneratedColumn<String>(
    'func',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operatorMeta = const VerificationMeta(
    'operator',
  );
  @override
  late final GeneratedColumn<int> operator = GeneratedColumn<int>(
    'operator',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedAttributeIdMeta =
      const VerificationMeta('modifiedAttributeId');
  @override
  late final GeneratedColumn<int> modifiedAttributeId = GeneratedColumn<int>(
    'modified_attribute_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifyingAttributeIdMeta =
      const VerificationMeta('modifyingAttributeId');
  @override
  late final GeneratedColumn<int> modifyingAttributeId = GeneratedColumn<int>(
    'modifying_attribute_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _domainMeta = const VerificationMeta('domain');
  @override
  late final GeneratedColumn<String> domain = GeneratedColumn<String>(
    'domain',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('shipID'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    effectId,
    func,
    operator,
    modifiedAttributeId,
    modifyingAttributeId,
    domain,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_effect_modifiers';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeEffectModifier> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('effect_id')) {
      context.handle(
        _effectIdMeta,
        effectId.isAcceptableOrUnknown(data['effect_id']!, _effectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_effectIdMeta);
    }
    if (data.containsKey('func')) {
      context.handle(
        _funcMeta,
        func.isAcceptableOrUnknown(data['func']!, _funcMeta),
      );
    } else if (isInserting) {
      context.missing(_funcMeta);
    }
    if (data.containsKey('operator')) {
      context.handle(
        _operatorMeta,
        operator.isAcceptableOrUnknown(data['operator']!, _operatorMeta),
      );
    } else if (isInserting) {
      context.missing(_operatorMeta);
    }
    if (data.containsKey('modified_attribute_id')) {
      context.handle(
        _modifiedAttributeIdMeta,
        modifiedAttributeId.isAcceptableOrUnknown(
          data['modified_attribute_id']!,
          _modifiedAttributeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modifiedAttributeIdMeta);
    }
    if (data.containsKey('modifying_attribute_id')) {
      context.handle(
        _modifyingAttributeIdMeta,
        modifyingAttributeId.isAcceptableOrUnknown(
          data['modifying_attribute_id']!,
          _modifyingAttributeIdMeta,
        ),
      );
    }
    if (data.containsKey('domain')) {
      context.handle(
        _domainMeta,
        domain.isAcceptableOrUnknown(data['domain']!, _domainMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SdeEffectModifier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeEffectModifier(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      effectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}effect_id'],
      )!,
      func: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}func'],
      )!,
      operator: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}operator'],
      )!,
      modifiedAttributeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_attribute_id'],
      )!,
      modifyingAttributeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modifying_attribute_id'],
      ),
      domain: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}domain'],
      )!,
    );
  }

  @override
  $SdeEffectModifiersTable createAlias(String alias) {
    return $SdeEffectModifiersTable(attachedDatabase, alias);
  }
}

class SdeEffectModifier extends DataClass
    implements Insertable<SdeEffectModifier> {
  final int id;
  final int effectId;
  final String func;
  final int operator;
  final int modifiedAttributeId;
  final int? modifyingAttributeId;
  final String domain;
  const SdeEffectModifier({
    required this.id,
    required this.effectId,
    required this.func,
    required this.operator,
    required this.modifiedAttributeId,
    this.modifyingAttributeId,
    required this.domain,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['effect_id'] = Variable<int>(effectId);
    map['func'] = Variable<String>(func);
    map['operator'] = Variable<int>(operator);
    map['modified_attribute_id'] = Variable<int>(modifiedAttributeId);
    if (!nullToAbsent || modifyingAttributeId != null) {
      map['modifying_attribute_id'] = Variable<int>(modifyingAttributeId);
    }
    map['domain'] = Variable<String>(domain);
    return map;
  }

  SdeEffectModifiersCompanion toCompanion(bool nullToAbsent) {
    return SdeEffectModifiersCompanion(
      id: Value(id),
      effectId: Value(effectId),
      func: Value(func),
      operator: Value(operator),
      modifiedAttributeId: Value(modifiedAttributeId),
      modifyingAttributeId: modifyingAttributeId == null && nullToAbsent
          ? const Value.absent()
          : Value(modifyingAttributeId),
      domain: Value(domain),
    );
  }

  factory SdeEffectModifier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeEffectModifier(
      id: serializer.fromJson<int>(json['id']),
      effectId: serializer.fromJson<int>(json['effectId']),
      func: serializer.fromJson<String>(json['func']),
      operator: serializer.fromJson<int>(json['operator']),
      modifiedAttributeId: serializer.fromJson<int>(
        json['modifiedAttributeId'],
      ),
      modifyingAttributeId: serializer.fromJson<int?>(
        json['modifyingAttributeId'],
      ),
      domain: serializer.fromJson<String>(json['domain']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'effectId': serializer.toJson<int>(effectId),
      'func': serializer.toJson<String>(func),
      'operator': serializer.toJson<int>(operator),
      'modifiedAttributeId': serializer.toJson<int>(modifiedAttributeId),
      'modifyingAttributeId': serializer.toJson<int?>(modifyingAttributeId),
      'domain': serializer.toJson<String>(domain),
    };
  }

  SdeEffectModifier copyWith({
    int? id,
    int? effectId,
    String? func,
    int? operator,
    int? modifiedAttributeId,
    Value<int?> modifyingAttributeId = const Value.absent(),
    String? domain,
  }) => SdeEffectModifier(
    id: id ?? this.id,
    effectId: effectId ?? this.effectId,
    func: func ?? this.func,
    operator: operator ?? this.operator,
    modifiedAttributeId: modifiedAttributeId ?? this.modifiedAttributeId,
    modifyingAttributeId: modifyingAttributeId.present
        ? modifyingAttributeId.value
        : this.modifyingAttributeId,
    domain: domain ?? this.domain,
  );
  SdeEffectModifier copyWithCompanion(SdeEffectModifiersCompanion data) {
    return SdeEffectModifier(
      id: data.id.present ? data.id.value : this.id,
      effectId: data.effectId.present ? data.effectId.value : this.effectId,
      func: data.func.present ? data.func.value : this.func,
      operator: data.operator.present ? data.operator.value : this.operator,
      modifiedAttributeId: data.modifiedAttributeId.present
          ? data.modifiedAttributeId.value
          : this.modifiedAttributeId,
      modifyingAttributeId: data.modifyingAttributeId.present
          ? data.modifyingAttributeId.value
          : this.modifyingAttributeId,
      domain: data.domain.present ? data.domain.value : this.domain,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeEffectModifier(')
          ..write('id: $id, ')
          ..write('effectId: $effectId, ')
          ..write('func: $func, ')
          ..write('operator: $operator, ')
          ..write('modifiedAttributeId: $modifiedAttributeId, ')
          ..write('modifyingAttributeId: $modifyingAttributeId, ')
          ..write('domain: $domain')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    effectId,
    func,
    operator,
    modifiedAttributeId,
    modifyingAttributeId,
    domain,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeEffectModifier &&
          other.id == this.id &&
          other.effectId == this.effectId &&
          other.func == this.func &&
          other.operator == this.operator &&
          other.modifiedAttributeId == this.modifiedAttributeId &&
          other.modifyingAttributeId == this.modifyingAttributeId &&
          other.domain == this.domain);
}

class SdeEffectModifiersCompanion extends UpdateCompanion<SdeEffectModifier> {
  final Value<int> id;
  final Value<int> effectId;
  final Value<String> func;
  final Value<int> operator;
  final Value<int> modifiedAttributeId;
  final Value<int?> modifyingAttributeId;
  final Value<String> domain;
  const SdeEffectModifiersCompanion({
    this.id = const Value.absent(),
    this.effectId = const Value.absent(),
    this.func = const Value.absent(),
    this.operator = const Value.absent(),
    this.modifiedAttributeId = const Value.absent(),
    this.modifyingAttributeId = const Value.absent(),
    this.domain = const Value.absent(),
  });
  SdeEffectModifiersCompanion.insert({
    this.id = const Value.absent(),
    required int effectId,
    required String func,
    required int operator,
    required int modifiedAttributeId,
    this.modifyingAttributeId = const Value.absent(),
    this.domain = const Value.absent(),
  }) : effectId = Value(effectId),
       func = Value(func),
       operator = Value(operator),
       modifiedAttributeId = Value(modifiedAttributeId);
  static Insertable<SdeEffectModifier> custom({
    Expression<int>? id,
    Expression<int>? effectId,
    Expression<String>? func,
    Expression<int>? operator,
    Expression<int>? modifiedAttributeId,
    Expression<int>? modifyingAttributeId,
    Expression<String>? domain,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (effectId != null) 'effect_id': effectId,
      if (func != null) 'func': func,
      if (operator != null) 'operator': operator,
      if (modifiedAttributeId != null)
        'modified_attribute_id': modifiedAttributeId,
      if (modifyingAttributeId != null)
        'modifying_attribute_id': modifyingAttributeId,
      if (domain != null) 'domain': domain,
    });
  }

  SdeEffectModifiersCompanion copyWith({
    Value<int>? id,
    Value<int>? effectId,
    Value<String>? func,
    Value<int>? operator,
    Value<int>? modifiedAttributeId,
    Value<int?>? modifyingAttributeId,
    Value<String>? domain,
  }) {
    return SdeEffectModifiersCompanion(
      id: id ?? this.id,
      effectId: effectId ?? this.effectId,
      func: func ?? this.func,
      operator: operator ?? this.operator,
      modifiedAttributeId: modifiedAttributeId ?? this.modifiedAttributeId,
      modifyingAttributeId: modifyingAttributeId ?? this.modifyingAttributeId,
      domain: domain ?? this.domain,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (effectId.present) {
      map['effect_id'] = Variable<int>(effectId.value);
    }
    if (func.present) {
      map['func'] = Variable<String>(func.value);
    }
    if (operator.present) {
      map['operator'] = Variable<int>(operator.value);
    }
    if (modifiedAttributeId.present) {
      map['modified_attribute_id'] = Variable<int>(modifiedAttributeId.value);
    }
    if (modifyingAttributeId.present) {
      map['modifying_attribute_id'] = Variable<int>(modifyingAttributeId.value);
    }
    if (domain.present) {
      map['domain'] = Variable<String>(domain.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeEffectModifiersCompanion(')
          ..write('id: $id, ')
          ..write('effectId: $effectId, ')
          ..write('func: $func, ')
          ..write('operator: $operator, ')
          ..write('modifiedAttributeId: $modifiedAttributeId, ')
          ..write('modifyingAttributeId: $modifyingAttributeId, ')
          ..write('domain: $domain')
          ..write(')'))
        .toString();
  }
}

class $SdeIndustryActivitiesTable extends SdeIndustryActivities
    with TableInfo<$SdeIndustryActivitiesTable, SdeIndustryActivity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeIndustryActivitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<int> typeId = GeneratedColumn<int>(
    'type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<int> activityId = GeneratedColumn<int>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [typeId, activityId, time];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_industry_activities';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeIndustryActivity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {typeId, activityId};
  @override
  SdeIndustryActivity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeIndustryActivity(
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activity_id'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time'],
      )!,
    );
  }

  @override
  $SdeIndustryActivitiesTable createAlias(String alias) {
    return $SdeIndustryActivitiesTable(attachedDatabase, alias);
  }
}

class SdeIndustryActivity extends DataClass
    implements Insertable<SdeIndustryActivity> {
  final int typeId;
  final int activityId;
  final int time;
  const SdeIndustryActivity({
    required this.typeId,
    required this.activityId,
    required this.time,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type_id'] = Variable<int>(typeId);
    map['activity_id'] = Variable<int>(activityId);
    map['time'] = Variable<int>(time);
    return map;
  }

  SdeIndustryActivitiesCompanion toCompanion(bool nullToAbsent) {
    return SdeIndustryActivitiesCompanion(
      typeId: Value(typeId),
      activityId: Value(activityId),
      time: Value(time),
    );
  }

  factory SdeIndustryActivity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeIndustryActivity(
      typeId: serializer.fromJson<int>(json['typeId']),
      activityId: serializer.fromJson<int>(json['activityId']),
      time: serializer.fromJson<int>(json['time']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'typeId': serializer.toJson<int>(typeId),
      'activityId': serializer.toJson<int>(activityId),
      'time': serializer.toJson<int>(time),
    };
  }

  SdeIndustryActivity copyWith({int? typeId, int? activityId, int? time}) =>
      SdeIndustryActivity(
        typeId: typeId ?? this.typeId,
        activityId: activityId ?? this.activityId,
        time: time ?? this.time,
      );
  SdeIndustryActivity copyWithCompanion(SdeIndustryActivitiesCompanion data) {
    return SdeIndustryActivity(
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      time: data.time.present ? data.time.value : this.time,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeIndustryActivity(')
          ..write('typeId: $typeId, ')
          ..write('activityId: $activityId, ')
          ..write('time: $time')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(typeId, activityId, time);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeIndustryActivity &&
          other.typeId == this.typeId &&
          other.activityId == this.activityId &&
          other.time == this.time);
}

class SdeIndustryActivitiesCompanion
    extends UpdateCompanion<SdeIndustryActivity> {
  final Value<int> typeId;
  final Value<int> activityId;
  final Value<int> time;
  final Value<int> rowid;
  const SdeIndustryActivitiesCompanion({
    this.typeId = const Value.absent(),
    this.activityId = const Value.absent(),
    this.time = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SdeIndustryActivitiesCompanion.insert({
    required int typeId,
    required int activityId,
    required int time,
    this.rowid = const Value.absent(),
  }) : typeId = Value(typeId),
       activityId = Value(activityId),
       time = Value(time);
  static Insertable<SdeIndustryActivity> custom({
    Expression<int>? typeId,
    Expression<int>? activityId,
    Expression<int>? time,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (typeId != null) 'type_id': typeId,
      if (activityId != null) 'activity_id': activityId,
      if (time != null) 'time': time,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SdeIndustryActivitiesCompanion copyWith({
    Value<int>? typeId,
    Value<int>? activityId,
    Value<int>? time,
    Value<int>? rowid,
  }) {
    return SdeIndustryActivitiesCompanion(
      typeId: typeId ?? this.typeId,
      activityId: activityId ?? this.activityId,
      time: time ?? this.time,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (typeId.present) {
      map['type_id'] = Variable<int>(typeId.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<int>(activityId.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeIndustryActivitiesCompanion(')
          ..write('typeId: $typeId, ')
          ..write('activityId: $activityId, ')
          ..write('time: $time, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SdeIndustryActivityMaterialsTable extends SdeIndustryActivityMaterials
    with
        TableInfo<
          $SdeIndustryActivityMaterialsTable,
          SdeIndustryActivityMaterial
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeIndustryActivityMaterialsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<int> typeId = GeneratedColumn<int>(
    'type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<int> activityId = GeneratedColumn<int>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _materialTypeIdMeta = const VerificationMeta(
    'materialTypeId',
  );
  @override
  late final GeneratedColumn<int> materialTypeId = GeneratedColumn<int>(
    'material_type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    typeId,
    activityId,
    materialTypeId,
    quantity,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_industry_activity_materials';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeIndustryActivityMaterial> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('material_type_id')) {
      context.handle(
        _materialTypeIdMeta,
        materialTypeId.isAcceptableOrUnknown(
          data['material_type_id']!,
          _materialTypeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_materialTypeIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {typeId, activityId, materialTypeId};
  @override
  SdeIndustryActivityMaterial map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeIndustryActivityMaterial(
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activity_id'],
      )!,
      materialTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}material_type_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
    );
  }

  @override
  $SdeIndustryActivityMaterialsTable createAlias(String alias) {
    return $SdeIndustryActivityMaterialsTable(attachedDatabase, alias);
  }
}

class SdeIndustryActivityMaterial extends DataClass
    implements Insertable<SdeIndustryActivityMaterial> {
  final int typeId;
  final int activityId;
  final int materialTypeId;
  final int quantity;
  const SdeIndustryActivityMaterial({
    required this.typeId,
    required this.activityId,
    required this.materialTypeId,
    required this.quantity,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type_id'] = Variable<int>(typeId);
    map['activity_id'] = Variable<int>(activityId);
    map['material_type_id'] = Variable<int>(materialTypeId);
    map['quantity'] = Variable<int>(quantity);
    return map;
  }

  SdeIndustryActivityMaterialsCompanion toCompanion(bool nullToAbsent) {
    return SdeIndustryActivityMaterialsCompanion(
      typeId: Value(typeId),
      activityId: Value(activityId),
      materialTypeId: Value(materialTypeId),
      quantity: Value(quantity),
    );
  }

  factory SdeIndustryActivityMaterial.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeIndustryActivityMaterial(
      typeId: serializer.fromJson<int>(json['typeId']),
      activityId: serializer.fromJson<int>(json['activityId']),
      materialTypeId: serializer.fromJson<int>(json['materialTypeId']),
      quantity: serializer.fromJson<int>(json['quantity']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'typeId': serializer.toJson<int>(typeId),
      'activityId': serializer.toJson<int>(activityId),
      'materialTypeId': serializer.toJson<int>(materialTypeId),
      'quantity': serializer.toJson<int>(quantity),
    };
  }

  SdeIndustryActivityMaterial copyWith({
    int? typeId,
    int? activityId,
    int? materialTypeId,
    int? quantity,
  }) => SdeIndustryActivityMaterial(
    typeId: typeId ?? this.typeId,
    activityId: activityId ?? this.activityId,
    materialTypeId: materialTypeId ?? this.materialTypeId,
    quantity: quantity ?? this.quantity,
  );
  SdeIndustryActivityMaterial copyWithCompanion(
    SdeIndustryActivityMaterialsCompanion data,
  ) {
    return SdeIndustryActivityMaterial(
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      materialTypeId: data.materialTypeId.present
          ? data.materialTypeId.value
          : this.materialTypeId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeIndustryActivityMaterial(')
          ..write('typeId: $typeId, ')
          ..write('activityId: $activityId, ')
          ..write('materialTypeId: $materialTypeId, ')
          ..write('quantity: $quantity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(typeId, activityId, materialTypeId, quantity);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeIndustryActivityMaterial &&
          other.typeId == this.typeId &&
          other.activityId == this.activityId &&
          other.materialTypeId == this.materialTypeId &&
          other.quantity == this.quantity);
}

class SdeIndustryActivityMaterialsCompanion
    extends UpdateCompanion<SdeIndustryActivityMaterial> {
  final Value<int> typeId;
  final Value<int> activityId;
  final Value<int> materialTypeId;
  final Value<int> quantity;
  final Value<int> rowid;
  const SdeIndustryActivityMaterialsCompanion({
    this.typeId = const Value.absent(),
    this.activityId = const Value.absent(),
    this.materialTypeId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SdeIndustryActivityMaterialsCompanion.insert({
    required int typeId,
    required int activityId,
    required int materialTypeId,
    required int quantity,
    this.rowid = const Value.absent(),
  }) : typeId = Value(typeId),
       activityId = Value(activityId),
       materialTypeId = Value(materialTypeId),
       quantity = Value(quantity);
  static Insertable<SdeIndustryActivityMaterial> custom({
    Expression<int>? typeId,
    Expression<int>? activityId,
    Expression<int>? materialTypeId,
    Expression<int>? quantity,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (typeId != null) 'type_id': typeId,
      if (activityId != null) 'activity_id': activityId,
      if (materialTypeId != null) 'material_type_id': materialTypeId,
      if (quantity != null) 'quantity': quantity,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SdeIndustryActivityMaterialsCompanion copyWith({
    Value<int>? typeId,
    Value<int>? activityId,
    Value<int>? materialTypeId,
    Value<int>? quantity,
    Value<int>? rowid,
  }) {
    return SdeIndustryActivityMaterialsCompanion(
      typeId: typeId ?? this.typeId,
      activityId: activityId ?? this.activityId,
      materialTypeId: materialTypeId ?? this.materialTypeId,
      quantity: quantity ?? this.quantity,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (typeId.present) {
      map['type_id'] = Variable<int>(typeId.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<int>(activityId.value);
    }
    if (materialTypeId.present) {
      map['material_type_id'] = Variable<int>(materialTypeId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeIndustryActivityMaterialsCompanion(')
          ..write('typeId: $typeId, ')
          ..write('activityId: $activityId, ')
          ..write('materialTypeId: $materialTypeId, ')
          ..write('quantity: $quantity, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SdeIndustryActivityProbabilitiesTable
    extends SdeIndustryActivityProbabilities
    with
        TableInfo<
          $SdeIndustryActivityProbabilitiesTable,
          SdeIndustryActivityProbability
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeIndustryActivityProbabilitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<int> typeId = GeneratedColumn<int>(
    'type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<int> activityId = GeneratedColumn<int>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productTypeIdMeta = const VerificationMeta(
    'productTypeId',
  );
  @override
  late final GeneratedColumn<int> productTypeId = GeneratedColumn<int>(
    'product_type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _probabilityMeta = const VerificationMeta(
    'probability',
  );
  @override
  late final GeneratedColumn<double> probability = GeneratedColumn<double>(
    'probability',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    typeId,
    activityId,
    productTypeId,
    probability,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_industry_activity_probabilities';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeIndustryActivityProbability> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('product_type_id')) {
      context.handle(
        _productTypeIdMeta,
        productTypeId.isAcceptableOrUnknown(
          data['product_type_id']!,
          _productTypeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productTypeIdMeta);
    }
    if (data.containsKey('probability')) {
      context.handle(
        _probabilityMeta,
        probability.isAcceptableOrUnknown(
          data['probability']!,
          _probabilityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_probabilityMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {typeId, activityId, productTypeId};
  @override
  SdeIndustryActivityProbability map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeIndustryActivityProbability(
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activity_id'],
      )!,
      productTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}product_type_id'],
      )!,
      probability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}probability'],
      )!,
    );
  }

  @override
  $SdeIndustryActivityProbabilitiesTable createAlias(String alias) {
    return $SdeIndustryActivityProbabilitiesTable(attachedDatabase, alias);
  }
}

class SdeIndustryActivityProbability extends DataClass
    implements Insertable<SdeIndustryActivityProbability> {
  final int typeId;
  final int activityId;
  final int productTypeId;
  final double probability;
  const SdeIndustryActivityProbability({
    required this.typeId,
    required this.activityId,
    required this.productTypeId,
    required this.probability,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type_id'] = Variable<int>(typeId);
    map['activity_id'] = Variable<int>(activityId);
    map['product_type_id'] = Variable<int>(productTypeId);
    map['probability'] = Variable<double>(probability);
    return map;
  }

  SdeIndustryActivityProbabilitiesCompanion toCompanion(bool nullToAbsent) {
    return SdeIndustryActivityProbabilitiesCompanion(
      typeId: Value(typeId),
      activityId: Value(activityId),
      productTypeId: Value(productTypeId),
      probability: Value(probability),
    );
  }

  factory SdeIndustryActivityProbability.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeIndustryActivityProbability(
      typeId: serializer.fromJson<int>(json['typeId']),
      activityId: serializer.fromJson<int>(json['activityId']),
      productTypeId: serializer.fromJson<int>(json['productTypeId']),
      probability: serializer.fromJson<double>(json['probability']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'typeId': serializer.toJson<int>(typeId),
      'activityId': serializer.toJson<int>(activityId),
      'productTypeId': serializer.toJson<int>(productTypeId),
      'probability': serializer.toJson<double>(probability),
    };
  }

  SdeIndustryActivityProbability copyWith({
    int? typeId,
    int? activityId,
    int? productTypeId,
    double? probability,
  }) => SdeIndustryActivityProbability(
    typeId: typeId ?? this.typeId,
    activityId: activityId ?? this.activityId,
    productTypeId: productTypeId ?? this.productTypeId,
    probability: probability ?? this.probability,
  );
  SdeIndustryActivityProbability copyWithCompanion(
    SdeIndustryActivityProbabilitiesCompanion data,
  ) {
    return SdeIndustryActivityProbability(
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      productTypeId: data.productTypeId.present
          ? data.productTypeId.value
          : this.productTypeId,
      probability: data.probability.present
          ? data.probability.value
          : this.probability,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeIndustryActivityProbability(')
          ..write('typeId: $typeId, ')
          ..write('activityId: $activityId, ')
          ..write('productTypeId: $productTypeId, ')
          ..write('probability: $probability')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(typeId, activityId, productTypeId, probability);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeIndustryActivityProbability &&
          other.typeId == this.typeId &&
          other.activityId == this.activityId &&
          other.productTypeId == this.productTypeId &&
          other.probability == this.probability);
}

class SdeIndustryActivityProbabilitiesCompanion
    extends UpdateCompanion<SdeIndustryActivityProbability> {
  final Value<int> typeId;
  final Value<int> activityId;
  final Value<int> productTypeId;
  final Value<double> probability;
  final Value<int> rowid;
  const SdeIndustryActivityProbabilitiesCompanion({
    this.typeId = const Value.absent(),
    this.activityId = const Value.absent(),
    this.productTypeId = const Value.absent(),
    this.probability = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SdeIndustryActivityProbabilitiesCompanion.insert({
    required int typeId,
    required int activityId,
    required int productTypeId,
    required double probability,
    this.rowid = const Value.absent(),
  }) : typeId = Value(typeId),
       activityId = Value(activityId),
       productTypeId = Value(productTypeId),
       probability = Value(probability);
  static Insertable<SdeIndustryActivityProbability> custom({
    Expression<int>? typeId,
    Expression<int>? activityId,
    Expression<int>? productTypeId,
    Expression<double>? probability,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (typeId != null) 'type_id': typeId,
      if (activityId != null) 'activity_id': activityId,
      if (productTypeId != null) 'product_type_id': productTypeId,
      if (probability != null) 'probability': probability,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SdeIndustryActivityProbabilitiesCompanion copyWith({
    Value<int>? typeId,
    Value<int>? activityId,
    Value<int>? productTypeId,
    Value<double>? probability,
    Value<int>? rowid,
  }) {
    return SdeIndustryActivityProbabilitiesCompanion(
      typeId: typeId ?? this.typeId,
      activityId: activityId ?? this.activityId,
      productTypeId: productTypeId ?? this.productTypeId,
      probability: probability ?? this.probability,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (typeId.present) {
      map['type_id'] = Variable<int>(typeId.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<int>(activityId.value);
    }
    if (productTypeId.present) {
      map['product_type_id'] = Variable<int>(productTypeId.value);
    }
    if (probability.present) {
      map['probability'] = Variable<double>(probability.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeIndustryActivityProbabilitiesCompanion(')
          ..write('typeId: $typeId, ')
          ..write('activityId: $activityId, ')
          ..write('productTypeId: $productTypeId, ')
          ..write('probability: $probability, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SdeIndustryActivityProductsTable extends SdeIndustryActivityProducts
    with
        TableInfo<
          $SdeIndustryActivityProductsTable,
          SdeIndustryActivityProduct
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeIndustryActivityProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<int> typeId = GeneratedColumn<int>(
    'type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<int> activityId = GeneratedColumn<int>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productTypeIdMeta = const VerificationMeta(
    'productTypeId',
  );
  @override
  late final GeneratedColumn<int> productTypeId = GeneratedColumn<int>(
    'product_type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    typeId,
    activityId,
    productTypeId,
    quantity,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_industry_activity_products';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeIndustryActivityProduct> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('product_type_id')) {
      context.handle(
        _productTypeIdMeta,
        productTypeId.isAcceptableOrUnknown(
          data['product_type_id']!,
          _productTypeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productTypeIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {typeId, activityId, productTypeId};
  @override
  SdeIndustryActivityProduct map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeIndustryActivityProduct(
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activity_id'],
      )!,
      productTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}product_type_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
    );
  }

  @override
  $SdeIndustryActivityProductsTable createAlias(String alias) {
    return $SdeIndustryActivityProductsTable(attachedDatabase, alias);
  }
}

class SdeIndustryActivityProduct extends DataClass
    implements Insertable<SdeIndustryActivityProduct> {
  final int typeId;
  final int activityId;
  final int productTypeId;
  final int quantity;
  const SdeIndustryActivityProduct({
    required this.typeId,
    required this.activityId,
    required this.productTypeId,
    required this.quantity,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type_id'] = Variable<int>(typeId);
    map['activity_id'] = Variable<int>(activityId);
    map['product_type_id'] = Variable<int>(productTypeId);
    map['quantity'] = Variable<int>(quantity);
    return map;
  }

  SdeIndustryActivityProductsCompanion toCompanion(bool nullToAbsent) {
    return SdeIndustryActivityProductsCompanion(
      typeId: Value(typeId),
      activityId: Value(activityId),
      productTypeId: Value(productTypeId),
      quantity: Value(quantity),
    );
  }

  factory SdeIndustryActivityProduct.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeIndustryActivityProduct(
      typeId: serializer.fromJson<int>(json['typeId']),
      activityId: serializer.fromJson<int>(json['activityId']),
      productTypeId: serializer.fromJson<int>(json['productTypeId']),
      quantity: serializer.fromJson<int>(json['quantity']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'typeId': serializer.toJson<int>(typeId),
      'activityId': serializer.toJson<int>(activityId),
      'productTypeId': serializer.toJson<int>(productTypeId),
      'quantity': serializer.toJson<int>(quantity),
    };
  }

  SdeIndustryActivityProduct copyWith({
    int? typeId,
    int? activityId,
    int? productTypeId,
    int? quantity,
  }) => SdeIndustryActivityProduct(
    typeId: typeId ?? this.typeId,
    activityId: activityId ?? this.activityId,
    productTypeId: productTypeId ?? this.productTypeId,
    quantity: quantity ?? this.quantity,
  );
  SdeIndustryActivityProduct copyWithCompanion(
    SdeIndustryActivityProductsCompanion data,
  ) {
    return SdeIndustryActivityProduct(
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      productTypeId: data.productTypeId.present
          ? data.productTypeId.value
          : this.productTypeId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeIndustryActivityProduct(')
          ..write('typeId: $typeId, ')
          ..write('activityId: $activityId, ')
          ..write('productTypeId: $productTypeId, ')
          ..write('quantity: $quantity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(typeId, activityId, productTypeId, quantity);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeIndustryActivityProduct &&
          other.typeId == this.typeId &&
          other.activityId == this.activityId &&
          other.productTypeId == this.productTypeId &&
          other.quantity == this.quantity);
}

class SdeIndustryActivityProductsCompanion
    extends UpdateCompanion<SdeIndustryActivityProduct> {
  final Value<int> typeId;
  final Value<int> activityId;
  final Value<int> productTypeId;
  final Value<int> quantity;
  final Value<int> rowid;
  const SdeIndustryActivityProductsCompanion({
    this.typeId = const Value.absent(),
    this.activityId = const Value.absent(),
    this.productTypeId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SdeIndustryActivityProductsCompanion.insert({
    required int typeId,
    required int activityId,
    required int productTypeId,
    required int quantity,
    this.rowid = const Value.absent(),
  }) : typeId = Value(typeId),
       activityId = Value(activityId),
       productTypeId = Value(productTypeId),
       quantity = Value(quantity);
  static Insertable<SdeIndustryActivityProduct> custom({
    Expression<int>? typeId,
    Expression<int>? activityId,
    Expression<int>? productTypeId,
    Expression<int>? quantity,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (typeId != null) 'type_id': typeId,
      if (activityId != null) 'activity_id': activityId,
      if (productTypeId != null) 'product_type_id': productTypeId,
      if (quantity != null) 'quantity': quantity,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SdeIndustryActivityProductsCompanion copyWith({
    Value<int>? typeId,
    Value<int>? activityId,
    Value<int>? productTypeId,
    Value<int>? quantity,
    Value<int>? rowid,
  }) {
    return SdeIndustryActivityProductsCompanion(
      typeId: typeId ?? this.typeId,
      activityId: activityId ?? this.activityId,
      productTypeId: productTypeId ?? this.productTypeId,
      quantity: quantity ?? this.quantity,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (typeId.present) {
      map['type_id'] = Variable<int>(typeId.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<int>(activityId.value);
    }
    if (productTypeId.present) {
      map['product_type_id'] = Variable<int>(productTypeId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeIndustryActivityProductsCompanion(')
          ..write('typeId: $typeId, ')
          ..write('activityId: $activityId, ')
          ..write('productTypeId: $productTypeId, ')
          ..write('quantity: $quantity, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SdeIndustryActivitySkillsTable extends SdeIndustryActivitySkills
    with TableInfo<$SdeIndustryActivitySkillsTable, SdeIndustryActivitySkill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeIndustryActivitySkillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<int> typeId = GeneratedColumn<int>(
    'type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<int> activityId = GeneratedColumn<int>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skillIdMeta = const VerificationMeta(
    'skillId',
  );
  @override
  late final GeneratedColumn<int> skillId = GeneratedColumn<int>(
    'skill_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [typeId, activityId, skillId, level];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_industry_activity_skills';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeIndustryActivitySkill> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('skill_id')) {
      context.handle(
        _skillIdMeta,
        skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta),
      );
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {typeId, activityId, skillId};
  @override
  SdeIndustryActivitySkill map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeIndustryActivitySkill(
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activity_id'],
      )!,
      skillId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skill_id'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
    );
  }

  @override
  $SdeIndustryActivitySkillsTable createAlias(String alias) {
    return $SdeIndustryActivitySkillsTable(attachedDatabase, alias);
  }
}

class SdeIndustryActivitySkill extends DataClass
    implements Insertable<SdeIndustryActivitySkill> {
  final int typeId;
  final int activityId;
  final int skillId;
  final int level;
  const SdeIndustryActivitySkill({
    required this.typeId,
    required this.activityId,
    required this.skillId,
    required this.level,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type_id'] = Variable<int>(typeId);
    map['activity_id'] = Variable<int>(activityId);
    map['skill_id'] = Variable<int>(skillId);
    map['level'] = Variable<int>(level);
    return map;
  }

  SdeIndustryActivitySkillsCompanion toCompanion(bool nullToAbsent) {
    return SdeIndustryActivitySkillsCompanion(
      typeId: Value(typeId),
      activityId: Value(activityId),
      skillId: Value(skillId),
      level: Value(level),
    );
  }

  factory SdeIndustryActivitySkill.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeIndustryActivitySkill(
      typeId: serializer.fromJson<int>(json['typeId']),
      activityId: serializer.fromJson<int>(json['activityId']),
      skillId: serializer.fromJson<int>(json['skillId']),
      level: serializer.fromJson<int>(json['level']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'typeId': serializer.toJson<int>(typeId),
      'activityId': serializer.toJson<int>(activityId),
      'skillId': serializer.toJson<int>(skillId),
      'level': serializer.toJson<int>(level),
    };
  }

  SdeIndustryActivitySkill copyWith({
    int? typeId,
    int? activityId,
    int? skillId,
    int? level,
  }) => SdeIndustryActivitySkill(
    typeId: typeId ?? this.typeId,
    activityId: activityId ?? this.activityId,
    skillId: skillId ?? this.skillId,
    level: level ?? this.level,
  );
  SdeIndustryActivitySkill copyWithCompanion(
    SdeIndustryActivitySkillsCompanion data,
  ) {
    return SdeIndustryActivitySkill(
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      level: data.level.present ? data.level.value : this.level,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeIndustryActivitySkill(')
          ..write('typeId: $typeId, ')
          ..write('activityId: $activityId, ')
          ..write('skillId: $skillId, ')
          ..write('level: $level')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(typeId, activityId, skillId, level);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeIndustryActivitySkill &&
          other.typeId == this.typeId &&
          other.activityId == this.activityId &&
          other.skillId == this.skillId &&
          other.level == this.level);
}

class SdeIndustryActivitySkillsCompanion
    extends UpdateCompanion<SdeIndustryActivitySkill> {
  final Value<int> typeId;
  final Value<int> activityId;
  final Value<int> skillId;
  final Value<int> level;
  final Value<int> rowid;
  const SdeIndustryActivitySkillsCompanion({
    this.typeId = const Value.absent(),
    this.activityId = const Value.absent(),
    this.skillId = const Value.absent(),
    this.level = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SdeIndustryActivitySkillsCompanion.insert({
    required int typeId,
    required int activityId,
    required int skillId,
    required int level,
    this.rowid = const Value.absent(),
  }) : typeId = Value(typeId),
       activityId = Value(activityId),
       skillId = Value(skillId),
       level = Value(level);
  static Insertable<SdeIndustryActivitySkill> custom({
    Expression<int>? typeId,
    Expression<int>? activityId,
    Expression<int>? skillId,
    Expression<int>? level,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (typeId != null) 'type_id': typeId,
      if (activityId != null) 'activity_id': activityId,
      if (skillId != null) 'skill_id': skillId,
      if (level != null) 'level': level,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SdeIndustryActivitySkillsCompanion copyWith({
    Value<int>? typeId,
    Value<int>? activityId,
    Value<int>? skillId,
    Value<int>? level,
    Value<int>? rowid,
  }) {
    return SdeIndustryActivitySkillsCompanion(
      typeId: typeId ?? this.typeId,
      activityId: activityId ?? this.activityId,
      skillId: skillId ?? this.skillId,
      level: level ?? this.level,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (typeId.present) {
      map['type_id'] = Variable<int>(typeId.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<int>(activityId.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<int>(skillId.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeIndustryActivitySkillsCompanion(')
          ..write('typeId: $typeId, ')
          ..write('activityId: $activityId, ')
          ..write('skillId: $skillId, ')
          ..write('level: $level, ')
          ..write('rowid: $rowid')
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
  late final $SdeMetadataTable sdeMetadata = $SdeMetadataTable(this);
  late final $SdeSkillRequirementsTable sdeSkillRequirements =
      $SdeSkillRequirementsTable(this);
  late final $SdeTypeAttributesTable sdeTypeAttributes =
      $SdeTypeAttributesTable(this);
  late final $SdeTypeEffectsTable sdeTypeEffects = $SdeTypeEffectsTable(this);
  late final $SdeEffectModifiersTable sdeEffectModifiers =
      $SdeEffectModifiersTable(this);
  late final $SdeIndustryActivitiesTable sdeIndustryActivities =
      $SdeIndustryActivitiesTable(this);
  late final $SdeIndustryActivityMaterialsTable sdeIndustryActivityMaterials =
      $SdeIndustryActivityMaterialsTable(this);
  late final $SdeIndustryActivityProbabilitiesTable
  sdeIndustryActivityProbabilities = $SdeIndustryActivityProbabilitiesTable(
    this,
  );
  late final $SdeIndustryActivityProductsTable sdeIndustryActivityProducts =
      $SdeIndustryActivityProductsTable(this);
  late final $SdeIndustryActivitySkillsTable sdeIndustryActivitySkills =
      $SdeIndustryActivitySkillsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sdeTypes,
    sdeGroups,
    sdeCategories,
    sdeMetadata,
    sdeSkillRequirements,
    sdeTypeAttributes,
    sdeTypeEffects,
    sdeEffectModifiers,
    sdeIndustryActivities,
    sdeIndustryActivityMaterials,
    sdeIndustryActivityProbabilities,
    sdeIndustryActivityProducts,
    sdeIndustryActivitySkills,
  ];
}

typedef $$SdeTypesTableCreateCompanionBuilder =
    SdeTypesCompanion Function({
      Value<int> typeId,
      required String typeName,
      required int groupId,
      Value<String?> description,
      Value<int?> rank,
      Value<String?> primaryAttribute,
      Value<String?> secondaryAttribute,
    });
typedef $$SdeTypesTableUpdateCompanionBuilder =
    SdeTypesCompanion Function({
      Value<int> typeId,
      Value<String> typeName,
      Value<int> groupId,
      Value<String?> description,
      Value<int?> rank,
      Value<String?> primaryAttribute,
      Value<String?> secondaryAttribute,
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
    column: $table.typeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typeName => $composableBuilder(
    column: $table.typeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryAttribute => $composableBuilder(
    column: $table.primaryAttribute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryAttribute => $composableBuilder(
    column: $table.secondaryAttribute,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.typeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typeName => $composableBuilder(
    column: $table.typeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryAttribute => $composableBuilder(
    column: $table.primaryAttribute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryAttribute => $composableBuilder(
    column: $table.secondaryAttribute,
    builder: (column) => ColumnOrderings(column),
  );
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
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);

  GeneratedColumn<String> get primaryAttribute => $composableBuilder(
    column: $table.primaryAttribute,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secondaryAttribute => $composableBuilder(
    column: $table.secondaryAttribute,
    builder: (column) => column,
  );
}

class $$SdeTypesTableTableManager
    extends
        RootTableManager<
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
          PrefetchHooks Function()
        > {
  $$SdeTypesTableTableManager(_$SdeDatabase db, $SdeTypesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> typeId = const Value.absent(),
                Value<String> typeName = const Value.absent(),
                Value<int> groupId = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int?> rank = const Value.absent(),
                Value<String?> primaryAttribute = const Value.absent(),
                Value<String?> secondaryAttribute = const Value.absent(),
              }) => SdeTypesCompanion(
                typeId: typeId,
                typeName: typeName,
                groupId: groupId,
                description: description,
                rank: rank,
                primaryAttribute: primaryAttribute,
                secondaryAttribute: secondaryAttribute,
              ),
          createCompanionCallback:
              ({
                Value<int> typeId = const Value.absent(),
                required String typeName,
                required int groupId,
                Value<String?> description = const Value.absent(),
                Value<int?> rank = const Value.absent(),
                Value<String?> primaryAttribute = const Value.absent(),
                Value<String?> secondaryAttribute = const Value.absent(),
              }) => SdeTypesCompanion.insert(
                typeId: typeId,
                typeName: typeName,
                groupId: groupId,
                description: description,
                rank: rank,
                primaryAttribute: primaryAttribute,
                secondaryAttribute: secondaryAttribute,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeTypesTableProcessedTableManager =
    ProcessedTableManager<
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
      PrefetchHooks Function()
    >;
typedef $$SdeGroupsTableCreateCompanionBuilder =
    SdeGroupsCompanion Function({
      Value<int> groupId,
      required String groupName,
      required int categoryId,
    });
typedef $$SdeGroupsTableUpdateCompanionBuilder =
    SdeGroupsCompanion Function({
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
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );
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
    column: $table.categoryId,
    builder: (column) => column,
  );
}

class $$SdeGroupsTableTableManager
    extends
        RootTableManager<
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
          PrefetchHooks Function()
        > {
  $$SdeGroupsTableTableManager(_$SdeDatabase db, $SdeGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> groupId = const Value.absent(),
                Value<String> groupName = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
              }) => SdeGroupsCompanion(
                groupId: groupId,
                groupName: groupName,
                categoryId: categoryId,
              ),
          createCompanionCallback:
              ({
                Value<int> groupId = const Value.absent(),
                required String groupName,
                required int categoryId,
              }) => SdeGroupsCompanion.insert(
                groupId: groupId,
                groupName: groupName,
                categoryId: categoryId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeGroupsTableProcessedTableManager =
    ProcessedTableManager<
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
      PrefetchHooks Function()
    >;
typedef $$SdeCategoriesTableCreateCompanionBuilder =
    SdeCategoriesCompanion Function({
      Value<int> categoryId,
      required String categoryName,
    });
typedef $$SdeCategoriesTableUpdateCompanionBuilder =
    SdeCategoriesCompanion Function({
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
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnOrderings(column),
  );
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
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => column,
  );
}

class $$SdeCategoriesTableTableManager
    extends
        RootTableManager<
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
            BaseReferences<_$SdeDatabase, $SdeCategoriesTable, SdeCategory>,
          ),
          SdeCategory,
          PrefetchHooks Function()
        > {
  $$SdeCategoriesTableTableManager(_$SdeDatabase db, $SdeCategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> categoryId = const Value.absent(),
                Value<String> categoryName = const Value.absent(),
              }) => SdeCategoriesCompanion(
                categoryId: categoryId,
                categoryName: categoryName,
              ),
          createCompanionCallback:
              ({
                Value<int> categoryId = const Value.absent(),
                required String categoryName,
              }) => SdeCategoriesCompanion.insert(
                categoryId: categoryId,
                categoryName: categoryName,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeCategoriesTableProcessedTableManager =
    ProcessedTableManager<
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
        BaseReferences<_$SdeDatabase, $SdeCategoriesTable, SdeCategory>,
      ),
      SdeCategory,
      PrefetchHooks Function()
    >;
typedef $$SdeMetadataTableCreateCompanionBuilder =
    SdeMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SdeMetadataTableUpdateCompanionBuilder =
    SdeMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SdeMetadataTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeMetadataTable> {
  $$SdeMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeMetadataTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeMetadataTable> {
  $$SdeMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeMetadataTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeMetadataTable> {
  $$SdeMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SdeMetadataTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeMetadataTable,
          SdeMetadataData,
          $$SdeMetadataTableFilterComposer,
          $$SdeMetadataTableOrderingComposer,
          $$SdeMetadataTableAnnotationComposer,
          $$SdeMetadataTableCreateCompanionBuilder,
          $$SdeMetadataTableUpdateCompanionBuilder,
          (
            SdeMetadataData,
            BaseReferences<_$SdeDatabase, $SdeMetadataTable, SdeMetadataData>,
          ),
          SdeMetadataData,
          PrefetchHooks Function()
        > {
  $$SdeMetadataTableTableManager(_$SdeDatabase db, $SdeMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SdeMetadataCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SdeMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeMetadataTable,
      SdeMetadataData,
      $$SdeMetadataTableFilterComposer,
      $$SdeMetadataTableOrderingComposer,
      $$SdeMetadataTableAnnotationComposer,
      $$SdeMetadataTableCreateCompanionBuilder,
      $$SdeMetadataTableUpdateCompanionBuilder,
      (
        SdeMetadataData,
        BaseReferences<_$SdeDatabase, $SdeMetadataTable, SdeMetadataData>,
      ),
      SdeMetadataData,
      PrefetchHooks Function()
    >;
typedef $$SdeSkillRequirementsTableCreateCompanionBuilder =
    SdeSkillRequirementsCompanion Function({
      required int skillId,
      required int requiredSkillId,
      required int requiredLevel,
      Value<int> rowid,
    });
typedef $$SdeSkillRequirementsTableUpdateCompanionBuilder =
    SdeSkillRequirementsCompanion Function({
      Value<int> skillId,
      Value<int> requiredSkillId,
      Value<int> requiredLevel,
      Value<int> rowid,
    });

class $$SdeSkillRequirementsTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeSkillRequirementsTable> {
  $$SdeSkillRequirementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requiredSkillId => $composableBuilder(
    column: $table.requiredSkillId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requiredLevel => $composableBuilder(
    column: $table.requiredLevel,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeSkillRequirementsTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeSkillRequirementsTable> {
  $$SdeSkillRequirementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requiredSkillId => $composableBuilder(
    column: $table.requiredSkillId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requiredLevel => $composableBuilder(
    column: $table.requiredLevel,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeSkillRequirementsTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeSkillRequirementsTable> {
  $$SdeSkillRequirementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<int> get requiredSkillId => $composableBuilder(
    column: $table.requiredSkillId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get requiredLevel => $composableBuilder(
    column: $table.requiredLevel,
    builder: (column) => column,
  );
}

class $$SdeSkillRequirementsTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeSkillRequirementsTable,
          SdeSkillRequirement,
          $$SdeSkillRequirementsTableFilterComposer,
          $$SdeSkillRequirementsTableOrderingComposer,
          $$SdeSkillRequirementsTableAnnotationComposer,
          $$SdeSkillRequirementsTableCreateCompanionBuilder,
          $$SdeSkillRequirementsTableUpdateCompanionBuilder,
          (
            SdeSkillRequirement,
            BaseReferences<
              _$SdeDatabase,
              $SdeSkillRequirementsTable,
              SdeSkillRequirement
            >,
          ),
          SdeSkillRequirement,
          PrefetchHooks Function()
        > {
  $$SdeSkillRequirementsTableTableManager(
    _$SdeDatabase db,
    $SdeSkillRequirementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeSkillRequirementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeSkillRequirementsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SdeSkillRequirementsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> skillId = const Value.absent(),
                Value<int> requiredSkillId = const Value.absent(),
                Value<int> requiredLevel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SdeSkillRequirementsCompanion(
                skillId: skillId,
                requiredSkillId: requiredSkillId,
                requiredLevel: requiredLevel,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int skillId,
                required int requiredSkillId,
                required int requiredLevel,
                Value<int> rowid = const Value.absent(),
              }) => SdeSkillRequirementsCompanion.insert(
                skillId: skillId,
                requiredSkillId: requiredSkillId,
                requiredLevel: requiredLevel,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeSkillRequirementsTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeSkillRequirementsTable,
      SdeSkillRequirement,
      $$SdeSkillRequirementsTableFilterComposer,
      $$SdeSkillRequirementsTableOrderingComposer,
      $$SdeSkillRequirementsTableAnnotationComposer,
      $$SdeSkillRequirementsTableCreateCompanionBuilder,
      $$SdeSkillRequirementsTableUpdateCompanionBuilder,
      (
        SdeSkillRequirement,
        BaseReferences<
          _$SdeDatabase,
          $SdeSkillRequirementsTable,
          SdeSkillRequirement
        >,
      ),
      SdeSkillRequirement,
      PrefetchHooks Function()
    >;
typedef $$SdeTypeAttributesTableCreateCompanionBuilder =
    SdeTypeAttributesCompanion Function({
      required int typeId,
      required int attributeId,
      required double value,
      Value<int> rowid,
    });
typedef $$SdeTypeAttributesTableUpdateCompanionBuilder =
    SdeTypeAttributesCompanion Function({
      Value<int> typeId,
      Value<int> attributeId,
      Value<double> value,
      Value<int> rowid,
    });

class $$SdeTypeAttributesTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeTypeAttributesTable> {
  $$SdeTypeAttributesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attributeId => $composableBuilder(
    column: $table.attributeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeTypeAttributesTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeTypeAttributesTable> {
  $$SdeTypeAttributesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attributeId => $composableBuilder(
    column: $table.attributeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeTypeAttributesTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeTypeAttributesTable> {
  $$SdeTypeAttributesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<int> get attributeId => $composableBuilder(
    column: $table.attributeId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SdeTypeAttributesTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeTypeAttributesTable,
          SdeTypeAttribute,
          $$SdeTypeAttributesTableFilterComposer,
          $$SdeTypeAttributesTableOrderingComposer,
          $$SdeTypeAttributesTableAnnotationComposer,
          $$SdeTypeAttributesTableCreateCompanionBuilder,
          $$SdeTypeAttributesTableUpdateCompanionBuilder,
          (
            SdeTypeAttribute,
            BaseReferences<
              _$SdeDatabase,
              $SdeTypeAttributesTable,
              SdeTypeAttribute
            >,
          ),
          SdeTypeAttribute,
          PrefetchHooks Function()
        > {
  $$SdeTypeAttributesTableTableManager(
    _$SdeDatabase db,
    $SdeTypeAttributesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeTypeAttributesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeTypeAttributesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeTypeAttributesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> typeId = const Value.absent(),
                Value<int> attributeId = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SdeTypeAttributesCompanion(
                typeId: typeId,
                attributeId: attributeId,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int typeId,
                required int attributeId,
                required double value,
                Value<int> rowid = const Value.absent(),
              }) => SdeTypeAttributesCompanion.insert(
                typeId: typeId,
                attributeId: attributeId,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeTypeAttributesTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeTypeAttributesTable,
      SdeTypeAttribute,
      $$SdeTypeAttributesTableFilterComposer,
      $$SdeTypeAttributesTableOrderingComposer,
      $$SdeTypeAttributesTableAnnotationComposer,
      $$SdeTypeAttributesTableCreateCompanionBuilder,
      $$SdeTypeAttributesTableUpdateCompanionBuilder,
      (
        SdeTypeAttribute,
        BaseReferences<
          _$SdeDatabase,
          $SdeTypeAttributesTable,
          SdeTypeAttribute
        >,
      ),
      SdeTypeAttribute,
      PrefetchHooks Function()
    >;
typedef $$SdeTypeEffectsTableCreateCompanionBuilder =
    SdeTypeEffectsCompanion Function({
      required int typeId,
      required int effectId,
      Value<bool> isDefault,
      Value<int> rowid,
    });
typedef $$SdeTypeEffectsTableUpdateCompanionBuilder =
    SdeTypeEffectsCompanion Function({
      Value<int> typeId,
      Value<int> effectId,
      Value<bool> isDefault,
      Value<int> rowid,
    });

class $$SdeTypeEffectsTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeTypeEffectsTable> {
  $$SdeTypeEffectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get effectId => $composableBuilder(
    column: $table.effectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeTypeEffectsTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeTypeEffectsTable> {
  $$SdeTypeEffectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get effectId => $composableBuilder(
    column: $table.effectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeTypeEffectsTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeTypeEffectsTable> {
  $$SdeTypeEffectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<int> get effectId =>
      $composableBuilder(column: $table.effectId, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);
}

class $$SdeTypeEffectsTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeTypeEffectsTable,
          SdeTypeEffect,
          $$SdeTypeEffectsTableFilterComposer,
          $$SdeTypeEffectsTableOrderingComposer,
          $$SdeTypeEffectsTableAnnotationComposer,
          $$SdeTypeEffectsTableCreateCompanionBuilder,
          $$SdeTypeEffectsTableUpdateCompanionBuilder,
          (
            SdeTypeEffect,
            BaseReferences<_$SdeDatabase, $SdeTypeEffectsTable, SdeTypeEffect>,
          ),
          SdeTypeEffect,
          PrefetchHooks Function()
        > {
  $$SdeTypeEffectsTableTableManager(
    _$SdeDatabase db,
    $SdeTypeEffectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeTypeEffectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeTypeEffectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeTypeEffectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> typeId = const Value.absent(),
                Value<int> effectId = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SdeTypeEffectsCompanion(
                typeId: typeId,
                effectId: effectId,
                isDefault: isDefault,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int typeId,
                required int effectId,
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SdeTypeEffectsCompanion.insert(
                typeId: typeId,
                effectId: effectId,
                isDefault: isDefault,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeTypeEffectsTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeTypeEffectsTable,
      SdeTypeEffect,
      $$SdeTypeEffectsTableFilterComposer,
      $$SdeTypeEffectsTableOrderingComposer,
      $$SdeTypeEffectsTableAnnotationComposer,
      $$SdeTypeEffectsTableCreateCompanionBuilder,
      $$SdeTypeEffectsTableUpdateCompanionBuilder,
      (
        SdeTypeEffect,
        BaseReferences<_$SdeDatabase, $SdeTypeEffectsTable, SdeTypeEffect>,
      ),
      SdeTypeEffect,
      PrefetchHooks Function()
    >;
typedef $$SdeEffectModifiersTableCreateCompanionBuilder =
    SdeEffectModifiersCompanion Function({
      Value<int> id,
      required int effectId,
      required String func,
      required int operator,
      required int modifiedAttributeId,
      Value<int?> modifyingAttributeId,
      Value<String> domain,
    });
typedef $$SdeEffectModifiersTableUpdateCompanionBuilder =
    SdeEffectModifiersCompanion Function({
      Value<int> id,
      Value<int> effectId,
      Value<String> func,
      Value<int> operator,
      Value<int> modifiedAttributeId,
      Value<int?> modifyingAttributeId,
      Value<String> domain,
    });

class $$SdeEffectModifiersTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeEffectModifiersTable> {
  $$SdeEffectModifiersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get effectId => $composableBuilder(
    column: $table.effectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get func => $composableBuilder(
    column: $table.func,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get operator => $composableBuilder(
    column: $table.operator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifiedAttributeId => $composableBuilder(
    column: $table.modifiedAttributeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifyingAttributeId => $composableBuilder(
    column: $table.modifyingAttributeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get domain => $composableBuilder(
    column: $table.domain,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeEffectModifiersTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeEffectModifiersTable> {
  $$SdeEffectModifiersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get effectId => $composableBuilder(
    column: $table.effectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get func => $composableBuilder(
    column: $table.func,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get operator => $composableBuilder(
    column: $table.operator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifiedAttributeId => $composableBuilder(
    column: $table.modifiedAttributeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifyingAttributeId => $composableBuilder(
    column: $table.modifyingAttributeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get domain => $composableBuilder(
    column: $table.domain,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeEffectModifiersTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeEffectModifiersTable> {
  $$SdeEffectModifiersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get effectId =>
      $composableBuilder(column: $table.effectId, builder: (column) => column);

  GeneratedColumn<String> get func =>
      $composableBuilder(column: $table.func, builder: (column) => column);

  GeneratedColumn<int> get operator =>
      $composableBuilder(column: $table.operator, builder: (column) => column);

  GeneratedColumn<int> get modifiedAttributeId => $composableBuilder(
    column: $table.modifiedAttributeId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get modifyingAttributeId => $composableBuilder(
    column: $table.modifyingAttributeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get domain =>
      $composableBuilder(column: $table.domain, builder: (column) => column);
}

class $$SdeEffectModifiersTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeEffectModifiersTable,
          SdeEffectModifier,
          $$SdeEffectModifiersTableFilterComposer,
          $$SdeEffectModifiersTableOrderingComposer,
          $$SdeEffectModifiersTableAnnotationComposer,
          $$SdeEffectModifiersTableCreateCompanionBuilder,
          $$SdeEffectModifiersTableUpdateCompanionBuilder,
          (
            SdeEffectModifier,
            BaseReferences<
              _$SdeDatabase,
              $SdeEffectModifiersTable,
              SdeEffectModifier
            >,
          ),
          SdeEffectModifier,
          PrefetchHooks Function()
        > {
  $$SdeEffectModifiersTableTableManager(
    _$SdeDatabase db,
    $SdeEffectModifiersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeEffectModifiersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeEffectModifiersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeEffectModifiersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> effectId = const Value.absent(),
                Value<String> func = const Value.absent(),
                Value<int> operator = const Value.absent(),
                Value<int> modifiedAttributeId = const Value.absent(),
                Value<int?> modifyingAttributeId = const Value.absent(),
                Value<String> domain = const Value.absent(),
              }) => SdeEffectModifiersCompanion(
                id: id,
                effectId: effectId,
                func: func,
                operator: operator,
                modifiedAttributeId: modifiedAttributeId,
                modifyingAttributeId: modifyingAttributeId,
                domain: domain,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int effectId,
                required String func,
                required int operator,
                required int modifiedAttributeId,
                Value<int?> modifyingAttributeId = const Value.absent(),
                Value<String> domain = const Value.absent(),
              }) => SdeEffectModifiersCompanion.insert(
                id: id,
                effectId: effectId,
                func: func,
                operator: operator,
                modifiedAttributeId: modifiedAttributeId,
                modifyingAttributeId: modifyingAttributeId,
                domain: domain,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeEffectModifiersTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeEffectModifiersTable,
      SdeEffectModifier,
      $$SdeEffectModifiersTableFilterComposer,
      $$SdeEffectModifiersTableOrderingComposer,
      $$SdeEffectModifiersTableAnnotationComposer,
      $$SdeEffectModifiersTableCreateCompanionBuilder,
      $$SdeEffectModifiersTableUpdateCompanionBuilder,
      (
        SdeEffectModifier,
        BaseReferences<
          _$SdeDatabase,
          $SdeEffectModifiersTable,
          SdeEffectModifier
        >,
      ),
      SdeEffectModifier,
      PrefetchHooks Function()
    >;
typedef $$SdeIndustryActivitiesTableCreateCompanionBuilder =
    SdeIndustryActivitiesCompanion Function({
      required int typeId,
      required int activityId,
      required int time,
      Value<int> rowid,
    });
typedef $$SdeIndustryActivitiesTableUpdateCompanionBuilder =
    SdeIndustryActivitiesCompanion Function({
      Value<int> typeId,
      Value<int> activityId,
      Value<int> time,
      Value<int> rowid,
    });

class $$SdeIndustryActivitiesTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivitiesTable> {
  $$SdeIndustryActivitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeIndustryActivitiesTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivitiesTable> {
  $$SdeIndustryActivitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeIndustryActivitiesTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivitiesTable> {
  $$SdeIndustryActivitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);
}

class $$SdeIndustryActivitiesTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeIndustryActivitiesTable,
          SdeIndustryActivity,
          $$SdeIndustryActivitiesTableFilterComposer,
          $$SdeIndustryActivitiesTableOrderingComposer,
          $$SdeIndustryActivitiesTableAnnotationComposer,
          $$SdeIndustryActivitiesTableCreateCompanionBuilder,
          $$SdeIndustryActivitiesTableUpdateCompanionBuilder,
          (
            SdeIndustryActivity,
            BaseReferences<
              _$SdeDatabase,
              $SdeIndustryActivitiesTable,
              SdeIndustryActivity
            >,
          ),
          SdeIndustryActivity,
          PrefetchHooks Function()
        > {
  $$SdeIndustryActivitiesTableTableManager(
    _$SdeDatabase db,
    $SdeIndustryActivitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeIndustryActivitiesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SdeIndustryActivitiesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SdeIndustryActivitiesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> typeId = const Value.absent(),
                Value<int> activityId = const Value.absent(),
                Value<int> time = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SdeIndustryActivitiesCompanion(
                typeId: typeId,
                activityId: activityId,
                time: time,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int typeId,
                required int activityId,
                required int time,
                Value<int> rowid = const Value.absent(),
              }) => SdeIndustryActivitiesCompanion.insert(
                typeId: typeId,
                activityId: activityId,
                time: time,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeIndustryActivitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeIndustryActivitiesTable,
      SdeIndustryActivity,
      $$SdeIndustryActivitiesTableFilterComposer,
      $$SdeIndustryActivitiesTableOrderingComposer,
      $$SdeIndustryActivitiesTableAnnotationComposer,
      $$SdeIndustryActivitiesTableCreateCompanionBuilder,
      $$SdeIndustryActivitiesTableUpdateCompanionBuilder,
      (
        SdeIndustryActivity,
        BaseReferences<
          _$SdeDatabase,
          $SdeIndustryActivitiesTable,
          SdeIndustryActivity
        >,
      ),
      SdeIndustryActivity,
      PrefetchHooks Function()
    >;
typedef $$SdeIndustryActivityMaterialsTableCreateCompanionBuilder =
    SdeIndustryActivityMaterialsCompanion Function({
      required int typeId,
      required int activityId,
      required int materialTypeId,
      required int quantity,
      Value<int> rowid,
    });
typedef $$SdeIndustryActivityMaterialsTableUpdateCompanionBuilder =
    SdeIndustryActivityMaterialsCompanion Function({
      Value<int> typeId,
      Value<int> activityId,
      Value<int> materialTypeId,
      Value<int> quantity,
      Value<int> rowid,
    });

class $$SdeIndustryActivityMaterialsTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivityMaterialsTable> {
  $$SdeIndustryActivityMaterialsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get materialTypeId => $composableBuilder(
    column: $table.materialTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeIndustryActivityMaterialsTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivityMaterialsTable> {
  $$SdeIndustryActivityMaterialsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get materialTypeId => $composableBuilder(
    column: $table.materialTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeIndustryActivityMaterialsTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivityMaterialsTable> {
  $$SdeIndustryActivityMaterialsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get materialTypeId => $composableBuilder(
    column: $table.materialTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);
}

class $$SdeIndustryActivityMaterialsTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeIndustryActivityMaterialsTable,
          SdeIndustryActivityMaterial,
          $$SdeIndustryActivityMaterialsTableFilterComposer,
          $$SdeIndustryActivityMaterialsTableOrderingComposer,
          $$SdeIndustryActivityMaterialsTableAnnotationComposer,
          $$SdeIndustryActivityMaterialsTableCreateCompanionBuilder,
          $$SdeIndustryActivityMaterialsTableUpdateCompanionBuilder,
          (
            SdeIndustryActivityMaterial,
            BaseReferences<
              _$SdeDatabase,
              $SdeIndustryActivityMaterialsTable,
              SdeIndustryActivityMaterial
            >,
          ),
          SdeIndustryActivityMaterial,
          PrefetchHooks Function()
        > {
  $$SdeIndustryActivityMaterialsTableTableManager(
    _$SdeDatabase db,
    $SdeIndustryActivityMaterialsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeIndustryActivityMaterialsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SdeIndustryActivityMaterialsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SdeIndustryActivityMaterialsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> typeId = const Value.absent(),
                Value<int> activityId = const Value.absent(),
                Value<int> materialTypeId = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SdeIndustryActivityMaterialsCompanion(
                typeId: typeId,
                activityId: activityId,
                materialTypeId: materialTypeId,
                quantity: quantity,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int typeId,
                required int activityId,
                required int materialTypeId,
                required int quantity,
                Value<int> rowid = const Value.absent(),
              }) => SdeIndustryActivityMaterialsCompanion.insert(
                typeId: typeId,
                activityId: activityId,
                materialTypeId: materialTypeId,
                quantity: quantity,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeIndustryActivityMaterialsTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeIndustryActivityMaterialsTable,
      SdeIndustryActivityMaterial,
      $$SdeIndustryActivityMaterialsTableFilterComposer,
      $$SdeIndustryActivityMaterialsTableOrderingComposer,
      $$SdeIndustryActivityMaterialsTableAnnotationComposer,
      $$SdeIndustryActivityMaterialsTableCreateCompanionBuilder,
      $$SdeIndustryActivityMaterialsTableUpdateCompanionBuilder,
      (
        SdeIndustryActivityMaterial,
        BaseReferences<
          _$SdeDatabase,
          $SdeIndustryActivityMaterialsTable,
          SdeIndustryActivityMaterial
        >,
      ),
      SdeIndustryActivityMaterial,
      PrefetchHooks Function()
    >;
typedef $$SdeIndustryActivityProbabilitiesTableCreateCompanionBuilder =
    SdeIndustryActivityProbabilitiesCompanion Function({
      required int typeId,
      required int activityId,
      required int productTypeId,
      required double probability,
      Value<int> rowid,
    });
typedef $$SdeIndustryActivityProbabilitiesTableUpdateCompanionBuilder =
    SdeIndustryActivityProbabilitiesCompanion Function({
      Value<int> typeId,
      Value<int> activityId,
      Value<int> productTypeId,
      Value<double> probability,
      Value<int> rowid,
    });

class $$SdeIndustryActivityProbabilitiesTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivityProbabilitiesTable> {
  $$SdeIndustryActivityProbabilitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get productTypeId => $composableBuilder(
    column: $table.productTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get probability => $composableBuilder(
    column: $table.probability,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeIndustryActivityProbabilitiesTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivityProbabilitiesTable> {
  $$SdeIndustryActivityProbabilitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get productTypeId => $composableBuilder(
    column: $table.productTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get probability => $composableBuilder(
    column: $table.probability,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeIndustryActivityProbabilitiesTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivityProbabilitiesTable> {
  $$SdeIndustryActivityProbabilitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get productTypeId => $composableBuilder(
    column: $table.productTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get probability => $composableBuilder(
    column: $table.probability,
    builder: (column) => column,
  );
}

class $$SdeIndustryActivityProbabilitiesTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeIndustryActivityProbabilitiesTable,
          SdeIndustryActivityProbability,
          $$SdeIndustryActivityProbabilitiesTableFilterComposer,
          $$SdeIndustryActivityProbabilitiesTableOrderingComposer,
          $$SdeIndustryActivityProbabilitiesTableAnnotationComposer,
          $$SdeIndustryActivityProbabilitiesTableCreateCompanionBuilder,
          $$SdeIndustryActivityProbabilitiesTableUpdateCompanionBuilder,
          (
            SdeIndustryActivityProbability,
            BaseReferences<
              _$SdeDatabase,
              $SdeIndustryActivityProbabilitiesTable,
              SdeIndustryActivityProbability
            >,
          ),
          SdeIndustryActivityProbability,
          PrefetchHooks Function()
        > {
  $$SdeIndustryActivityProbabilitiesTableTableManager(
    _$SdeDatabase db,
    $SdeIndustryActivityProbabilitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeIndustryActivityProbabilitiesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SdeIndustryActivityProbabilitiesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SdeIndustryActivityProbabilitiesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> typeId = const Value.absent(),
                Value<int> activityId = const Value.absent(),
                Value<int> productTypeId = const Value.absent(),
                Value<double> probability = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SdeIndustryActivityProbabilitiesCompanion(
                typeId: typeId,
                activityId: activityId,
                productTypeId: productTypeId,
                probability: probability,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int typeId,
                required int activityId,
                required int productTypeId,
                required double probability,
                Value<int> rowid = const Value.absent(),
              }) => SdeIndustryActivityProbabilitiesCompanion.insert(
                typeId: typeId,
                activityId: activityId,
                productTypeId: productTypeId,
                probability: probability,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeIndustryActivityProbabilitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeIndustryActivityProbabilitiesTable,
      SdeIndustryActivityProbability,
      $$SdeIndustryActivityProbabilitiesTableFilterComposer,
      $$SdeIndustryActivityProbabilitiesTableOrderingComposer,
      $$SdeIndustryActivityProbabilitiesTableAnnotationComposer,
      $$SdeIndustryActivityProbabilitiesTableCreateCompanionBuilder,
      $$SdeIndustryActivityProbabilitiesTableUpdateCompanionBuilder,
      (
        SdeIndustryActivityProbability,
        BaseReferences<
          _$SdeDatabase,
          $SdeIndustryActivityProbabilitiesTable,
          SdeIndustryActivityProbability
        >,
      ),
      SdeIndustryActivityProbability,
      PrefetchHooks Function()
    >;
typedef $$SdeIndustryActivityProductsTableCreateCompanionBuilder =
    SdeIndustryActivityProductsCompanion Function({
      required int typeId,
      required int activityId,
      required int productTypeId,
      required int quantity,
      Value<int> rowid,
    });
typedef $$SdeIndustryActivityProductsTableUpdateCompanionBuilder =
    SdeIndustryActivityProductsCompanion Function({
      Value<int> typeId,
      Value<int> activityId,
      Value<int> productTypeId,
      Value<int> quantity,
      Value<int> rowid,
    });

class $$SdeIndustryActivityProductsTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivityProductsTable> {
  $$SdeIndustryActivityProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get productTypeId => $composableBuilder(
    column: $table.productTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeIndustryActivityProductsTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivityProductsTable> {
  $$SdeIndustryActivityProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get productTypeId => $composableBuilder(
    column: $table.productTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeIndustryActivityProductsTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivityProductsTable> {
  $$SdeIndustryActivityProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get productTypeId => $composableBuilder(
    column: $table.productTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);
}

class $$SdeIndustryActivityProductsTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeIndustryActivityProductsTable,
          SdeIndustryActivityProduct,
          $$SdeIndustryActivityProductsTableFilterComposer,
          $$SdeIndustryActivityProductsTableOrderingComposer,
          $$SdeIndustryActivityProductsTableAnnotationComposer,
          $$SdeIndustryActivityProductsTableCreateCompanionBuilder,
          $$SdeIndustryActivityProductsTableUpdateCompanionBuilder,
          (
            SdeIndustryActivityProduct,
            BaseReferences<
              _$SdeDatabase,
              $SdeIndustryActivityProductsTable,
              SdeIndustryActivityProduct
            >,
          ),
          SdeIndustryActivityProduct,
          PrefetchHooks Function()
        > {
  $$SdeIndustryActivityProductsTableTableManager(
    _$SdeDatabase db,
    $SdeIndustryActivityProductsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeIndustryActivityProductsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SdeIndustryActivityProductsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SdeIndustryActivityProductsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> typeId = const Value.absent(),
                Value<int> activityId = const Value.absent(),
                Value<int> productTypeId = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SdeIndustryActivityProductsCompanion(
                typeId: typeId,
                activityId: activityId,
                productTypeId: productTypeId,
                quantity: quantity,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int typeId,
                required int activityId,
                required int productTypeId,
                required int quantity,
                Value<int> rowid = const Value.absent(),
              }) => SdeIndustryActivityProductsCompanion.insert(
                typeId: typeId,
                activityId: activityId,
                productTypeId: productTypeId,
                quantity: quantity,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeIndustryActivityProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeIndustryActivityProductsTable,
      SdeIndustryActivityProduct,
      $$SdeIndustryActivityProductsTableFilterComposer,
      $$SdeIndustryActivityProductsTableOrderingComposer,
      $$SdeIndustryActivityProductsTableAnnotationComposer,
      $$SdeIndustryActivityProductsTableCreateCompanionBuilder,
      $$SdeIndustryActivityProductsTableUpdateCompanionBuilder,
      (
        SdeIndustryActivityProduct,
        BaseReferences<
          _$SdeDatabase,
          $SdeIndustryActivityProductsTable,
          SdeIndustryActivityProduct
        >,
      ),
      SdeIndustryActivityProduct,
      PrefetchHooks Function()
    >;
typedef $$SdeIndustryActivitySkillsTableCreateCompanionBuilder =
    SdeIndustryActivitySkillsCompanion Function({
      required int typeId,
      required int activityId,
      required int skillId,
      required int level,
      Value<int> rowid,
    });
typedef $$SdeIndustryActivitySkillsTableUpdateCompanionBuilder =
    SdeIndustryActivitySkillsCompanion Function({
      Value<int> typeId,
      Value<int> activityId,
      Value<int> skillId,
      Value<int> level,
      Value<int> rowid,
    });

class $$SdeIndustryActivitySkillsTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivitySkillsTable> {
  $$SdeIndustryActivitySkillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeIndustryActivitySkillsTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivitySkillsTable> {
  $$SdeIndustryActivitySkillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeIndustryActivitySkillsTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeIndustryActivitySkillsTable> {
  $$SdeIndustryActivitySkillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<int> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);
}

class $$SdeIndustryActivitySkillsTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeIndustryActivitySkillsTable,
          SdeIndustryActivitySkill,
          $$SdeIndustryActivitySkillsTableFilterComposer,
          $$SdeIndustryActivitySkillsTableOrderingComposer,
          $$SdeIndustryActivitySkillsTableAnnotationComposer,
          $$SdeIndustryActivitySkillsTableCreateCompanionBuilder,
          $$SdeIndustryActivitySkillsTableUpdateCompanionBuilder,
          (
            SdeIndustryActivitySkill,
            BaseReferences<
              _$SdeDatabase,
              $SdeIndustryActivitySkillsTable,
              SdeIndustryActivitySkill
            >,
          ),
          SdeIndustryActivitySkill,
          PrefetchHooks Function()
        > {
  $$SdeIndustryActivitySkillsTableTableManager(
    _$SdeDatabase db,
    $SdeIndustryActivitySkillsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeIndustryActivitySkillsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SdeIndustryActivitySkillsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SdeIndustryActivitySkillsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> typeId = const Value.absent(),
                Value<int> activityId = const Value.absent(),
                Value<int> skillId = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SdeIndustryActivitySkillsCompanion(
                typeId: typeId,
                activityId: activityId,
                skillId: skillId,
                level: level,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int typeId,
                required int activityId,
                required int skillId,
                required int level,
                Value<int> rowid = const Value.absent(),
              }) => SdeIndustryActivitySkillsCompanion.insert(
                typeId: typeId,
                activityId: activityId,
                skillId: skillId,
                level: level,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeIndustryActivitySkillsTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeIndustryActivitySkillsTable,
      SdeIndustryActivitySkill,
      $$SdeIndustryActivitySkillsTableFilterComposer,
      $$SdeIndustryActivitySkillsTableOrderingComposer,
      $$SdeIndustryActivitySkillsTableAnnotationComposer,
      $$SdeIndustryActivitySkillsTableCreateCompanionBuilder,
      $$SdeIndustryActivitySkillsTableUpdateCompanionBuilder,
      (
        SdeIndustryActivitySkill,
        BaseReferences<
          _$SdeDatabase,
          $SdeIndustryActivitySkillsTable,
          SdeIndustryActivitySkill
        >,
      ),
      SdeIndustryActivitySkill,
      PrefetchHooks Function()
    >;

class $SdeDatabaseManager {
  final _$SdeDatabase _db;
  $SdeDatabaseManager(this._db);
  $$SdeTypesTableTableManager get sdeTypes =>
      $$SdeTypesTableTableManager(_db, _db.sdeTypes);
  $$SdeGroupsTableTableManager get sdeGroups =>
      $$SdeGroupsTableTableManager(_db, _db.sdeGroups);
  $$SdeCategoriesTableTableManager get sdeCategories =>
      $$SdeCategoriesTableTableManager(_db, _db.sdeCategories);
  $$SdeMetadataTableTableManager get sdeMetadata =>
      $$SdeMetadataTableTableManager(_db, _db.sdeMetadata);
  $$SdeSkillRequirementsTableTableManager get sdeSkillRequirements =>
      $$SdeSkillRequirementsTableTableManager(_db, _db.sdeSkillRequirements);
  $$SdeTypeAttributesTableTableManager get sdeTypeAttributes =>
      $$SdeTypeAttributesTableTableManager(_db, _db.sdeTypeAttributes);
  $$SdeTypeEffectsTableTableManager get sdeTypeEffects =>
      $$SdeTypeEffectsTableTableManager(_db, _db.sdeTypeEffects);
  $$SdeEffectModifiersTableTableManager get sdeEffectModifiers =>
      $$SdeEffectModifiersTableTableManager(_db, _db.sdeEffectModifiers);
  $$SdeIndustryActivitiesTableTableManager get sdeIndustryActivities =>
      $$SdeIndustryActivitiesTableTableManager(_db, _db.sdeIndustryActivities);
  $$SdeIndustryActivityMaterialsTableTableManager
  get sdeIndustryActivityMaterials =>
      $$SdeIndustryActivityMaterialsTableTableManager(
        _db,
        _db.sdeIndustryActivityMaterials,
      );
  $$SdeIndustryActivityProbabilitiesTableTableManager
  get sdeIndustryActivityProbabilities =>
      $$SdeIndustryActivityProbabilitiesTableTableManager(
        _db,
        _db.sdeIndustryActivityProbabilities,
      );
  $$SdeIndustryActivityProductsTableTableManager
  get sdeIndustryActivityProducts =>
      $$SdeIndustryActivityProductsTableTableManager(
        _db,
        _db.sdeIndustryActivityProducts,
      );
  $$SdeIndustryActivitySkillsTableTableManager get sdeIndustryActivitySkills =>
      $$SdeIndustryActivitySkillsTableTableManager(
        _db,
        _db.sdeIndustryActivitySkills,
      );
}
