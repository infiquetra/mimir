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

class $SdeWormholeTypesTable extends SdeWormholeTypes
    with TableInfo<$SdeWormholeTypesTable, SdeWormholeType> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeWormholeTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<int> typeId = GeneratedColumn<int>(
    'type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
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
    requiredDuringInsert: false,
    defaultValue: const Constant(988),
  );
  static const VerificationMeta _publishedMeta = const VerificationMeta(
    'published',
  );
  @override
  late final GeneratedColumn<bool> published = GeneratedColumn<bool>(
    'published',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("published" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _rawTargetClassMeta = const VerificationMeta(
    'rawTargetClass',
  );
  @override
  late final GeneratedColumn<int> rawTargetClass = GeneratedColumn<int>(
    'raw_target_class',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawTargetDistributionMeta =
      const VerificationMeta('rawTargetDistribution');
  @override
  late final GeneratedColumn<int> rawTargetDistribution = GeneratedColumn<int>(
    'raw_target_distribution',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reliableLifetimeSecondsMeta =
      const VerificationMeta('reliableLifetimeSeconds');
  @override
  late final GeneratedColumn<int> reliableLifetimeSeconds =
      GeneratedColumn<int>(
        'reliable_lifetime_seconds',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _maxJumpMassKgMeta = const VerificationMeta(
    'maxJumpMassKg',
  );
  @override
  late final GeneratedColumn<double> maxJumpMassKg = GeneratedColumn<double>(
    'max_jump_mass_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalMassKgMeta = const VerificationMeta(
    'totalMassKg',
  );
  @override
  late final GeneratedColumn<double> totalMassKg = GeneratedColumn<double>(
    'total_mass_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regenerationKgPerCycleMeta =
      const VerificationMeta('regenerationKgPerCycle');
  @override
  late final GeneratedColumn<double> regenerationKgPerCycle =
      GeneratedColumn<double>(
        'regeneration_kg_per_cycle',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    typeId,
    code,
    name,
    groupId,
    published,
    rawTargetClass,
    rawTargetDistribution,
    reliableLifetimeSeconds,
    maxJumpMassKg,
    totalMassKg,
    regenerationKgPerCycle,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_wormhole_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeWormholeType> instance, {
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
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('published')) {
      context.handle(
        _publishedMeta,
        published.isAcceptableOrUnknown(data['published']!, _publishedMeta),
      );
    }
    if (data.containsKey('raw_target_class')) {
      context.handle(
        _rawTargetClassMeta,
        rawTargetClass.isAcceptableOrUnknown(
          data['raw_target_class']!,
          _rawTargetClassMeta,
        ),
      );
    }
    if (data.containsKey('raw_target_distribution')) {
      context.handle(
        _rawTargetDistributionMeta,
        rawTargetDistribution.isAcceptableOrUnknown(
          data['raw_target_distribution']!,
          _rawTargetDistributionMeta,
        ),
      );
    }
    if (data.containsKey('reliable_lifetime_seconds')) {
      context.handle(
        _reliableLifetimeSecondsMeta,
        reliableLifetimeSeconds.isAcceptableOrUnknown(
          data['reliable_lifetime_seconds']!,
          _reliableLifetimeSecondsMeta,
        ),
      );
    }
    if (data.containsKey('max_jump_mass_kg')) {
      context.handle(
        _maxJumpMassKgMeta,
        maxJumpMassKg.isAcceptableOrUnknown(
          data['max_jump_mass_kg']!,
          _maxJumpMassKgMeta,
        ),
      );
    }
    if (data.containsKey('total_mass_kg')) {
      context.handle(
        _totalMassKgMeta,
        totalMassKg.isAcceptableOrUnknown(
          data['total_mass_kg']!,
          _totalMassKgMeta,
        ),
      );
    }
    if (data.containsKey('regeneration_kg_per_cycle')) {
      context.handle(
        _regenerationKgPerCycleMeta,
        regenerationKgPerCycle.isAcceptableOrUnknown(
          data['regeneration_kg_per_cycle']!,
          _regenerationKgPerCycleMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {typeId};
  @override
  SdeWormholeType map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeWormholeType(
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      )!,
      published: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}published'],
      )!,
      rawTargetClass: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}raw_target_class'],
      ),
      rawTargetDistribution: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}raw_target_distribution'],
      ),
      reliableLifetimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reliable_lifetime_seconds'],
      ),
      maxJumpMassKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_jump_mass_kg'],
      ),
      totalMassKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_mass_kg'],
      ),
      regenerationKgPerCycle: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}regeneration_kg_per_cycle'],
      ),
    );
  }

  @override
  $SdeWormholeTypesTable createAlias(String alias) {
    return $SdeWormholeTypesTable(attachedDatabase, alias);
  }
}

class SdeWormholeType extends DataClass implements Insertable<SdeWormholeType> {
  final int typeId;
  final String code;
  final String name;
  final int groupId;
  final bool published;
  final int? rawTargetClass;
  final int? rawTargetDistribution;
  final int? reliableLifetimeSeconds;
  final double? maxJumpMassKg;
  final double? totalMassKg;
  final double? regenerationKgPerCycle;
  const SdeWormholeType({
    required this.typeId,
    required this.code,
    required this.name,
    required this.groupId,
    required this.published,
    this.rawTargetClass,
    this.rawTargetDistribution,
    this.reliableLifetimeSeconds,
    this.maxJumpMassKg,
    this.totalMassKg,
    this.regenerationKgPerCycle,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type_id'] = Variable<int>(typeId);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['group_id'] = Variable<int>(groupId);
    map['published'] = Variable<bool>(published);
    if (!nullToAbsent || rawTargetClass != null) {
      map['raw_target_class'] = Variable<int>(rawTargetClass);
    }
    if (!nullToAbsent || rawTargetDistribution != null) {
      map['raw_target_distribution'] = Variable<int>(rawTargetDistribution);
    }
    if (!nullToAbsent || reliableLifetimeSeconds != null) {
      map['reliable_lifetime_seconds'] = Variable<int>(reliableLifetimeSeconds);
    }
    if (!nullToAbsent || maxJumpMassKg != null) {
      map['max_jump_mass_kg'] = Variable<double>(maxJumpMassKg);
    }
    if (!nullToAbsent || totalMassKg != null) {
      map['total_mass_kg'] = Variable<double>(totalMassKg);
    }
    if (!nullToAbsent || regenerationKgPerCycle != null) {
      map['regeneration_kg_per_cycle'] = Variable<double>(
        regenerationKgPerCycle,
      );
    }
    return map;
  }

  SdeWormholeTypesCompanion toCompanion(bool nullToAbsent) {
    return SdeWormholeTypesCompanion(
      typeId: Value(typeId),
      code: Value(code),
      name: Value(name),
      groupId: Value(groupId),
      published: Value(published),
      rawTargetClass: rawTargetClass == null && nullToAbsent
          ? const Value.absent()
          : Value(rawTargetClass),
      rawTargetDistribution: rawTargetDistribution == null && nullToAbsent
          ? const Value.absent()
          : Value(rawTargetDistribution),
      reliableLifetimeSeconds: reliableLifetimeSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(reliableLifetimeSeconds),
      maxJumpMassKg: maxJumpMassKg == null && nullToAbsent
          ? const Value.absent()
          : Value(maxJumpMassKg),
      totalMassKg: totalMassKg == null && nullToAbsent
          ? const Value.absent()
          : Value(totalMassKg),
      regenerationKgPerCycle: regenerationKgPerCycle == null && nullToAbsent
          ? const Value.absent()
          : Value(regenerationKgPerCycle),
    );
  }

  factory SdeWormholeType.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeWormholeType(
      typeId: serializer.fromJson<int>(json['typeId']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      groupId: serializer.fromJson<int>(json['groupId']),
      published: serializer.fromJson<bool>(json['published']),
      rawTargetClass: serializer.fromJson<int?>(json['rawTargetClass']),
      rawTargetDistribution: serializer.fromJson<int?>(
        json['rawTargetDistribution'],
      ),
      reliableLifetimeSeconds: serializer.fromJson<int?>(
        json['reliableLifetimeSeconds'],
      ),
      maxJumpMassKg: serializer.fromJson<double?>(json['maxJumpMassKg']),
      totalMassKg: serializer.fromJson<double?>(json['totalMassKg']),
      regenerationKgPerCycle: serializer.fromJson<double?>(
        json['regenerationKgPerCycle'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'typeId': serializer.toJson<int>(typeId),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'groupId': serializer.toJson<int>(groupId),
      'published': serializer.toJson<bool>(published),
      'rawTargetClass': serializer.toJson<int?>(rawTargetClass),
      'rawTargetDistribution': serializer.toJson<int?>(rawTargetDistribution),
      'reliableLifetimeSeconds': serializer.toJson<int?>(
        reliableLifetimeSeconds,
      ),
      'maxJumpMassKg': serializer.toJson<double?>(maxJumpMassKg),
      'totalMassKg': serializer.toJson<double?>(totalMassKg),
      'regenerationKgPerCycle': serializer.toJson<double?>(
        regenerationKgPerCycle,
      ),
    };
  }

  SdeWormholeType copyWith({
    int? typeId,
    String? code,
    String? name,
    int? groupId,
    bool? published,
    Value<int?> rawTargetClass = const Value.absent(),
    Value<int?> rawTargetDistribution = const Value.absent(),
    Value<int?> reliableLifetimeSeconds = const Value.absent(),
    Value<double?> maxJumpMassKg = const Value.absent(),
    Value<double?> totalMassKg = const Value.absent(),
    Value<double?> regenerationKgPerCycle = const Value.absent(),
  }) => SdeWormholeType(
    typeId: typeId ?? this.typeId,
    code: code ?? this.code,
    name: name ?? this.name,
    groupId: groupId ?? this.groupId,
    published: published ?? this.published,
    rawTargetClass: rawTargetClass.present
        ? rawTargetClass.value
        : this.rawTargetClass,
    rawTargetDistribution: rawTargetDistribution.present
        ? rawTargetDistribution.value
        : this.rawTargetDistribution,
    reliableLifetimeSeconds: reliableLifetimeSeconds.present
        ? reliableLifetimeSeconds.value
        : this.reliableLifetimeSeconds,
    maxJumpMassKg: maxJumpMassKg.present
        ? maxJumpMassKg.value
        : this.maxJumpMassKg,
    totalMassKg: totalMassKg.present ? totalMassKg.value : this.totalMassKg,
    regenerationKgPerCycle: regenerationKgPerCycle.present
        ? regenerationKgPerCycle.value
        : this.regenerationKgPerCycle,
  );
  SdeWormholeType copyWithCompanion(SdeWormholeTypesCompanion data) {
    return SdeWormholeType(
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      published: data.published.present ? data.published.value : this.published,
      rawTargetClass: data.rawTargetClass.present
          ? data.rawTargetClass.value
          : this.rawTargetClass,
      rawTargetDistribution: data.rawTargetDistribution.present
          ? data.rawTargetDistribution.value
          : this.rawTargetDistribution,
      reliableLifetimeSeconds: data.reliableLifetimeSeconds.present
          ? data.reliableLifetimeSeconds.value
          : this.reliableLifetimeSeconds,
      maxJumpMassKg: data.maxJumpMassKg.present
          ? data.maxJumpMassKg.value
          : this.maxJumpMassKg,
      totalMassKg: data.totalMassKg.present
          ? data.totalMassKg.value
          : this.totalMassKg,
      regenerationKgPerCycle: data.regenerationKgPerCycle.present
          ? data.regenerationKgPerCycle.value
          : this.regenerationKgPerCycle,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeWormholeType(')
          ..write('typeId: $typeId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('groupId: $groupId, ')
          ..write('published: $published, ')
          ..write('rawTargetClass: $rawTargetClass, ')
          ..write('rawTargetDistribution: $rawTargetDistribution, ')
          ..write('reliableLifetimeSeconds: $reliableLifetimeSeconds, ')
          ..write('maxJumpMassKg: $maxJumpMassKg, ')
          ..write('totalMassKg: $totalMassKg, ')
          ..write('regenerationKgPerCycle: $regenerationKgPerCycle')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    typeId,
    code,
    name,
    groupId,
    published,
    rawTargetClass,
    rawTargetDistribution,
    reliableLifetimeSeconds,
    maxJumpMassKg,
    totalMassKg,
    regenerationKgPerCycle,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeWormholeType &&
          other.typeId == this.typeId &&
          other.code == this.code &&
          other.name == this.name &&
          other.groupId == this.groupId &&
          other.published == this.published &&
          other.rawTargetClass == this.rawTargetClass &&
          other.rawTargetDistribution == this.rawTargetDistribution &&
          other.reliableLifetimeSeconds == this.reliableLifetimeSeconds &&
          other.maxJumpMassKg == this.maxJumpMassKg &&
          other.totalMassKg == this.totalMassKg &&
          other.regenerationKgPerCycle == this.regenerationKgPerCycle);
}

class SdeWormholeTypesCompanion extends UpdateCompanion<SdeWormholeType> {
  final Value<int> typeId;
  final Value<String> code;
  final Value<String> name;
  final Value<int> groupId;
  final Value<bool> published;
  final Value<int?> rawTargetClass;
  final Value<int?> rawTargetDistribution;
  final Value<int?> reliableLifetimeSeconds;
  final Value<double?> maxJumpMassKg;
  final Value<double?> totalMassKg;
  final Value<double?> regenerationKgPerCycle;
  const SdeWormholeTypesCompanion({
    this.typeId = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.groupId = const Value.absent(),
    this.published = const Value.absent(),
    this.rawTargetClass = const Value.absent(),
    this.rawTargetDistribution = const Value.absent(),
    this.reliableLifetimeSeconds = const Value.absent(),
    this.maxJumpMassKg = const Value.absent(),
    this.totalMassKg = const Value.absent(),
    this.regenerationKgPerCycle = const Value.absent(),
  });
  SdeWormholeTypesCompanion.insert({
    this.typeId = const Value.absent(),
    required String code,
    required String name,
    this.groupId = const Value.absent(),
    this.published = const Value.absent(),
    this.rawTargetClass = const Value.absent(),
    this.rawTargetDistribution = const Value.absent(),
    this.reliableLifetimeSeconds = const Value.absent(),
    this.maxJumpMassKg = const Value.absent(),
    this.totalMassKg = const Value.absent(),
    this.regenerationKgPerCycle = const Value.absent(),
  }) : code = Value(code),
       name = Value(name);
  static Insertable<SdeWormholeType> custom({
    Expression<int>? typeId,
    Expression<String>? code,
    Expression<String>? name,
    Expression<int>? groupId,
    Expression<bool>? published,
    Expression<int>? rawTargetClass,
    Expression<int>? rawTargetDistribution,
    Expression<int>? reliableLifetimeSeconds,
    Expression<double>? maxJumpMassKg,
    Expression<double>? totalMassKg,
    Expression<double>? regenerationKgPerCycle,
  }) {
    return RawValuesInsertable({
      if (typeId != null) 'type_id': typeId,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (groupId != null) 'group_id': groupId,
      if (published != null) 'published': published,
      if (rawTargetClass != null) 'raw_target_class': rawTargetClass,
      if (rawTargetDistribution != null)
        'raw_target_distribution': rawTargetDistribution,
      if (reliableLifetimeSeconds != null)
        'reliable_lifetime_seconds': reliableLifetimeSeconds,
      if (maxJumpMassKg != null) 'max_jump_mass_kg': maxJumpMassKg,
      if (totalMassKg != null) 'total_mass_kg': totalMassKg,
      if (regenerationKgPerCycle != null)
        'regeneration_kg_per_cycle': regenerationKgPerCycle,
    });
  }

  SdeWormholeTypesCompanion copyWith({
    Value<int>? typeId,
    Value<String>? code,
    Value<String>? name,
    Value<int>? groupId,
    Value<bool>? published,
    Value<int?>? rawTargetClass,
    Value<int?>? rawTargetDistribution,
    Value<int?>? reliableLifetimeSeconds,
    Value<double?>? maxJumpMassKg,
    Value<double?>? totalMassKg,
    Value<double?>? regenerationKgPerCycle,
  }) {
    return SdeWormholeTypesCompanion(
      typeId: typeId ?? this.typeId,
      code: code ?? this.code,
      name: name ?? this.name,
      groupId: groupId ?? this.groupId,
      published: published ?? this.published,
      rawTargetClass: rawTargetClass ?? this.rawTargetClass,
      rawTargetDistribution:
          rawTargetDistribution ?? this.rawTargetDistribution,
      reliableLifetimeSeconds:
          reliableLifetimeSeconds ?? this.reliableLifetimeSeconds,
      maxJumpMassKg: maxJumpMassKg ?? this.maxJumpMassKg,
      totalMassKg: totalMassKg ?? this.totalMassKg,
      regenerationKgPerCycle:
          regenerationKgPerCycle ?? this.regenerationKgPerCycle,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (typeId.present) {
      map['type_id'] = Variable<int>(typeId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (published.present) {
      map['published'] = Variable<bool>(published.value);
    }
    if (rawTargetClass.present) {
      map['raw_target_class'] = Variable<int>(rawTargetClass.value);
    }
    if (rawTargetDistribution.present) {
      map['raw_target_distribution'] = Variable<int>(
        rawTargetDistribution.value,
      );
    }
    if (reliableLifetimeSeconds.present) {
      map['reliable_lifetime_seconds'] = Variable<int>(
        reliableLifetimeSeconds.value,
      );
    }
    if (maxJumpMassKg.present) {
      map['max_jump_mass_kg'] = Variable<double>(maxJumpMassKg.value);
    }
    if (totalMassKg.present) {
      map['total_mass_kg'] = Variable<double>(totalMassKg.value);
    }
    if (regenerationKgPerCycle.present) {
      map['regeneration_kg_per_cycle'] = Variable<double>(
        regenerationKgPerCycle.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeWormholeTypesCompanion(')
          ..write('typeId: $typeId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('groupId: $groupId, ')
          ..write('published: $published, ')
          ..write('rawTargetClass: $rawTargetClass, ')
          ..write('rawTargetDistribution: $rawTargetDistribution, ')
          ..write('reliableLifetimeSeconds: $reliableLifetimeSeconds, ')
          ..write('maxJumpMassKg: $maxJumpMassKg, ')
          ..write('totalMassKg: $totalMassKg, ')
          ..write('regenerationKgPerCycle: $regenerationKgPerCycle')
          ..write(')'))
        .toString();
  }
}

class $SdeWormholeSystemsTable extends SdeWormholeSystems
    with TableInfo<$SdeWormholeSystemsTable, SdeWormholeSystem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeWormholeSystemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _systemIdMeta = const VerificationMeta(
    'systemId',
  );
  @override
  late final GeneratedColumn<int> systemId = GeneratedColumn<int>(
    'system_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _constellationIdMeta = const VerificationMeta(
    'constellationId',
  );
  @override
  late final GeneratedColumn<int> constellationId = GeneratedColumn<int>(
    'constellation_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regionIdMeta = const VerificationMeta(
    'regionId',
  );
  @override
  late final GeneratedColumn<int> regionId = GeneratedColumn<int>(
    'region_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _constellationNameMeta = const VerificationMeta(
    'constellationName',
  );
  @override
  late final GeneratedColumn<String> constellationName =
      GeneratedColumn<String>(
        'constellation_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _regionNameMeta = const VerificationMeta(
    'regionName',
  );
  @override
  late final GeneratedColumn<String> regionName = GeneratedColumn<String>(
    'region_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawSecurityMeta = const VerificationMeta(
    'rawSecurity',
  );
  @override
  late final GeneratedColumn<double> rawSecurity = GeneratedColumn<double>(
    'raw_security',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawClassMeta = const VerificationMeta(
    'rawClass',
  );
  @override
  late final GeneratedColumn<int> rawClass = GeneratedColumn<int>(
    'raw_class',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inheritedClassMeta = const VerificationMeta(
    'inheritedClass',
  );
  @override
  late final GeneratedColumn<int> inheritedClass = GeneratedColumn<int>(
    'inherited_class',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inheritanceSourceMeta = const VerificationMeta(
    'inheritanceSource',
  );
  @override
  late final GeneratedColumn<String> inheritanceSource =
      GeneratedColumn<String>(
        'inheritance_source',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _effectBeaconTypeIdMeta =
      const VerificationMeta('effectBeaconTypeId');
  @override
  late final GeneratedColumn<int> effectBeaconTypeId = GeneratedColumn<int>(
    'effect_beacon_type_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _visualSunTypeIdMeta = const VerificationMeta(
    'visualSunTypeId',
  );
  @override
  late final GeneratedColumn<int> visualSunTypeId = GeneratedColumn<int>(
    'visual_sun_type_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    systemId,
    name,
    constellationId,
    regionId,
    constellationName,
    regionName,
    rawSecurity,
    rawClass,
    inheritedClass,
    inheritanceSource,
    effectBeaconTypeId,
    visualSunTypeId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_wormhole_systems';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeWormholeSystem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('system_id')) {
      context.handle(
        _systemIdMeta,
        systemId.isAcceptableOrUnknown(data['system_id']!, _systemIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('constellation_id')) {
      context.handle(
        _constellationIdMeta,
        constellationId.isAcceptableOrUnknown(
          data['constellation_id']!,
          _constellationIdMeta,
        ),
      );
    }
    if (data.containsKey('region_id')) {
      context.handle(
        _regionIdMeta,
        regionId.isAcceptableOrUnknown(data['region_id']!, _regionIdMeta),
      );
    }
    if (data.containsKey('constellation_name')) {
      context.handle(
        _constellationNameMeta,
        constellationName.isAcceptableOrUnknown(
          data['constellation_name']!,
          _constellationNameMeta,
        ),
      );
    }
    if (data.containsKey('region_name')) {
      context.handle(
        _regionNameMeta,
        regionName.isAcceptableOrUnknown(data['region_name']!, _regionNameMeta),
      );
    }
    if (data.containsKey('raw_security')) {
      context.handle(
        _rawSecurityMeta,
        rawSecurity.isAcceptableOrUnknown(
          data['raw_security']!,
          _rawSecurityMeta,
        ),
      );
    }
    if (data.containsKey('raw_class')) {
      context.handle(
        _rawClassMeta,
        rawClass.isAcceptableOrUnknown(data['raw_class']!, _rawClassMeta),
      );
    }
    if (data.containsKey('inherited_class')) {
      context.handle(
        _inheritedClassMeta,
        inheritedClass.isAcceptableOrUnknown(
          data['inherited_class']!,
          _inheritedClassMeta,
        ),
      );
    }
    if (data.containsKey('inheritance_source')) {
      context.handle(
        _inheritanceSourceMeta,
        inheritanceSource.isAcceptableOrUnknown(
          data['inheritance_source']!,
          _inheritanceSourceMeta,
        ),
      );
    }
    if (data.containsKey('effect_beacon_type_id')) {
      context.handle(
        _effectBeaconTypeIdMeta,
        effectBeaconTypeId.isAcceptableOrUnknown(
          data['effect_beacon_type_id']!,
          _effectBeaconTypeIdMeta,
        ),
      );
    }
    if (data.containsKey('visual_sun_type_id')) {
      context.handle(
        _visualSunTypeIdMeta,
        visualSunTypeId.isAcceptableOrUnknown(
          data['visual_sun_type_id']!,
          _visualSunTypeIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {systemId};
  @override
  SdeWormholeSystem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeWormholeSystem(
      systemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}system_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      constellationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}constellation_id'],
      ),
      regionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}region_id'],
      ),
      constellationName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}constellation_name'],
      ),
      regionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region_name'],
      ),
      rawSecurity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}raw_security'],
      ),
      rawClass: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}raw_class'],
      ),
      inheritedClass: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}inherited_class'],
      ),
      inheritanceSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}inheritance_source'],
      ),
      effectBeaconTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}effect_beacon_type_id'],
      ),
      visualSunTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}visual_sun_type_id'],
      ),
    );
  }

  @override
  $SdeWormholeSystemsTable createAlias(String alias) {
    return $SdeWormholeSystemsTable(attachedDatabase, alias);
  }
}

class SdeWormholeSystem extends DataClass
    implements Insertable<SdeWormholeSystem> {
  final int systemId;
  final String name;
  final int? constellationId;
  final int? regionId;
  final String? constellationName;
  final String? regionName;
  final double? rawSecurity;
  final int? rawClass;
  final int? inheritedClass;
  final String? inheritanceSource;
  final int? effectBeaconTypeId;
  final int? visualSunTypeId;
  const SdeWormholeSystem({
    required this.systemId,
    required this.name,
    this.constellationId,
    this.regionId,
    this.constellationName,
    this.regionName,
    this.rawSecurity,
    this.rawClass,
    this.inheritedClass,
    this.inheritanceSource,
    this.effectBeaconTypeId,
    this.visualSunTypeId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['system_id'] = Variable<int>(systemId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || constellationId != null) {
      map['constellation_id'] = Variable<int>(constellationId);
    }
    if (!nullToAbsent || regionId != null) {
      map['region_id'] = Variable<int>(regionId);
    }
    if (!nullToAbsent || constellationName != null) {
      map['constellation_name'] = Variable<String>(constellationName);
    }
    if (!nullToAbsent || regionName != null) {
      map['region_name'] = Variable<String>(regionName);
    }
    if (!nullToAbsent || rawSecurity != null) {
      map['raw_security'] = Variable<double>(rawSecurity);
    }
    if (!nullToAbsent || rawClass != null) {
      map['raw_class'] = Variable<int>(rawClass);
    }
    if (!nullToAbsent || inheritedClass != null) {
      map['inherited_class'] = Variable<int>(inheritedClass);
    }
    if (!nullToAbsent || inheritanceSource != null) {
      map['inheritance_source'] = Variable<String>(inheritanceSource);
    }
    if (!nullToAbsent || effectBeaconTypeId != null) {
      map['effect_beacon_type_id'] = Variable<int>(effectBeaconTypeId);
    }
    if (!nullToAbsent || visualSunTypeId != null) {
      map['visual_sun_type_id'] = Variable<int>(visualSunTypeId);
    }
    return map;
  }

  SdeWormholeSystemsCompanion toCompanion(bool nullToAbsent) {
    return SdeWormholeSystemsCompanion(
      systemId: Value(systemId),
      name: Value(name),
      constellationId: constellationId == null && nullToAbsent
          ? const Value.absent()
          : Value(constellationId),
      regionId: regionId == null && nullToAbsent
          ? const Value.absent()
          : Value(regionId),
      constellationName: constellationName == null && nullToAbsent
          ? const Value.absent()
          : Value(constellationName),
      regionName: regionName == null && nullToAbsent
          ? const Value.absent()
          : Value(regionName),
      rawSecurity: rawSecurity == null && nullToAbsent
          ? const Value.absent()
          : Value(rawSecurity),
      rawClass: rawClass == null && nullToAbsent
          ? const Value.absent()
          : Value(rawClass),
      inheritedClass: inheritedClass == null && nullToAbsent
          ? const Value.absent()
          : Value(inheritedClass),
      inheritanceSource: inheritanceSource == null && nullToAbsent
          ? const Value.absent()
          : Value(inheritanceSource),
      effectBeaconTypeId: effectBeaconTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(effectBeaconTypeId),
      visualSunTypeId: visualSunTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(visualSunTypeId),
    );
  }

  factory SdeWormholeSystem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeWormholeSystem(
      systemId: serializer.fromJson<int>(json['systemId']),
      name: serializer.fromJson<String>(json['name']),
      constellationId: serializer.fromJson<int?>(json['constellationId']),
      regionId: serializer.fromJson<int?>(json['regionId']),
      constellationName: serializer.fromJson<String?>(
        json['constellationName'],
      ),
      regionName: serializer.fromJson<String?>(json['regionName']),
      rawSecurity: serializer.fromJson<double?>(json['rawSecurity']),
      rawClass: serializer.fromJson<int?>(json['rawClass']),
      inheritedClass: serializer.fromJson<int?>(json['inheritedClass']),
      inheritanceSource: serializer.fromJson<String?>(
        json['inheritanceSource'],
      ),
      effectBeaconTypeId: serializer.fromJson<int?>(json['effectBeaconTypeId']),
      visualSunTypeId: serializer.fromJson<int?>(json['visualSunTypeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'systemId': serializer.toJson<int>(systemId),
      'name': serializer.toJson<String>(name),
      'constellationId': serializer.toJson<int?>(constellationId),
      'regionId': serializer.toJson<int?>(regionId),
      'constellationName': serializer.toJson<String?>(constellationName),
      'regionName': serializer.toJson<String?>(regionName),
      'rawSecurity': serializer.toJson<double?>(rawSecurity),
      'rawClass': serializer.toJson<int?>(rawClass),
      'inheritedClass': serializer.toJson<int?>(inheritedClass),
      'inheritanceSource': serializer.toJson<String?>(inheritanceSource),
      'effectBeaconTypeId': serializer.toJson<int?>(effectBeaconTypeId),
      'visualSunTypeId': serializer.toJson<int?>(visualSunTypeId),
    };
  }

  SdeWormholeSystem copyWith({
    int? systemId,
    String? name,
    Value<int?> constellationId = const Value.absent(),
    Value<int?> regionId = const Value.absent(),
    Value<String?> constellationName = const Value.absent(),
    Value<String?> regionName = const Value.absent(),
    Value<double?> rawSecurity = const Value.absent(),
    Value<int?> rawClass = const Value.absent(),
    Value<int?> inheritedClass = const Value.absent(),
    Value<String?> inheritanceSource = const Value.absent(),
    Value<int?> effectBeaconTypeId = const Value.absent(),
    Value<int?> visualSunTypeId = const Value.absent(),
  }) => SdeWormholeSystem(
    systemId: systemId ?? this.systemId,
    name: name ?? this.name,
    constellationId: constellationId.present
        ? constellationId.value
        : this.constellationId,
    regionId: regionId.present ? regionId.value : this.regionId,
    constellationName: constellationName.present
        ? constellationName.value
        : this.constellationName,
    regionName: regionName.present ? regionName.value : this.regionName,
    rawSecurity: rawSecurity.present ? rawSecurity.value : this.rawSecurity,
    rawClass: rawClass.present ? rawClass.value : this.rawClass,
    inheritedClass: inheritedClass.present
        ? inheritedClass.value
        : this.inheritedClass,
    inheritanceSource: inheritanceSource.present
        ? inheritanceSource.value
        : this.inheritanceSource,
    effectBeaconTypeId: effectBeaconTypeId.present
        ? effectBeaconTypeId.value
        : this.effectBeaconTypeId,
    visualSunTypeId: visualSunTypeId.present
        ? visualSunTypeId.value
        : this.visualSunTypeId,
  );
  SdeWormholeSystem copyWithCompanion(SdeWormholeSystemsCompanion data) {
    return SdeWormholeSystem(
      systemId: data.systemId.present ? data.systemId.value : this.systemId,
      name: data.name.present ? data.name.value : this.name,
      constellationId: data.constellationId.present
          ? data.constellationId.value
          : this.constellationId,
      regionId: data.regionId.present ? data.regionId.value : this.regionId,
      constellationName: data.constellationName.present
          ? data.constellationName.value
          : this.constellationName,
      regionName: data.regionName.present
          ? data.regionName.value
          : this.regionName,
      rawSecurity: data.rawSecurity.present
          ? data.rawSecurity.value
          : this.rawSecurity,
      rawClass: data.rawClass.present ? data.rawClass.value : this.rawClass,
      inheritedClass: data.inheritedClass.present
          ? data.inheritedClass.value
          : this.inheritedClass,
      inheritanceSource: data.inheritanceSource.present
          ? data.inheritanceSource.value
          : this.inheritanceSource,
      effectBeaconTypeId: data.effectBeaconTypeId.present
          ? data.effectBeaconTypeId.value
          : this.effectBeaconTypeId,
      visualSunTypeId: data.visualSunTypeId.present
          ? data.visualSunTypeId.value
          : this.visualSunTypeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeWormholeSystem(')
          ..write('systemId: $systemId, ')
          ..write('name: $name, ')
          ..write('constellationId: $constellationId, ')
          ..write('regionId: $regionId, ')
          ..write('constellationName: $constellationName, ')
          ..write('regionName: $regionName, ')
          ..write('rawSecurity: $rawSecurity, ')
          ..write('rawClass: $rawClass, ')
          ..write('inheritedClass: $inheritedClass, ')
          ..write('inheritanceSource: $inheritanceSource, ')
          ..write('effectBeaconTypeId: $effectBeaconTypeId, ')
          ..write('visualSunTypeId: $visualSunTypeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    systemId,
    name,
    constellationId,
    regionId,
    constellationName,
    regionName,
    rawSecurity,
    rawClass,
    inheritedClass,
    inheritanceSource,
    effectBeaconTypeId,
    visualSunTypeId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeWormholeSystem &&
          other.systemId == this.systemId &&
          other.name == this.name &&
          other.constellationId == this.constellationId &&
          other.regionId == this.regionId &&
          other.constellationName == this.constellationName &&
          other.regionName == this.regionName &&
          other.rawSecurity == this.rawSecurity &&
          other.rawClass == this.rawClass &&
          other.inheritedClass == this.inheritedClass &&
          other.inheritanceSource == this.inheritanceSource &&
          other.effectBeaconTypeId == this.effectBeaconTypeId &&
          other.visualSunTypeId == this.visualSunTypeId);
}

class SdeWormholeSystemsCompanion extends UpdateCompanion<SdeWormholeSystem> {
  final Value<int> systemId;
  final Value<String> name;
  final Value<int?> constellationId;
  final Value<int?> regionId;
  final Value<String?> constellationName;
  final Value<String?> regionName;
  final Value<double?> rawSecurity;
  final Value<int?> rawClass;
  final Value<int?> inheritedClass;
  final Value<String?> inheritanceSource;
  final Value<int?> effectBeaconTypeId;
  final Value<int?> visualSunTypeId;
  const SdeWormholeSystemsCompanion({
    this.systemId = const Value.absent(),
    this.name = const Value.absent(),
    this.constellationId = const Value.absent(),
    this.regionId = const Value.absent(),
    this.constellationName = const Value.absent(),
    this.regionName = const Value.absent(),
    this.rawSecurity = const Value.absent(),
    this.rawClass = const Value.absent(),
    this.inheritedClass = const Value.absent(),
    this.inheritanceSource = const Value.absent(),
    this.effectBeaconTypeId = const Value.absent(),
    this.visualSunTypeId = const Value.absent(),
  });
  SdeWormholeSystemsCompanion.insert({
    this.systemId = const Value.absent(),
    required String name,
    this.constellationId = const Value.absent(),
    this.regionId = const Value.absent(),
    this.constellationName = const Value.absent(),
    this.regionName = const Value.absent(),
    this.rawSecurity = const Value.absent(),
    this.rawClass = const Value.absent(),
    this.inheritedClass = const Value.absent(),
    this.inheritanceSource = const Value.absent(),
    this.effectBeaconTypeId = const Value.absent(),
    this.visualSunTypeId = const Value.absent(),
  }) : name = Value(name);
  static Insertable<SdeWormholeSystem> custom({
    Expression<int>? systemId,
    Expression<String>? name,
    Expression<int>? constellationId,
    Expression<int>? regionId,
    Expression<String>? constellationName,
    Expression<String>? regionName,
    Expression<double>? rawSecurity,
    Expression<int>? rawClass,
    Expression<int>? inheritedClass,
    Expression<String>? inheritanceSource,
    Expression<int>? effectBeaconTypeId,
    Expression<int>? visualSunTypeId,
  }) {
    return RawValuesInsertable({
      if (systemId != null) 'system_id': systemId,
      if (name != null) 'name': name,
      if (constellationId != null) 'constellation_id': constellationId,
      if (regionId != null) 'region_id': regionId,
      if (constellationName != null) 'constellation_name': constellationName,
      if (regionName != null) 'region_name': regionName,
      if (rawSecurity != null) 'raw_security': rawSecurity,
      if (rawClass != null) 'raw_class': rawClass,
      if (inheritedClass != null) 'inherited_class': inheritedClass,
      if (inheritanceSource != null) 'inheritance_source': inheritanceSource,
      if (effectBeaconTypeId != null)
        'effect_beacon_type_id': effectBeaconTypeId,
      if (visualSunTypeId != null) 'visual_sun_type_id': visualSunTypeId,
    });
  }

  SdeWormholeSystemsCompanion copyWith({
    Value<int>? systemId,
    Value<String>? name,
    Value<int?>? constellationId,
    Value<int?>? regionId,
    Value<String?>? constellationName,
    Value<String?>? regionName,
    Value<double?>? rawSecurity,
    Value<int?>? rawClass,
    Value<int?>? inheritedClass,
    Value<String?>? inheritanceSource,
    Value<int?>? effectBeaconTypeId,
    Value<int?>? visualSunTypeId,
  }) {
    return SdeWormholeSystemsCompanion(
      systemId: systemId ?? this.systemId,
      name: name ?? this.name,
      constellationId: constellationId ?? this.constellationId,
      regionId: regionId ?? this.regionId,
      constellationName: constellationName ?? this.constellationName,
      regionName: regionName ?? this.regionName,
      rawSecurity: rawSecurity ?? this.rawSecurity,
      rawClass: rawClass ?? this.rawClass,
      inheritedClass: inheritedClass ?? this.inheritedClass,
      inheritanceSource: inheritanceSource ?? this.inheritanceSource,
      effectBeaconTypeId: effectBeaconTypeId ?? this.effectBeaconTypeId,
      visualSunTypeId: visualSunTypeId ?? this.visualSunTypeId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (systemId.present) {
      map['system_id'] = Variable<int>(systemId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (constellationId.present) {
      map['constellation_id'] = Variable<int>(constellationId.value);
    }
    if (regionId.present) {
      map['region_id'] = Variable<int>(regionId.value);
    }
    if (constellationName.present) {
      map['constellation_name'] = Variable<String>(constellationName.value);
    }
    if (regionName.present) {
      map['region_name'] = Variable<String>(regionName.value);
    }
    if (rawSecurity.present) {
      map['raw_security'] = Variable<double>(rawSecurity.value);
    }
    if (rawClass.present) {
      map['raw_class'] = Variable<int>(rawClass.value);
    }
    if (inheritedClass.present) {
      map['inherited_class'] = Variable<int>(inheritedClass.value);
    }
    if (inheritanceSource.present) {
      map['inheritance_source'] = Variable<String>(inheritanceSource.value);
    }
    if (effectBeaconTypeId.present) {
      map['effect_beacon_type_id'] = Variable<int>(effectBeaconTypeId.value);
    }
    if (visualSunTypeId.present) {
      map['visual_sun_type_id'] = Variable<int>(visualSunTypeId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeWormholeSystemsCompanion(')
          ..write('systemId: $systemId, ')
          ..write('name: $name, ')
          ..write('constellationId: $constellationId, ')
          ..write('regionId: $regionId, ')
          ..write('constellationName: $constellationName, ')
          ..write('regionName: $regionName, ')
          ..write('rawSecurity: $rawSecurity, ')
          ..write('rawClass: $rawClass, ')
          ..write('inheritedClass: $inheritedClass, ')
          ..write('inheritanceSource: $inheritanceSource, ')
          ..write('effectBeaconTypeId: $effectBeaconTypeId, ')
          ..write('visualSunTypeId: $visualSunTypeId')
          ..write(')'))
        .toString();
  }
}

class $SdeSystemEffectsTable extends SdeSystemEffects
    with TableInfo<$SdeSystemEffectsTable, SdeSystemEffect> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeSystemEffectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _beaconTypeIdMeta = const VerificationMeta(
    'beaconTypeId',
  );
  @override
  late final GeneratedColumn<int> beaconTypeId = GeneratedColumn<int>(
    'beacon_type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _familyMeta = const VerificationMeta('family');
  @override
  late final GeneratedColumn<String> family = GeneratedColumn<String>(
    'family',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _strengthMeta = const VerificationMeta(
    'strength',
  );
  @override
  late final GeneratedColumn<int> strength = GeneratedColumn<int>(
    'strength',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopesJsonMeta = const VerificationMeta(
    'scopesJson',
  );
  @override
  late final GeneratedColumn<String> scopesJson = GeneratedColumn<String>(
    'scopes_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    beaconTypeId,
    family,
    strength,
    scopesJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_system_effects';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeSystemEffect> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('beacon_type_id')) {
      context.handle(
        _beaconTypeIdMeta,
        beaconTypeId.isAcceptableOrUnknown(
          data['beacon_type_id']!,
          _beaconTypeIdMeta,
        ),
      );
    }
    if (data.containsKey('family')) {
      context.handle(
        _familyMeta,
        family.isAcceptableOrUnknown(data['family']!, _familyMeta),
      );
    } else if (isInserting) {
      context.missing(_familyMeta);
    }
    if (data.containsKey('strength')) {
      context.handle(
        _strengthMeta,
        strength.isAcceptableOrUnknown(data['strength']!, _strengthMeta),
      );
    } else if (isInserting) {
      context.missing(_strengthMeta);
    }
    if (data.containsKey('scopes_json')) {
      context.handle(
        _scopesJsonMeta,
        scopesJson.isAcceptableOrUnknown(data['scopes_json']!, _scopesJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {beaconTypeId};
  @override
  SdeSystemEffect map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeSystemEffect(
      beaconTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}beacon_type_id'],
      )!,
      family: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family'],
      )!,
      strength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}strength'],
      )!,
      scopesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scopes_json'],
      ),
    );
  }

  @override
  $SdeSystemEffectsTable createAlias(String alias) {
    return $SdeSystemEffectsTable(attachedDatabase, alias);
  }
}

class SdeSystemEffect extends DataClass implements Insertable<SdeSystemEffect> {
  final int beaconTypeId;
  final String family;
  final int strength;
  final String? scopesJson;
  const SdeSystemEffect({
    required this.beaconTypeId,
    required this.family,
    required this.strength,
    this.scopesJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['beacon_type_id'] = Variable<int>(beaconTypeId);
    map['family'] = Variable<String>(family);
    map['strength'] = Variable<int>(strength);
    if (!nullToAbsent || scopesJson != null) {
      map['scopes_json'] = Variable<String>(scopesJson);
    }
    return map;
  }

  SdeSystemEffectsCompanion toCompanion(bool nullToAbsent) {
    return SdeSystemEffectsCompanion(
      beaconTypeId: Value(beaconTypeId),
      family: Value(family),
      strength: Value(strength),
      scopesJson: scopesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(scopesJson),
    );
  }

  factory SdeSystemEffect.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeSystemEffect(
      beaconTypeId: serializer.fromJson<int>(json['beaconTypeId']),
      family: serializer.fromJson<String>(json['family']),
      strength: serializer.fromJson<int>(json['strength']),
      scopesJson: serializer.fromJson<String?>(json['scopesJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'beaconTypeId': serializer.toJson<int>(beaconTypeId),
      'family': serializer.toJson<String>(family),
      'strength': serializer.toJson<int>(strength),
      'scopesJson': serializer.toJson<String?>(scopesJson),
    };
  }

  SdeSystemEffect copyWith({
    int? beaconTypeId,
    String? family,
    int? strength,
    Value<String?> scopesJson = const Value.absent(),
  }) => SdeSystemEffect(
    beaconTypeId: beaconTypeId ?? this.beaconTypeId,
    family: family ?? this.family,
    strength: strength ?? this.strength,
    scopesJson: scopesJson.present ? scopesJson.value : this.scopesJson,
  );
  SdeSystemEffect copyWithCompanion(SdeSystemEffectsCompanion data) {
    return SdeSystemEffect(
      beaconTypeId: data.beaconTypeId.present
          ? data.beaconTypeId.value
          : this.beaconTypeId,
      family: data.family.present ? data.family.value : this.family,
      strength: data.strength.present ? data.strength.value : this.strength,
      scopesJson: data.scopesJson.present
          ? data.scopesJson.value
          : this.scopesJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeSystemEffect(')
          ..write('beaconTypeId: $beaconTypeId, ')
          ..write('family: $family, ')
          ..write('strength: $strength, ')
          ..write('scopesJson: $scopesJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(beaconTypeId, family, strength, scopesJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeSystemEffect &&
          other.beaconTypeId == this.beaconTypeId &&
          other.family == this.family &&
          other.strength == this.strength &&
          other.scopesJson == this.scopesJson);
}

class SdeSystemEffectsCompanion extends UpdateCompanion<SdeSystemEffect> {
  final Value<int> beaconTypeId;
  final Value<String> family;
  final Value<int> strength;
  final Value<String?> scopesJson;
  const SdeSystemEffectsCompanion({
    this.beaconTypeId = const Value.absent(),
    this.family = const Value.absent(),
    this.strength = const Value.absent(),
    this.scopesJson = const Value.absent(),
  });
  SdeSystemEffectsCompanion.insert({
    this.beaconTypeId = const Value.absent(),
    required String family,
    required int strength,
    this.scopesJson = const Value.absent(),
  }) : family = Value(family),
       strength = Value(strength);
  static Insertable<SdeSystemEffect> custom({
    Expression<int>? beaconTypeId,
    Expression<String>? family,
    Expression<int>? strength,
    Expression<String>? scopesJson,
  }) {
    return RawValuesInsertable({
      if (beaconTypeId != null) 'beacon_type_id': beaconTypeId,
      if (family != null) 'family': family,
      if (strength != null) 'strength': strength,
      if (scopesJson != null) 'scopes_json': scopesJson,
    });
  }

  SdeSystemEffectsCompanion copyWith({
    Value<int>? beaconTypeId,
    Value<String>? family,
    Value<int>? strength,
    Value<String?>? scopesJson,
  }) {
    return SdeSystemEffectsCompanion(
      beaconTypeId: beaconTypeId ?? this.beaconTypeId,
      family: family ?? this.family,
      strength: strength ?? this.strength,
      scopesJson: scopesJson ?? this.scopesJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (beaconTypeId.present) {
      map['beacon_type_id'] = Variable<int>(beaconTypeId.value);
    }
    if (family.present) {
      map['family'] = Variable<String>(family.value);
    }
    if (strength.present) {
      map['strength'] = Variable<int>(strength.value);
    }
    if (scopesJson.present) {
      map['scopes_json'] = Variable<String>(scopesJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeSystemEffectsCompanion(')
          ..write('beaconTypeId: $beaconTypeId, ')
          ..write('family: $family, ')
          ..write('strength: $strength, ')
          ..write('scopesJson: $scopesJson')
          ..write(')'))
        .toString();
  }
}

class $SdeStargatesTable extends SdeStargates
    with TableInfo<$SdeStargatesTable, SdeStargate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeStargatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gateIdMeta = const VerificationMeta('gateId');
  @override
  late final GeneratedColumn<int> gateId = GeneratedColumn<int>(
    'gate_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fromSystemIdMeta = const VerificationMeta(
    'fromSystemId',
  );
  @override
  late final GeneratedColumn<int> fromSystemId = GeneratedColumn<int>(
    'from_system_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toSystemIdMeta = const VerificationMeta(
    'toSystemId',
  );
  @override
  late final GeneratedColumn<int> toSystemId = GeneratedColumn<int>(
    'to_system_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topologyVersionMeta = const VerificationMeta(
    'topologyVersion',
  );
  @override
  late final GeneratedColumn<int> topologyVersion = GeneratedColumn<int>(
    'topology_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _restrictionsJsonMeta = const VerificationMeta(
    'restrictionsJson',
  );
  @override
  late final GeneratedColumn<String> restrictionsJson = GeneratedColumn<String>(
    'restrictions_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    gateId,
    fromSystemId,
    toSystemId,
    topologyVersion,
    restrictionsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_stargates';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeStargate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gate_id')) {
      context.handle(
        _gateIdMeta,
        gateId.isAcceptableOrUnknown(data['gate_id']!, _gateIdMeta),
      );
    }
    if (data.containsKey('from_system_id')) {
      context.handle(
        _fromSystemIdMeta,
        fromSystemId.isAcceptableOrUnknown(
          data['from_system_id']!,
          _fromSystemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromSystemIdMeta);
    }
    if (data.containsKey('to_system_id')) {
      context.handle(
        _toSystemIdMeta,
        toSystemId.isAcceptableOrUnknown(
          data['to_system_id']!,
          _toSystemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_toSystemIdMeta);
    }
    if (data.containsKey('topology_version')) {
      context.handle(
        _topologyVersionMeta,
        topologyVersion.isAcceptableOrUnknown(
          data['topology_version']!,
          _topologyVersionMeta,
        ),
      );
    }
    if (data.containsKey('restrictions_json')) {
      context.handle(
        _restrictionsJsonMeta,
        restrictionsJson.isAcceptableOrUnknown(
          data['restrictions_json']!,
          _restrictionsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gateId};
  @override
  SdeStargate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeStargate(
      gateId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gate_id'],
      )!,
      fromSystemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}from_system_id'],
      )!,
      toSystemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}to_system_id'],
      )!,
      topologyVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}topology_version'],
      )!,
      restrictionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}restrictions_json'],
      ),
    );
  }

  @override
  $SdeStargatesTable createAlias(String alias) {
    return $SdeStargatesTable(attachedDatabase, alias);
  }
}

class SdeStargate extends DataClass implements Insertable<SdeStargate> {
  final int gateId;
  final int fromSystemId;
  final int toSystemId;
  final int topologyVersion;
  final String? restrictionsJson;
  const SdeStargate({
    required this.gateId,
    required this.fromSystemId,
    required this.toSystemId,
    required this.topologyVersion,
    this.restrictionsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gate_id'] = Variable<int>(gateId);
    map['from_system_id'] = Variable<int>(fromSystemId);
    map['to_system_id'] = Variable<int>(toSystemId);
    map['topology_version'] = Variable<int>(topologyVersion);
    if (!nullToAbsent || restrictionsJson != null) {
      map['restrictions_json'] = Variable<String>(restrictionsJson);
    }
    return map;
  }

  SdeStargatesCompanion toCompanion(bool nullToAbsent) {
    return SdeStargatesCompanion(
      gateId: Value(gateId),
      fromSystemId: Value(fromSystemId),
      toSystemId: Value(toSystemId),
      topologyVersion: Value(topologyVersion),
      restrictionsJson: restrictionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(restrictionsJson),
    );
  }

  factory SdeStargate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeStargate(
      gateId: serializer.fromJson<int>(json['gateId']),
      fromSystemId: serializer.fromJson<int>(json['fromSystemId']),
      toSystemId: serializer.fromJson<int>(json['toSystemId']),
      topologyVersion: serializer.fromJson<int>(json['topologyVersion']),
      restrictionsJson: serializer.fromJson<String?>(json['restrictionsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gateId': serializer.toJson<int>(gateId),
      'fromSystemId': serializer.toJson<int>(fromSystemId),
      'toSystemId': serializer.toJson<int>(toSystemId),
      'topologyVersion': serializer.toJson<int>(topologyVersion),
      'restrictionsJson': serializer.toJson<String?>(restrictionsJson),
    };
  }

  SdeStargate copyWith({
    int? gateId,
    int? fromSystemId,
    int? toSystemId,
    int? topologyVersion,
    Value<String?> restrictionsJson = const Value.absent(),
  }) => SdeStargate(
    gateId: gateId ?? this.gateId,
    fromSystemId: fromSystemId ?? this.fromSystemId,
    toSystemId: toSystemId ?? this.toSystemId,
    topologyVersion: topologyVersion ?? this.topologyVersion,
    restrictionsJson: restrictionsJson.present
        ? restrictionsJson.value
        : this.restrictionsJson,
  );
  SdeStargate copyWithCompanion(SdeStargatesCompanion data) {
    return SdeStargate(
      gateId: data.gateId.present ? data.gateId.value : this.gateId,
      fromSystemId: data.fromSystemId.present
          ? data.fromSystemId.value
          : this.fromSystemId,
      toSystemId: data.toSystemId.present
          ? data.toSystemId.value
          : this.toSystemId,
      topologyVersion: data.topologyVersion.present
          ? data.topologyVersion.value
          : this.topologyVersion,
      restrictionsJson: data.restrictionsJson.present
          ? data.restrictionsJson.value
          : this.restrictionsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeStargate(')
          ..write('gateId: $gateId, ')
          ..write('fromSystemId: $fromSystemId, ')
          ..write('toSystemId: $toSystemId, ')
          ..write('topologyVersion: $topologyVersion, ')
          ..write('restrictionsJson: $restrictionsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    gateId,
    fromSystemId,
    toSystemId,
    topologyVersion,
    restrictionsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeStargate &&
          other.gateId == this.gateId &&
          other.fromSystemId == this.fromSystemId &&
          other.toSystemId == this.toSystemId &&
          other.topologyVersion == this.topologyVersion &&
          other.restrictionsJson == this.restrictionsJson);
}

class SdeStargatesCompanion extends UpdateCompanion<SdeStargate> {
  final Value<int> gateId;
  final Value<int> fromSystemId;
  final Value<int> toSystemId;
  final Value<int> topologyVersion;
  final Value<String?> restrictionsJson;
  const SdeStargatesCompanion({
    this.gateId = const Value.absent(),
    this.fromSystemId = const Value.absent(),
    this.toSystemId = const Value.absent(),
    this.topologyVersion = const Value.absent(),
    this.restrictionsJson = const Value.absent(),
  });
  SdeStargatesCompanion.insert({
    this.gateId = const Value.absent(),
    required int fromSystemId,
    required int toSystemId,
    this.topologyVersion = const Value.absent(),
    this.restrictionsJson = const Value.absent(),
  }) : fromSystemId = Value(fromSystemId),
       toSystemId = Value(toSystemId);
  static Insertable<SdeStargate> custom({
    Expression<int>? gateId,
    Expression<int>? fromSystemId,
    Expression<int>? toSystemId,
    Expression<int>? topologyVersion,
    Expression<String>? restrictionsJson,
  }) {
    return RawValuesInsertable({
      if (gateId != null) 'gate_id': gateId,
      if (fromSystemId != null) 'from_system_id': fromSystemId,
      if (toSystemId != null) 'to_system_id': toSystemId,
      if (topologyVersion != null) 'topology_version': topologyVersion,
      if (restrictionsJson != null) 'restrictions_json': restrictionsJson,
    });
  }

  SdeStargatesCompanion copyWith({
    Value<int>? gateId,
    Value<int>? fromSystemId,
    Value<int>? toSystemId,
    Value<int>? topologyVersion,
    Value<String?>? restrictionsJson,
  }) {
    return SdeStargatesCompanion(
      gateId: gateId ?? this.gateId,
      fromSystemId: fromSystemId ?? this.fromSystemId,
      toSystemId: toSystemId ?? this.toSystemId,
      topologyVersion: topologyVersion ?? this.topologyVersion,
      restrictionsJson: restrictionsJson ?? this.restrictionsJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gateId.present) {
      map['gate_id'] = Variable<int>(gateId.value);
    }
    if (fromSystemId.present) {
      map['from_system_id'] = Variable<int>(fromSystemId.value);
    }
    if (toSystemId.present) {
      map['to_system_id'] = Variable<int>(toSystemId.value);
    }
    if (topologyVersion.present) {
      map['topology_version'] = Variable<int>(topologyVersion.value);
    }
    if (restrictionsJson.present) {
      map['restrictions_json'] = Variable<String>(restrictionsJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeStargatesCompanion(')
          ..write('gateId: $gateId, ')
          ..write('fromSystemId: $fromSystemId, ')
          ..write('toSystemId: $toSystemId, ')
          ..write('topologyVersion: $topologyVersion, ')
          ..write('restrictionsJson: $restrictionsJson')
          ..write(')'))
        .toString();
  }
}

class $SdeSystemStaticsTable extends SdeSystemStatics
    with TableInfo<$SdeSystemStaticsTable, SdeSystemStatic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SdeSystemStaticsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _systemIdMeta = const VerificationMeta(
    'systemId',
  );
  @override
  late final GeneratedColumn<int> systemId = GeneratedColumn<int>(
    'system_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assignmentIndexMeta = const VerificationMeta(
    'assignmentIndex',
  );
  @override
  late final GeneratedColumn<int> assignmentIndex = GeneratedColumn<int>(
    'assignment_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<int> typeId = GeneratedColumn<int>(
    'type_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _meaningMeta = const VerificationMeta(
    'meaning',
  );
  @override
  late final GeneratedColumn<String> meaning = GeneratedColumn<String>(
    'meaning',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<String> confidence = GeneratedColumn<String>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    systemId,
    assignmentIndex,
    code,
    typeId,
    meaning,
    source,
    confidence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sde_system_statics';
  @override
  VerificationContext validateIntegrity(
    Insertable<SdeSystemStatic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('system_id')) {
      context.handle(
        _systemIdMeta,
        systemId.isAcceptableOrUnknown(data['system_id']!, _systemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_systemIdMeta);
    }
    if (data.containsKey('assignment_index')) {
      context.handle(
        _assignmentIndexMeta,
        assignmentIndex.isAcceptableOrUnknown(
          data['assignment_index']!,
          _assignmentIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assignmentIndexMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('type_id')) {
      context.handle(
        _typeIdMeta,
        typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta),
      );
    }
    if (data.containsKey('meaning')) {
      context.handle(
        _meaningMeta,
        meaning.isAcceptableOrUnknown(data['meaning']!, _meaningMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {systemId, assignmentIndex};
  @override
  SdeSystemStatic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SdeSystemStatic(
      systemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}system_id'],
      )!,
      assignmentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}assignment_index'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      ),
      typeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_id'],
      ),
      meaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confidence'],
      )!,
    );
  }

  @override
  $SdeSystemStaticsTable createAlias(String alias) {
    return $SdeSystemStaticsTable(attachedDatabase, alias);
  }
}

class SdeSystemStatic extends DataClass implements Insertable<SdeSystemStatic> {
  final int systemId;
  final int assignmentIndex;
  final String? code;
  final int? typeId;
  final String meaning;
  final String source;
  final String confidence;
  const SdeSystemStatic({
    required this.systemId,
    required this.assignmentIndex,
    this.code,
    this.typeId,
    required this.meaning,
    required this.source,
    required this.confidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['system_id'] = Variable<int>(systemId);
    map['assignment_index'] = Variable<int>(assignmentIndex);
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || typeId != null) {
      map['type_id'] = Variable<int>(typeId);
    }
    map['meaning'] = Variable<String>(meaning);
    map['source'] = Variable<String>(source);
    map['confidence'] = Variable<String>(confidence);
    return map;
  }

  SdeSystemStaticsCompanion toCompanion(bool nullToAbsent) {
    return SdeSystemStaticsCompanion(
      systemId: Value(systemId),
      assignmentIndex: Value(assignmentIndex),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      typeId: typeId == null && nullToAbsent
          ? const Value.absent()
          : Value(typeId),
      meaning: Value(meaning),
      source: Value(source),
      confidence: Value(confidence),
    );
  }

  factory SdeSystemStatic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SdeSystemStatic(
      systemId: serializer.fromJson<int>(json['systemId']),
      assignmentIndex: serializer.fromJson<int>(json['assignmentIndex']),
      code: serializer.fromJson<String?>(json['code']),
      typeId: serializer.fromJson<int?>(json['typeId']),
      meaning: serializer.fromJson<String>(json['meaning']),
      source: serializer.fromJson<String>(json['source']),
      confidence: serializer.fromJson<String>(json['confidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'systemId': serializer.toJson<int>(systemId),
      'assignmentIndex': serializer.toJson<int>(assignmentIndex),
      'code': serializer.toJson<String?>(code),
      'typeId': serializer.toJson<int?>(typeId),
      'meaning': serializer.toJson<String>(meaning),
      'source': serializer.toJson<String>(source),
      'confidence': serializer.toJson<String>(confidence),
    };
  }

  SdeSystemStatic copyWith({
    int? systemId,
    int? assignmentIndex,
    Value<String?> code = const Value.absent(),
    Value<int?> typeId = const Value.absent(),
    String? meaning,
    String? source,
    String? confidence,
  }) => SdeSystemStatic(
    systemId: systemId ?? this.systemId,
    assignmentIndex: assignmentIndex ?? this.assignmentIndex,
    code: code.present ? code.value : this.code,
    typeId: typeId.present ? typeId.value : this.typeId,
    meaning: meaning ?? this.meaning,
    source: source ?? this.source,
    confidence: confidence ?? this.confidence,
  );
  SdeSystemStatic copyWithCompanion(SdeSystemStaticsCompanion data) {
    return SdeSystemStatic(
      systemId: data.systemId.present ? data.systemId.value : this.systemId,
      assignmentIndex: data.assignmentIndex.present
          ? data.assignmentIndex.value
          : this.assignmentIndex,
      code: data.code.present ? data.code.value : this.code,
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      meaning: data.meaning.present ? data.meaning.value : this.meaning,
      source: data.source.present ? data.source.value : this.source,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SdeSystemStatic(')
          ..write('systemId: $systemId, ')
          ..write('assignmentIndex: $assignmentIndex, ')
          ..write('code: $code, ')
          ..write('typeId: $typeId, ')
          ..write('meaning: $meaning, ')
          ..write('source: $source, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    systemId,
    assignmentIndex,
    code,
    typeId,
    meaning,
    source,
    confidence,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SdeSystemStatic &&
          other.systemId == this.systemId &&
          other.assignmentIndex == this.assignmentIndex &&
          other.code == this.code &&
          other.typeId == this.typeId &&
          other.meaning == this.meaning &&
          other.source == this.source &&
          other.confidence == this.confidence);
}

class SdeSystemStaticsCompanion extends UpdateCompanion<SdeSystemStatic> {
  final Value<int> systemId;
  final Value<int> assignmentIndex;
  final Value<String?> code;
  final Value<int?> typeId;
  final Value<String> meaning;
  final Value<String> source;
  final Value<String> confidence;
  final Value<int> rowid;
  const SdeSystemStaticsCompanion({
    this.systemId = const Value.absent(),
    this.assignmentIndex = const Value.absent(),
    this.code = const Value.absent(),
    this.typeId = const Value.absent(),
    this.meaning = const Value.absent(),
    this.source = const Value.absent(),
    this.confidence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SdeSystemStaticsCompanion.insert({
    required int systemId,
    required int assignmentIndex,
    this.code = const Value.absent(),
    this.typeId = const Value.absent(),
    this.meaning = const Value.absent(),
    this.source = const Value.absent(),
    this.confidence = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : systemId = Value(systemId),
       assignmentIndex = Value(assignmentIndex);
  static Insertable<SdeSystemStatic> custom({
    Expression<int>? systemId,
    Expression<int>? assignmentIndex,
    Expression<String>? code,
    Expression<int>? typeId,
    Expression<String>? meaning,
    Expression<String>? source,
    Expression<String>? confidence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (systemId != null) 'system_id': systemId,
      if (assignmentIndex != null) 'assignment_index': assignmentIndex,
      if (code != null) 'code': code,
      if (typeId != null) 'type_id': typeId,
      if (meaning != null) 'meaning': meaning,
      if (source != null) 'source': source,
      if (confidence != null) 'confidence': confidence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SdeSystemStaticsCompanion copyWith({
    Value<int>? systemId,
    Value<int>? assignmentIndex,
    Value<String?>? code,
    Value<int?>? typeId,
    Value<String>? meaning,
    Value<String>? source,
    Value<String>? confidence,
    Value<int>? rowid,
  }) {
    return SdeSystemStaticsCompanion(
      systemId: systemId ?? this.systemId,
      assignmentIndex: assignmentIndex ?? this.assignmentIndex,
      code: code ?? this.code,
      typeId: typeId ?? this.typeId,
      meaning: meaning ?? this.meaning,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (systemId.present) {
      map['system_id'] = Variable<int>(systemId.value);
    }
    if (assignmentIndex.present) {
      map['assignment_index'] = Variable<int>(assignmentIndex.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (typeId.present) {
      map['type_id'] = Variable<int>(typeId.value);
    }
    if (meaning.present) {
      map['meaning'] = Variable<String>(meaning.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<String>(confidence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SdeSystemStaticsCompanion(')
          ..write('systemId: $systemId, ')
          ..write('assignmentIndex: $assignmentIndex, ')
          ..write('code: $code, ')
          ..write('typeId: $typeId, ')
          ..write('meaning: $meaning, ')
          ..write('source: $source, ')
          ..write('confidence: $confidence, ')
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
  late final $SdeWormholeTypesTable sdeWormholeTypes = $SdeWormholeTypesTable(
    this,
  );
  late final $SdeWormholeSystemsTable sdeWormholeSystems =
      $SdeWormholeSystemsTable(this);
  late final $SdeSystemEffectsTable sdeSystemEffects = $SdeSystemEffectsTable(
    this,
  );
  late final $SdeStargatesTable sdeStargates = $SdeStargatesTable(this);
  late final $SdeSystemStaticsTable sdeSystemStatics = $SdeSystemStaticsTable(
    this,
  );
  late final Index sdeWormholeTypesCode = Index(
    'sde_wormhole_types_code',
    'CREATE INDEX sde_wormhole_types_code ON sde_wormhole_types (code)',
  );
  late final Index sdeWormholeSystemsName = Index(
    'sde_wormhole_systems_name',
    'CREATE INDEX sde_wormhole_systems_name ON sde_wormhole_systems (name)',
  );
  late final Index sdeStargatesFrom = Index(
    'sde_stargates_from',
    'CREATE INDEX sde_stargates_from ON sde_stargates (from_system_id)',
  );
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
    sdeWormholeTypes,
    sdeWormholeSystems,
    sdeSystemEffects,
    sdeStargates,
    sdeSystemStatics,
    sdeWormholeTypesCode,
    sdeWormholeSystemsName,
    sdeStargatesFrom,
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
typedef $$SdeWormholeTypesTableCreateCompanionBuilder =
    SdeWormholeTypesCompanion Function({
      Value<int> typeId,
      required String code,
      required String name,
      Value<int> groupId,
      Value<bool> published,
      Value<int?> rawTargetClass,
      Value<int?> rawTargetDistribution,
      Value<int?> reliableLifetimeSeconds,
      Value<double?> maxJumpMassKg,
      Value<double?> totalMassKg,
      Value<double?> regenerationKgPerCycle,
    });
typedef $$SdeWormholeTypesTableUpdateCompanionBuilder =
    SdeWormholeTypesCompanion Function({
      Value<int> typeId,
      Value<String> code,
      Value<String> name,
      Value<int> groupId,
      Value<bool> published,
      Value<int?> rawTargetClass,
      Value<int?> rawTargetDistribution,
      Value<int?> reliableLifetimeSeconds,
      Value<double?> maxJumpMassKg,
      Value<double?> totalMassKg,
      Value<double?> regenerationKgPerCycle,
    });

class $$SdeWormholeTypesTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeWormholeTypesTable> {
  $$SdeWormholeTypesTableFilterComposer({
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

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get published => $composableBuilder(
    column: $table.published,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rawTargetClass => $composableBuilder(
    column: $table.rawTargetClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rawTargetDistribution => $composableBuilder(
    column: $table.rawTargetDistribution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reliableLifetimeSeconds => $composableBuilder(
    column: $table.reliableLifetimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxJumpMassKg => $composableBuilder(
    column: $table.maxJumpMassKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalMassKg => $composableBuilder(
    column: $table.totalMassKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get regenerationKgPerCycle => $composableBuilder(
    column: $table.regenerationKgPerCycle,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeWormholeTypesTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeWormholeTypesTable> {
  $$SdeWormholeTypesTableOrderingComposer({
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

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get published => $composableBuilder(
    column: $table.published,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rawTargetClass => $composableBuilder(
    column: $table.rawTargetClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rawTargetDistribution => $composableBuilder(
    column: $table.rawTargetDistribution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reliableLifetimeSeconds => $composableBuilder(
    column: $table.reliableLifetimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxJumpMassKg => $composableBuilder(
    column: $table.maxJumpMassKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalMassKg => $composableBuilder(
    column: $table.totalMassKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get regenerationKgPerCycle => $composableBuilder(
    column: $table.regenerationKgPerCycle,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeWormholeTypesTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeWormholeTypesTable> {
  $$SdeWormholeTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<bool> get published =>
      $composableBuilder(column: $table.published, builder: (column) => column);

  GeneratedColumn<int> get rawTargetClass => $composableBuilder(
    column: $table.rawTargetClass,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rawTargetDistribution => $composableBuilder(
    column: $table.rawTargetDistribution,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reliableLifetimeSeconds => $composableBuilder(
    column: $table.reliableLifetimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxJumpMassKg => $composableBuilder(
    column: $table.maxJumpMassKg,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalMassKg => $composableBuilder(
    column: $table.totalMassKg,
    builder: (column) => column,
  );

  GeneratedColumn<double> get regenerationKgPerCycle => $composableBuilder(
    column: $table.regenerationKgPerCycle,
    builder: (column) => column,
  );
}

class $$SdeWormholeTypesTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeWormholeTypesTable,
          SdeWormholeType,
          $$SdeWormholeTypesTableFilterComposer,
          $$SdeWormholeTypesTableOrderingComposer,
          $$SdeWormholeTypesTableAnnotationComposer,
          $$SdeWormholeTypesTableCreateCompanionBuilder,
          $$SdeWormholeTypesTableUpdateCompanionBuilder,
          (
            SdeWormholeType,
            BaseReferences<
              _$SdeDatabase,
              $SdeWormholeTypesTable,
              SdeWormholeType
            >,
          ),
          SdeWormholeType,
          PrefetchHooks Function()
        > {
  $$SdeWormholeTypesTableTableManager(
    _$SdeDatabase db,
    $SdeWormholeTypesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeWormholeTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeWormholeTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeWormholeTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> typeId = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> groupId = const Value.absent(),
                Value<bool> published = const Value.absent(),
                Value<int?> rawTargetClass = const Value.absent(),
                Value<int?> rawTargetDistribution = const Value.absent(),
                Value<int?> reliableLifetimeSeconds = const Value.absent(),
                Value<double?> maxJumpMassKg = const Value.absent(),
                Value<double?> totalMassKg = const Value.absent(),
                Value<double?> regenerationKgPerCycle = const Value.absent(),
              }) => SdeWormholeTypesCompanion(
                typeId: typeId,
                code: code,
                name: name,
                groupId: groupId,
                published: published,
                rawTargetClass: rawTargetClass,
                rawTargetDistribution: rawTargetDistribution,
                reliableLifetimeSeconds: reliableLifetimeSeconds,
                maxJumpMassKg: maxJumpMassKg,
                totalMassKg: totalMassKg,
                regenerationKgPerCycle: regenerationKgPerCycle,
              ),
          createCompanionCallback:
              ({
                Value<int> typeId = const Value.absent(),
                required String code,
                required String name,
                Value<int> groupId = const Value.absent(),
                Value<bool> published = const Value.absent(),
                Value<int?> rawTargetClass = const Value.absent(),
                Value<int?> rawTargetDistribution = const Value.absent(),
                Value<int?> reliableLifetimeSeconds = const Value.absent(),
                Value<double?> maxJumpMassKg = const Value.absent(),
                Value<double?> totalMassKg = const Value.absent(),
                Value<double?> regenerationKgPerCycle = const Value.absent(),
              }) => SdeWormholeTypesCompanion.insert(
                typeId: typeId,
                code: code,
                name: name,
                groupId: groupId,
                published: published,
                rawTargetClass: rawTargetClass,
                rawTargetDistribution: rawTargetDistribution,
                reliableLifetimeSeconds: reliableLifetimeSeconds,
                maxJumpMassKg: maxJumpMassKg,
                totalMassKg: totalMassKg,
                regenerationKgPerCycle: regenerationKgPerCycle,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeWormholeTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeWormholeTypesTable,
      SdeWormholeType,
      $$SdeWormholeTypesTableFilterComposer,
      $$SdeWormholeTypesTableOrderingComposer,
      $$SdeWormholeTypesTableAnnotationComposer,
      $$SdeWormholeTypesTableCreateCompanionBuilder,
      $$SdeWormholeTypesTableUpdateCompanionBuilder,
      (
        SdeWormholeType,
        BaseReferences<_$SdeDatabase, $SdeWormholeTypesTable, SdeWormholeType>,
      ),
      SdeWormholeType,
      PrefetchHooks Function()
    >;
typedef $$SdeWormholeSystemsTableCreateCompanionBuilder =
    SdeWormholeSystemsCompanion Function({
      Value<int> systemId,
      required String name,
      Value<int?> constellationId,
      Value<int?> regionId,
      Value<String?> constellationName,
      Value<String?> regionName,
      Value<double?> rawSecurity,
      Value<int?> rawClass,
      Value<int?> inheritedClass,
      Value<String?> inheritanceSource,
      Value<int?> effectBeaconTypeId,
      Value<int?> visualSunTypeId,
    });
typedef $$SdeWormholeSystemsTableUpdateCompanionBuilder =
    SdeWormholeSystemsCompanion Function({
      Value<int> systemId,
      Value<String> name,
      Value<int?> constellationId,
      Value<int?> regionId,
      Value<String?> constellationName,
      Value<String?> regionName,
      Value<double?> rawSecurity,
      Value<int?> rawClass,
      Value<int?> inheritedClass,
      Value<String?> inheritanceSource,
      Value<int?> effectBeaconTypeId,
      Value<int?> visualSunTypeId,
    });

class $$SdeWormholeSystemsTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeWormholeSystemsTable> {
  $$SdeWormholeSystemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get systemId => $composableBuilder(
    column: $table.systemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get constellationId => $composableBuilder(
    column: $table.constellationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get regionId => $composableBuilder(
    column: $table.regionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get constellationName => $composableBuilder(
    column: $table.constellationName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get regionName => $composableBuilder(
    column: $table.regionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rawSecurity => $composableBuilder(
    column: $table.rawSecurity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rawClass => $composableBuilder(
    column: $table.rawClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inheritedClass => $composableBuilder(
    column: $table.inheritedClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inheritanceSource => $composableBuilder(
    column: $table.inheritanceSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get effectBeaconTypeId => $composableBuilder(
    column: $table.effectBeaconTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get visualSunTypeId => $composableBuilder(
    column: $table.visualSunTypeId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeWormholeSystemsTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeWormholeSystemsTable> {
  $$SdeWormholeSystemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get systemId => $composableBuilder(
    column: $table.systemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get constellationId => $composableBuilder(
    column: $table.constellationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get regionId => $composableBuilder(
    column: $table.regionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get constellationName => $composableBuilder(
    column: $table.constellationName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get regionName => $composableBuilder(
    column: $table.regionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rawSecurity => $composableBuilder(
    column: $table.rawSecurity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rawClass => $composableBuilder(
    column: $table.rawClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inheritedClass => $composableBuilder(
    column: $table.inheritedClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inheritanceSource => $composableBuilder(
    column: $table.inheritanceSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get effectBeaconTypeId => $composableBuilder(
    column: $table.effectBeaconTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get visualSunTypeId => $composableBuilder(
    column: $table.visualSunTypeId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeWormholeSystemsTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeWormholeSystemsTable> {
  $$SdeWormholeSystemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get systemId =>
      $composableBuilder(column: $table.systemId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get constellationId => $composableBuilder(
    column: $table.constellationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get regionId =>
      $composableBuilder(column: $table.regionId, builder: (column) => column);

  GeneratedColumn<String> get constellationName => $composableBuilder(
    column: $table.constellationName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get regionName => $composableBuilder(
    column: $table.regionName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rawSecurity => $composableBuilder(
    column: $table.rawSecurity,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rawClass =>
      $composableBuilder(column: $table.rawClass, builder: (column) => column);

  GeneratedColumn<int> get inheritedClass => $composableBuilder(
    column: $table.inheritedClass,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inheritanceSource => $composableBuilder(
    column: $table.inheritanceSource,
    builder: (column) => column,
  );

  GeneratedColumn<int> get effectBeaconTypeId => $composableBuilder(
    column: $table.effectBeaconTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get visualSunTypeId => $composableBuilder(
    column: $table.visualSunTypeId,
    builder: (column) => column,
  );
}

class $$SdeWormholeSystemsTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeWormholeSystemsTable,
          SdeWormholeSystem,
          $$SdeWormholeSystemsTableFilterComposer,
          $$SdeWormholeSystemsTableOrderingComposer,
          $$SdeWormholeSystemsTableAnnotationComposer,
          $$SdeWormholeSystemsTableCreateCompanionBuilder,
          $$SdeWormholeSystemsTableUpdateCompanionBuilder,
          (
            SdeWormholeSystem,
            BaseReferences<
              _$SdeDatabase,
              $SdeWormholeSystemsTable,
              SdeWormholeSystem
            >,
          ),
          SdeWormholeSystem,
          PrefetchHooks Function()
        > {
  $$SdeWormholeSystemsTableTableManager(
    _$SdeDatabase db,
    $SdeWormholeSystemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeWormholeSystemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeWormholeSystemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeWormholeSystemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> systemId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> constellationId = const Value.absent(),
                Value<int?> regionId = const Value.absent(),
                Value<String?> constellationName = const Value.absent(),
                Value<String?> regionName = const Value.absent(),
                Value<double?> rawSecurity = const Value.absent(),
                Value<int?> rawClass = const Value.absent(),
                Value<int?> inheritedClass = const Value.absent(),
                Value<String?> inheritanceSource = const Value.absent(),
                Value<int?> effectBeaconTypeId = const Value.absent(),
                Value<int?> visualSunTypeId = const Value.absent(),
              }) => SdeWormholeSystemsCompanion(
                systemId: systemId,
                name: name,
                constellationId: constellationId,
                regionId: regionId,
                constellationName: constellationName,
                regionName: regionName,
                rawSecurity: rawSecurity,
                rawClass: rawClass,
                inheritedClass: inheritedClass,
                inheritanceSource: inheritanceSource,
                effectBeaconTypeId: effectBeaconTypeId,
                visualSunTypeId: visualSunTypeId,
              ),
          createCompanionCallback:
              ({
                Value<int> systemId = const Value.absent(),
                required String name,
                Value<int?> constellationId = const Value.absent(),
                Value<int?> regionId = const Value.absent(),
                Value<String?> constellationName = const Value.absent(),
                Value<String?> regionName = const Value.absent(),
                Value<double?> rawSecurity = const Value.absent(),
                Value<int?> rawClass = const Value.absent(),
                Value<int?> inheritedClass = const Value.absent(),
                Value<String?> inheritanceSource = const Value.absent(),
                Value<int?> effectBeaconTypeId = const Value.absent(),
                Value<int?> visualSunTypeId = const Value.absent(),
              }) => SdeWormholeSystemsCompanion.insert(
                systemId: systemId,
                name: name,
                constellationId: constellationId,
                regionId: regionId,
                constellationName: constellationName,
                regionName: regionName,
                rawSecurity: rawSecurity,
                rawClass: rawClass,
                inheritedClass: inheritedClass,
                inheritanceSource: inheritanceSource,
                effectBeaconTypeId: effectBeaconTypeId,
                visualSunTypeId: visualSunTypeId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeWormholeSystemsTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeWormholeSystemsTable,
      SdeWormholeSystem,
      $$SdeWormholeSystemsTableFilterComposer,
      $$SdeWormholeSystemsTableOrderingComposer,
      $$SdeWormholeSystemsTableAnnotationComposer,
      $$SdeWormholeSystemsTableCreateCompanionBuilder,
      $$SdeWormholeSystemsTableUpdateCompanionBuilder,
      (
        SdeWormholeSystem,
        BaseReferences<
          _$SdeDatabase,
          $SdeWormholeSystemsTable,
          SdeWormholeSystem
        >,
      ),
      SdeWormholeSystem,
      PrefetchHooks Function()
    >;
typedef $$SdeSystemEffectsTableCreateCompanionBuilder =
    SdeSystemEffectsCompanion Function({
      Value<int> beaconTypeId,
      required String family,
      required int strength,
      Value<String?> scopesJson,
    });
typedef $$SdeSystemEffectsTableUpdateCompanionBuilder =
    SdeSystemEffectsCompanion Function({
      Value<int> beaconTypeId,
      Value<String> family,
      Value<int> strength,
      Value<String?> scopesJson,
    });

class $$SdeSystemEffectsTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeSystemEffectsTable> {
  $$SdeSystemEffectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get beaconTypeId => $composableBuilder(
    column: $table.beaconTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get strength => $composableBuilder(
    column: $table.strength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopesJson => $composableBuilder(
    column: $table.scopesJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeSystemEffectsTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeSystemEffectsTable> {
  $$SdeSystemEffectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get beaconTypeId => $composableBuilder(
    column: $table.beaconTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get strength => $composableBuilder(
    column: $table.strength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopesJson => $composableBuilder(
    column: $table.scopesJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeSystemEffectsTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeSystemEffectsTable> {
  $$SdeSystemEffectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get beaconTypeId => $composableBuilder(
    column: $table.beaconTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get family =>
      $composableBuilder(column: $table.family, builder: (column) => column);

  GeneratedColumn<int> get strength =>
      $composableBuilder(column: $table.strength, builder: (column) => column);

  GeneratedColumn<String> get scopesJson => $composableBuilder(
    column: $table.scopesJson,
    builder: (column) => column,
  );
}

class $$SdeSystemEffectsTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeSystemEffectsTable,
          SdeSystemEffect,
          $$SdeSystemEffectsTableFilterComposer,
          $$SdeSystemEffectsTableOrderingComposer,
          $$SdeSystemEffectsTableAnnotationComposer,
          $$SdeSystemEffectsTableCreateCompanionBuilder,
          $$SdeSystemEffectsTableUpdateCompanionBuilder,
          (
            SdeSystemEffect,
            BaseReferences<
              _$SdeDatabase,
              $SdeSystemEffectsTable,
              SdeSystemEffect
            >,
          ),
          SdeSystemEffect,
          PrefetchHooks Function()
        > {
  $$SdeSystemEffectsTableTableManager(
    _$SdeDatabase db,
    $SdeSystemEffectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeSystemEffectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeSystemEffectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeSystemEffectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> beaconTypeId = const Value.absent(),
                Value<String> family = const Value.absent(),
                Value<int> strength = const Value.absent(),
                Value<String?> scopesJson = const Value.absent(),
              }) => SdeSystemEffectsCompanion(
                beaconTypeId: beaconTypeId,
                family: family,
                strength: strength,
                scopesJson: scopesJson,
              ),
          createCompanionCallback:
              ({
                Value<int> beaconTypeId = const Value.absent(),
                required String family,
                required int strength,
                Value<String?> scopesJson = const Value.absent(),
              }) => SdeSystemEffectsCompanion.insert(
                beaconTypeId: beaconTypeId,
                family: family,
                strength: strength,
                scopesJson: scopesJson,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeSystemEffectsTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeSystemEffectsTable,
      SdeSystemEffect,
      $$SdeSystemEffectsTableFilterComposer,
      $$SdeSystemEffectsTableOrderingComposer,
      $$SdeSystemEffectsTableAnnotationComposer,
      $$SdeSystemEffectsTableCreateCompanionBuilder,
      $$SdeSystemEffectsTableUpdateCompanionBuilder,
      (
        SdeSystemEffect,
        BaseReferences<_$SdeDatabase, $SdeSystemEffectsTable, SdeSystemEffect>,
      ),
      SdeSystemEffect,
      PrefetchHooks Function()
    >;
typedef $$SdeStargatesTableCreateCompanionBuilder =
    SdeStargatesCompanion Function({
      Value<int> gateId,
      required int fromSystemId,
      required int toSystemId,
      Value<int> topologyVersion,
      Value<String?> restrictionsJson,
    });
typedef $$SdeStargatesTableUpdateCompanionBuilder =
    SdeStargatesCompanion Function({
      Value<int> gateId,
      Value<int> fromSystemId,
      Value<int> toSystemId,
      Value<int> topologyVersion,
      Value<String?> restrictionsJson,
    });

class $$SdeStargatesTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeStargatesTable> {
  $$SdeStargatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get gateId => $composableBuilder(
    column: $table.gateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fromSystemId => $composableBuilder(
    column: $table.fromSystemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get toSystemId => $composableBuilder(
    column: $table.toSystemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get topologyVersion => $composableBuilder(
    column: $table.topologyVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get restrictionsJson => $composableBuilder(
    column: $table.restrictionsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeStargatesTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeStargatesTable> {
  $$SdeStargatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get gateId => $composableBuilder(
    column: $table.gateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fromSystemId => $composableBuilder(
    column: $table.fromSystemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get toSystemId => $composableBuilder(
    column: $table.toSystemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get topologyVersion => $composableBuilder(
    column: $table.topologyVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get restrictionsJson => $composableBuilder(
    column: $table.restrictionsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeStargatesTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeStargatesTable> {
  $$SdeStargatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get gateId =>
      $composableBuilder(column: $table.gateId, builder: (column) => column);

  GeneratedColumn<int> get fromSystemId => $composableBuilder(
    column: $table.fromSystemId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get toSystemId => $composableBuilder(
    column: $table.toSystemId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get topologyVersion => $composableBuilder(
    column: $table.topologyVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get restrictionsJson => $composableBuilder(
    column: $table.restrictionsJson,
    builder: (column) => column,
  );
}

class $$SdeStargatesTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeStargatesTable,
          SdeStargate,
          $$SdeStargatesTableFilterComposer,
          $$SdeStargatesTableOrderingComposer,
          $$SdeStargatesTableAnnotationComposer,
          $$SdeStargatesTableCreateCompanionBuilder,
          $$SdeStargatesTableUpdateCompanionBuilder,
          (
            SdeStargate,
            BaseReferences<_$SdeDatabase, $SdeStargatesTable, SdeStargate>,
          ),
          SdeStargate,
          PrefetchHooks Function()
        > {
  $$SdeStargatesTableTableManager(_$SdeDatabase db, $SdeStargatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeStargatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeStargatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeStargatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> gateId = const Value.absent(),
                Value<int> fromSystemId = const Value.absent(),
                Value<int> toSystemId = const Value.absent(),
                Value<int> topologyVersion = const Value.absent(),
                Value<String?> restrictionsJson = const Value.absent(),
              }) => SdeStargatesCompanion(
                gateId: gateId,
                fromSystemId: fromSystemId,
                toSystemId: toSystemId,
                topologyVersion: topologyVersion,
                restrictionsJson: restrictionsJson,
              ),
          createCompanionCallback:
              ({
                Value<int> gateId = const Value.absent(),
                required int fromSystemId,
                required int toSystemId,
                Value<int> topologyVersion = const Value.absent(),
                Value<String?> restrictionsJson = const Value.absent(),
              }) => SdeStargatesCompanion.insert(
                gateId: gateId,
                fromSystemId: fromSystemId,
                toSystemId: toSystemId,
                topologyVersion: topologyVersion,
                restrictionsJson: restrictionsJson,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeStargatesTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeStargatesTable,
      SdeStargate,
      $$SdeStargatesTableFilterComposer,
      $$SdeStargatesTableOrderingComposer,
      $$SdeStargatesTableAnnotationComposer,
      $$SdeStargatesTableCreateCompanionBuilder,
      $$SdeStargatesTableUpdateCompanionBuilder,
      (
        SdeStargate,
        BaseReferences<_$SdeDatabase, $SdeStargatesTable, SdeStargate>,
      ),
      SdeStargate,
      PrefetchHooks Function()
    >;
typedef $$SdeSystemStaticsTableCreateCompanionBuilder =
    SdeSystemStaticsCompanion Function({
      required int systemId,
      required int assignmentIndex,
      Value<String?> code,
      Value<int?> typeId,
      Value<String> meaning,
      Value<String> source,
      Value<String> confidence,
      Value<int> rowid,
    });
typedef $$SdeSystemStaticsTableUpdateCompanionBuilder =
    SdeSystemStaticsCompanion Function({
      Value<int> systemId,
      Value<int> assignmentIndex,
      Value<String?> code,
      Value<int?> typeId,
      Value<String> meaning,
      Value<String> source,
      Value<String> confidence,
      Value<int> rowid,
    });

class $$SdeSystemStaticsTableFilterComposer
    extends Composer<_$SdeDatabase, $SdeSystemStaticsTable> {
  $$SdeSystemStaticsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get systemId => $composableBuilder(
    column: $table.systemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get assignmentIndex => $composableBuilder(
    column: $table.assignmentIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SdeSystemStaticsTableOrderingComposer
    extends Composer<_$SdeDatabase, $SdeSystemStaticsTable> {
  $$SdeSystemStaticsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get systemId => $composableBuilder(
    column: $table.systemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get assignmentIndex => $composableBuilder(
    column: $table.assignmentIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get typeId => $composableBuilder(
    column: $table.typeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SdeSystemStaticsTableAnnotationComposer
    extends Composer<_$SdeDatabase, $SdeSystemStaticsTable> {
  $$SdeSystemStaticsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get systemId =>
      $composableBuilder(column: $table.systemId, builder: (column) => column);

  GeneratedColumn<int> get assignmentIndex => $composableBuilder(
    column: $table.assignmentIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<int> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );
}

class $$SdeSystemStaticsTableTableManager
    extends
        RootTableManager<
          _$SdeDatabase,
          $SdeSystemStaticsTable,
          SdeSystemStatic,
          $$SdeSystemStaticsTableFilterComposer,
          $$SdeSystemStaticsTableOrderingComposer,
          $$SdeSystemStaticsTableAnnotationComposer,
          $$SdeSystemStaticsTableCreateCompanionBuilder,
          $$SdeSystemStaticsTableUpdateCompanionBuilder,
          (
            SdeSystemStatic,
            BaseReferences<
              _$SdeDatabase,
              $SdeSystemStaticsTable,
              SdeSystemStatic
            >,
          ),
          SdeSystemStatic,
          PrefetchHooks Function()
        > {
  $$SdeSystemStaticsTableTableManager(
    _$SdeDatabase db,
    $SdeSystemStaticsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SdeSystemStaticsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SdeSystemStaticsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SdeSystemStaticsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> systemId = const Value.absent(),
                Value<int> assignmentIndex = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<int?> typeId = const Value.absent(),
                Value<String> meaning = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> confidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SdeSystemStaticsCompanion(
                systemId: systemId,
                assignmentIndex: assignmentIndex,
                code: code,
                typeId: typeId,
                meaning: meaning,
                source: source,
                confidence: confidence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int systemId,
                required int assignmentIndex,
                Value<String?> code = const Value.absent(),
                Value<int?> typeId = const Value.absent(),
                Value<String> meaning = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> confidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SdeSystemStaticsCompanion.insert(
                systemId: systemId,
                assignmentIndex: assignmentIndex,
                code: code,
                typeId: typeId,
                meaning: meaning,
                source: source,
                confidence: confidence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SdeSystemStaticsTableProcessedTableManager =
    ProcessedTableManager<
      _$SdeDatabase,
      $SdeSystemStaticsTable,
      SdeSystemStatic,
      $$SdeSystemStaticsTableFilterComposer,
      $$SdeSystemStaticsTableOrderingComposer,
      $$SdeSystemStaticsTableAnnotationComposer,
      $$SdeSystemStaticsTableCreateCompanionBuilder,
      $$SdeSystemStaticsTableUpdateCompanionBuilder,
      (
        SdeSystemStatic,
        BaseReferences<_$SdeDatabase, $SdeSystemStaticsTable, SdeSystemStatic>,
      ),
      SdeSystemStatic,
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
  $$SdeWormholeTypesTableTableManager get sdeWormholeTypes =>
      $$SdeWormholeTypesTableTableManager(_db, _db.sdeWormholeTypes);
  $$SdeWormholeSystemsTableTableManager get sdeWormholeSystems =>
      $$SdeWormholeSystemsTableTableManager(_db, _db.sdeWormholeSystems);
  $$SdeSystemEffectsTableTableManager get sdeSystemEffects =>
      $$SdeSystemEffectsTableTableManager(_db, _db.sdeSystemEffects);
  $$SdeStargatesTableTableManager get sdeStargates =>
      $$SdeStargatesTableTableManager(_db, _db.sdeStargates);
  $$SdeSystemStaticsTableTableManager get sdeSystemStatics =>
      $$SdeSystemStaticsTableTableManager(_db, _db.sdeSystemStatics);
}
