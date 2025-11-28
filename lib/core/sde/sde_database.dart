import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'sde_database.g.dart';

/// EVE Online item types from the Static Data Export.
///
/// Stores type information including skill names, descriptions,
/// and group associations.
class SdeTypes extends Table {
  /// Type ID (primary key) - matches EVE typeID.
  IntColumn get typeId => integer()();

  /// Type name (e.g., "Caldari Frigate", "Mining Barge").
  TextColumn get typeName => text()();

  /// Group ID this type belongs to.
  IntColumn get groupId => integer()();

  /// Type description (optional).
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {typeId};
}

/// EVE Online item groups from the Static Data Export.
///
/// Groups organize types within categories (e.g., skill groups
/// like "Spaceship Command", "Gunnery").
class SdeGroups extends Table {
  /// Group ID (primary key) - matches EVE groupID.
  IntColumn get groupId => integer()();

  /// Group name (e.g., "Spaceship Command", "Shield").
  TextColumn get groupName => text()();

  /// Category ID this group belongs to.
  IntColumn get categoryId => integer()();

  @override
  Set<Column> get primaryKey => {groupId};
}

/// EVE Online categories from the Static Data Export.
///
/// Top-level classification (e.g., "Skill" = categoryId 16).
class SdeCategories extends Table {
  /// Category ID (primary key) - matches EVE categoryID.
  IntColumn get categoryId => integer()();

  /// Category name (e.g., "Skill", "Ship").
  TextColumn get categoryName => text()();

  @override
  Set<Column> get primaryKey => {categoryId};
}

/// Static Data Export database using Drift.
///
/// Stores EVE Online reference data for offline lookups:
/// - Type names (skills, ships, items)
/// - Group information
/// - Category classification
///
/// This is a read-mostly database that's populated from
/// bundled assets or downloaded from Fuzzwork.
@DriftDatabase(tables: [
  SdeTypes,
  SdeGroups,
  SdeCategories,
])
class SdeDatabase extends _$SdeDatabase {
  SdeDatabase() : super(_openConnection());

  /// Constructor for testing with custom executor.
  SdeDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
    );
  }

  // Type operations

  /// Get a type by ID.
  Future<SdeType?> getType(int typeId) {
    return (select(sdeTypes)..where((t) => t.typeId.equals(typeId)))
        .getSingleOrNull();
  }

  /// Get type name by ID (convenience method).
  Future<String?> getTypeName(int typeId) async {
    final type = await getType(typeId);
    return type?.typeName;
  }

  /// Get multiple types by IDs.
  Future<Map<int, String>> getTypeNames(List<int> typeIds) async {
    if (typeIds.isEmpty) return {};

    final types = await (select(sdeTypes)
          ..where((t) => t.typeId.isIn(typeIds)))
        .get();

    return {for (final t in types) t.typeId: t.typeName};
  }

  /// Get all types in a group.
  Future<List<SdeType>> getTypesByGroup(int groupId) {
    return (select(sdeTypes)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.asc(t.typeName)]))
        .get();
  }

  /// Get all skill types (category 16).
  Future<List<SdeType>> getAllSkills() async {
    // Skills have categoryId = 16
    // First get all groups in the Skill category
    final skillGroups = await (select(sdeGroups)
          ..where((g) => g.categoryId.equals(16)))
        .get();

    if (skillGroups.isEmpty) return [];

    final groupIds = skillGroups.map((g) => g.groupId).toList();

    return (select(sdeTypes)
          ..where((t) => t.groupId.isIn(groupIds))
          ..orderBy([(t) => OrderingTerm.asc(t.typeName)]))
        .get();
  }

  // Group operations

  /// Get a group by ID.
  Future<SdeGroup?> getGroup(int groupId) {
    return (select(sdeGroups)..where((g) => g.groupId.equals(groupId)))
        .getSingleOrNull();
  }

  /// Get all groups in a category.
  Future<List<SdeGroup>> getGroupsByCategory(int categoryId) {
    return (select(sdeGroups)
          ..where((g) => g.categoryId.equals(categoryId))
          ..orderBy([(g) => OrderingTerm.asc(g.groupName)]))
        .get();
  }

  /// Get all skill groups (category 16).
  Future<List<SdeGroup>> getSkillGroups() {
    return getGroupsByCategory(16);
  }

  // Category operations

  /// Get a category by ID.
  Future<SdeCategory?> getCategory(int categoryId) {
    return (select(sdeCategories)..where((c) => c.categoryId.equals(categoryId)))
        .getSingleOrNull();
  }

  // Bulk insert operations (for populating the database)

  /// Insert or update types.
  Future<void> upsertTypes(List<SdeTypesCompanion> types) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(sdeTypes, types);
    });
  }

  /// Insert or update groups.
  Future<void> upsertGroups(List<SdeGroupsCompanion> groups) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(sdeGroups, groups);
    });
  }

  /// Insert or update categories.
  Future<void> upsertCategories(List<SdeCategoriesCompanion> categories) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(sdeCategories, categories);
    });
  }

  /// Check if the database has any skill data.
  Future<bool> hasSkillData() async {
    final count = await (selectOnly(sdeTypes)
          ..addColumns([sdeTypes.typeId.count()]))
        .map((row) => row.read(sdeTypes.typeId.count()))
        .getSingle();
    return (count ?? 0) > 0;
  }

  /// Clear all data (for refresh).
  Future<void> clearAll() async {
    await transaction(() async {
      await delete(sdeTypes).go();
      await delete(sdeGroups).go();
      await delete(sdeCategories).go();
    });
  }
}

/// Opens the SDE database connection.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'mimir_sde.db'));
    return NativeDatabase.createInBackground(file);
  });
}
