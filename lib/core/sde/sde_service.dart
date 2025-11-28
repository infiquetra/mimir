import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sde_database.dart';

/// Service for managing Static Data Export (SDE) data.
///
/// Handles loading, caching, and updating EVE Online reference data
/// such as skill names, groups, and categories.
///
/// Uses a hybrid strategy:
/// - Bundle skills with the app for offline availability
/// - Check for updates in background
/// - In-memory cache for fast lookups
class SdeService {
  SdeService({required this.database});

  final SdeDatabase database;

  /// In-memory cache for fast skill name lookups.
  final Map<int, String> _skillNameCache = {};

  /// Whether the service has been initialized.
  bool _initialized = false;

  /// URL to fetch skills data (Fuzzwork SDE API).
  static const String _skillsApiUrl =
      'https://www.fuzzwork.co.uk/api/typematerials.php?categoryID=16';

  /// Alternative: Direct SDE endpoint for skill types.
  /// Using a simpler approach with bundled JSON for reliability.
  static const String _bundledSkillsAsset = 'assets/sde/skills.json';

  /// Initialize the SDE service.
  ///
  /// Loads skill data from bundled assets or database.
  /// Should be called during app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    // Check if database already has data
    final hasData = await database.hasSkillData();

    if (!hasData) {
      // Load from bundled assets
      await _loadBundledSkills();
    }

    // Populate in-memory cache
    await _populateCache();

    _initialized = true;
  }

  /// Load skills from bundled JSON asset.
  Future<void> _loadBundledSkills() async {
    try {
      final jsonString = await rootBundle.loadString(_bundledSkillsAsset);
      final data = json.decode(jsonString) as Map<String, dynamic>;
      await _importSkillsData(data);
    } catch (e) {
      // Asset not found - use fallback hardcoded data for common skills
      debugPrint('SDE: Bundled skills not found, using fallback data');
      await _loadFallbackSkills();
    }
  }

  /// Load hardcoded fallback skills for basic functionality.
  ///
  /// This ensures the app works even without bundled SDE data.
  /// Contains only the most common skills.
  Future<void> _loadFallbackSkills() async {
    // Skill category
    await database.upsertCategories([
      SdeCategoriesCompanion.insert(
        categoryId: const Value(16),
        categoryName: 'Skill',
      ),
    ]);

    // Common skill groups
    final groups = <SdeGroupsCompanion>[
      SdeGroupsCompanion.insert(
        groupId: const Value(255),
        groupName: 'Spaceship Command',
        categoryId: 16,
      ),
      SdeGroupsCompanion.insert(
        groupId: const Value(256),
        groupName: 'Gunnery',
        categoryId: 16,
      ),
      SdeGroupsCompanion.insert(
        groupId: const Value(257),
        groupName: 'Missiles',
        categoryId: 16,
      ),
      SdeGroupsCompanion.insert(
        groupId: const Value(258),
        groupName: 'Drones',
        categoryId: 16,
      ),
      SdeGroupsCompanion.insert(
        groupId: const Value(266),
        groupName: 'Mining',
        categoryId: 16,
      ),
      SdeGroupsCompanion.insert(
        groupId: const Value(269),
        groupName: 'Engineering',
        categoryId: 16,
      ),
      SdeGroupsCompanion.insert(
        groupId: const Value(272),
        groupName: 'Electronic Systems',
        categoryId: 16,
      ),
      SdeGroupsCompanion.insert(
        groupId: const Value(273),
        groupName: 'Rigging',
        categoryId: 16,
      ),
      SdeGroupsCompanion.insert(
        groupId: const Value(274),
        groupName: 'Armor',
        categoryId: 16,
      ),
      SdeGroupsCompanion.insert(
        groupId: const Value(275),
        groupName: 'Shield',
        categoryId: 16,
      ),
      SdeGroupsCompanion.insert(
        groupId: const Value(278),
        groupName: 'Navigation',
        categoryId: 16,
      ),
      SdeGroupsCompanion.insert(
        groupId: const Value(1216),
        groupName: 'Neural Enhancement',
        categoryId: 16,
      ),
    ];
    await database.upsertGroups(groups);

    // Common spaceship command skills
    final skills = <SdeTypesCompanion>[
      // Spaceship Command
      SdeTypesCompanion.insert(
        typeId: const Value(3327),
        typeName: 'Spaceship Command',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3330),
        typeName: 'Amarr Frigate',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3328),
        typeName: 'Caldari Frigate',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3329),
        typeName: 'Gallente Frigate',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3331),
        typeName: 'Minmatar Frigate',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(33095),
        typeName: 'Amarr Destroyer',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(33093),
        typeName: 'Caldari Destroyer',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(33094),
        typeName: 'Gallente Destroyer',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(33092),
        typeName: 'Minmatar Destroyer',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3332),
        typeName: 'Amarr Cruiser',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3334),
        typeName: 'Caldari Cruiser',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3333),
        typeName: 'Gallente Cruiser',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3335),
        typeName: 'Minmatar Cruiser',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3336),
        typeName: 'Amarr Battlecruiser',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3338),
        typeName: 'Caldari Battlecruiser',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3337),
        typeName: 'Gallente Battlecruiser',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3339),
        typeName: 'Minmatar Battlecruiser',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3340),
        typeName: 'Amarr Battleship',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3342),
        typeName: 'Caldari Battleship',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3341),
        typeName: 'Gallente Battleship',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3343),
        typeName: 'Minmatar Battleship',
        groupId: 255,
      ),
      // Mining
      SdeTypesCompanion.insert(
        typeId: const Value(3386),
        typeName: 'Mining',
        groupId: 266,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(12195),
        typeName: 'Astrogeology',
        groupId: 266,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(22578),
        typeName: 'Mining Barge',
        groupId: 255,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(22551),
        typeName: 'Exhumers',
        groupId: 255,
      ),
      // Common core skills
      SdeTypesCompanion.insert(
        typeId: const Value(3413),
        typeName: 'Power Grid Management',
        groupId: 269,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3418),
        typeName: 'CPU Management',
        groupId: 269,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3426),
        typeName: 'Capacitor Management',
        groupId: 269,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3417),
        typeName: 'Hull Upgrades',
        groupId: 274,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3392),
        typeName: 'Mechanics',
        groupId: 274,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3416),
        typeName: 'Shield Operation',
        groupId: 275,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3419),
        typeName: 'Shield Management',
        groupId: 275,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3449),
        typeName: 'Navigation',
        groupId: 278,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3453),
        typeName: 'Warp Drive Operation',
        groupId: 278,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3455),
        typeName: 'Evasive Maneuvering',
        groupId: 278,
      ),
    ];
    await database.upsertTypes(skills);
  }

  /// Import skills data from parsed JSON.
  Future<void> _importSkillsData(Map<String, dynamic> data) async {
    // Expected format:
    // {
    //   "categories": [{"categoryId": 16, "categoryName": "Skill"}],
    //   "groups": [{"groupId": 255, "groupName": "...", "categoryId": 16}],
    //   "types": [{"typeId": 123, "typeName": "...", "groupId": 255}]
    // }

    if (data.containsKey('categories')) {
      final categories = (data['categories'] as List)
          .map((c) => SdeCategoriesCompanion.insert(
                categoryId: Value(c['categoryId'] as int),
                categoryName: c['categoryName'] as String,
              ))
          .toList();
      await database.upsertCategories(categories);
    }

    if (data.containsKey('groups')) {
      final groups = (data['groups'] as List)
          .map((g) => SdeGroupsCompanion.insert(
                groupId: Value(g['groupId'] as int),
                groupName: g['groupName'] as String,
                categoryId: g['categoryId'] as int,
              ))
          .toList();
      await database.upsertGroups(groups);
    }

    if (data.containsKey('types')) {
      final types = (data['types'] as List)
          .map((t) => SdeTypesCompanion.insert(
                typeId: Value(t['typeId'] as int),
                typeName: t['typeName'] as String,
                groupId: t['groupId'] as int,
                description: t['description'] != null
                    ? Value(t['description'] as String)
                    : const Value.absent(),
              ))
          .toList();
      await database.upsertTypes(types);
    }
  }

  /// Populate the in-memory cache from the database.
  Future<void> _populateCache() async {
    final skills = await database.getAllSkills();
    _skillNameCache.clear();
    for (final skill in skills) {
      _skillNameCache[skill.typeId] = skill.typeName;
    }
    debugPrint('SDE: Loaded ${_skillNameCache.length} skills into cache');
  }

  /// Get a skill name by type ID.
  ///
  /// Returns the cached name if available, otherwise
  /// queries the database. Returns null if not found.
  Future<String?> getSkillName(int typeId) async {
    // Check cache first
    if (_skillNameCache.containsKey(typeId)) {
      return _skillNameCache[typeId];
    }

    // Fall back to database query
    final name = await database.getTypeName(typeId);
    if (name != null) {
      _skillNameCache[typeId] = name;
    }
    return name;
  }

  /// Get skill name synchronously from cache.
  ///
  /// Returns null if not in cache. Use [getSkillName] for
  /// guaranteed lookups that may hit the database.
  String? getSkillNameSync(int typeId) {
    return _skillNameCache[typeId];
  }

  /// Get multiple skill names at once.
  Future<Map<int, String>> getSkillNames(List<int> typeIds) async {
    final result = <int, String>{};
    final missingIds = <int>[];

    // Check cache first
    for (final id in typeIds) {
      final cached = _skillNameCache[id];
      if (cached != null) {
        result[id] = cached;
      } else {
        missingIds.add(id);
      }
    }

    // Fetch missing from database
    if (missingIds.isNotEmpty) {
      final fromDb = await database.getTypeNames(missingIds);
      result.addAll(fromDb);
      _skillNameCache.addAll(fromDb);
    }

    return result;
  }

  /// Get all skill groups.
  Future<List<SdeGroup>> getSkillGroups() {
    return database.getSkillGroups();
  }

  /// Get skills in a specific group.
  Future<List<SdeType>> getSkillsByGroup(int groupId) {
    return database.getTypesByGroup(groupId);
  }

  /// Check for SDE updates from remote source.
  ///
  /// This is a background operation that should not block the UI.
  Future<void> checkForUpdates() async {
    // TODO: Implement version checking and incremental updates
    // For now, this is a placeholder for future enhancement
    debugPrint('SDE: Update check not yet implemented');
  }

  /// Force refresh all SDE data.
  ///
  /// Downloads fresh data and repopulates the database.
  Future<void> forceRefresh() async {
    try {
      final dio = Dio();
      final response = await dio.get(_skillsApiUrl);
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        await database.clearAll();
        await _importSkillsData(data);
        await _populateCache();
      }
    } catch (e) {
      debugPrint('SDE: Force refresh failed: $e');
      rethrow;
    }
  }

  /// Get initialization status.
  bool get isInitialized => _initialized;

  /// Get the number of cached skill names.
  int get cachedSkillCount => _skillNameCache.length;
}
