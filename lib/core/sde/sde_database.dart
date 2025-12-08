import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart' show getDatabasePath;

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

  /// Skill rank (training time multiplier) - only for skills.
  /// Null for non-skill types.
  IntColumn get rank => integer().nullable()();

  /// Primary attribute for skill training - only for skills.
  /// One of: perception, willpower, intelligence, memory, charisma.
  /// Null for non-skill types.
  TextColumn get primaryAttribute => text().nullable()();

  /// Secondary attribute for skill training - only for skills.
  /// One of: perception, willpower, intelligence, memory, charisma.
  /// Null for non-skill types.
  TextColumn get secondaryAttribute => text().nullable()();

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

/// Metadata about the SDE data version and update status.
///
/// Stores key-value pairs for:
/// - `version` - Installed SDE version (e.g., "20250805")
/// - `eve_version` - EVE SDE release name (e.g., "sde-20250805-TRANQUILITY")
/// - `last_check` - ISO8601 timestamp of last update check
/// - `checksum` - SHA256 of installed skills.json
/// - `skill_count` - Number of skills in the database
class SdeMetadata extends Table {
  /// Key for the metadata entry.
  TextColumn get key => text()();

  /// Value for the metadata entry.
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Skill prerequisites from the Static Data Export.
///
/// Stores prerequisite requirements for skills. A skill can have
/// up to 3 prerequisites, each requiring a specific skill level.
///
/// Example: "Medium Hybrid Turret" requires "Gunnery III" and
/// "Small Hybrid Turret III".
class SdeSkillRequirements extends Table {
  /// The skill that has the requirement (e.g., "Medium Hybrid Turret").
  IntColumn get skillId => integer()();

  /// The required skill (e.g., "Gunnery").
  IntColumn get requiredSkillId => integer()();

  /// The required level (1-5).
  IntColumn get requiredLevel => integer()();

  @override
  Set<Column> get primaryKey => {skillId, requiredSkillId};
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
  SdeMetadata,
  SdeSkillRequirements,
])
class SdeDatabase extends _$SdeDatabase {
  SdeDatabase() : super(_openConnection());

  /// Constructor for testing with custom executor.
  SdeDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Version 2: Add SdeMetadata table for version tracking
          await m.createTable(sdeMetadata);
        }
        if (from < 3) {
          // Version 3: Add skill attributes and prerequisites
          // Add new columns to SdeTypes
          await m.addColumn(sdeTypes, sdeTypes.rank);
          await m.addColumn(sdeTypes, sdeTypes.primaryAttribute);
          await m.addColumn(sdeTypes, sdeTypes.secondaryAttribute);

          // Create SdeSkillRequirements table
          await m.createTable(sdeSkillRequirements);
        }
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
      await delete(sdeSkillRequirements).go();
    });
  }

  // Metadata operations

  /// Get a metadata value by key.
  Future<String?> getMetadata(String key) async {
    final row = await (select(sdeMetadata)..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Set a metadata value.
  Future<void> setMetadata(String key, String value) async {
    await into(sdeMetadata).insertOnConflictUpdate(
      SdeMetadataCompanion.insert(key: key, value: value),
    );
  }

  /// Get all metadata as a map.
  Future<Map<String, String>> getAllMetadata() async {
    final rows = await select(sdeMetadata).get();
    return {for (final row in rows) row.key: row.value};
  }

  /// Delete a metadata key.
  Future<void> deleteMetadata(String key) async {
    await (delete(sdeMetadata)..where((m) => m.key.equals(key))).go();
  }

  /// Clear all metadata.
  Future<void> clearMetadata() async {
    await delete(sdeMetadata).go();
  }

  // Skill requirement operations

  /// Get prerequisites for a skill.
  Future<List<SdeSkillRequirement>> getSkillPrerequisites(int skillId) {
    return (select(sdeSkillRequirements)
          ..where((r) => r.skillId.equals(skillId))
          ..orderBy([(r) => OrderingTerm.asc(r.requiredLevel)]))
        .get();
  }

  /// Insert or update skill requirements.
  Future<void> upsertSkillRequirements(
      List<SdeSkillRequirementsCompanion> requirements) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(sdeSkillRequirements, requirements);
    });
  }

  /// Clear all skill requirements (for refresh).
  Future<void> clearSkillRequirements() async {
    await delete(sdeSkillRequirements).go();
  }
}

/// Opens the SDE database connection.
///
/// Uses the shared database path from app_database.dart to ensure
/// sub-windows can access the database without path_provider.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    try {
      // Get the app database path and derive SDE path from it.
      // This works in sub-windows because getDatabasePath() uses the
      // global path set by main.dart before ProviderScope creation.
      final appDbPath = await getDatabasePath();
      final dbFolder = p.dirname(appDbPath);
      final file = File(p.join(dbFolder, 'mimir_sde.db'));
      debugPrint('SdeDatabase: Opening at ${file.path}');
      final db = NativeDatabase.createInBackground(file);
      debugPrint('SdeDatabase: Connection established successfully');
      return db;
    } catch (e, stack) {
      debugPrint('SdeDatabase: ERROR opening connection: $e');
      debugPrint('SdeDatabase: Stack trace: $stack');
      rethrow;
    }
  });
}
