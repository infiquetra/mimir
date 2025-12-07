import 'package:drift/drift.dart';
import 'package:mimir/core/database/app_database.dart';

/// Test fixtures for skill queue data.
///
/// Provides pre-built SkillQueueEntriesCompanion objects for integration tests.
/// These align with MockEsiClient test data for consistency.
class SkillFixtures {
  // =========================================================================
  // Active Skill Queue Fixtures
  // =========================================================================

  /// Currently training skill - Mechanics V.
  ///
  /// Position: 0 (actively training)
  /// Skill: Mechanics (3301)
  /// Level: V
  /// Time: Started 2h ago, finishes in 6h
  static SkillQueueEntriesCompanion skillMechanicsV({
    required int characterId,
  }) {
    return SkillQueueEntriesCompanion.insert(
      characterId: characterId,
      queuePosition: 0,
      skillId: 3301, // Mechanics
      finishedLevel: 5,
      startDate: Value(DateTime.now().subtract(const Duration(hours: 2))),
      finishDate: Value(DateTime.now().add(const Duration(hours: 6))),
      trainingStartSp: const Value(226275),
      levelEndSp: const Value(256000),
      levelStartSp: const Value(181020),
    );
  }

  /// Queued skill - Engineering IV.
  ///
  /// Position: 1 (next in queue)
  /// Skill: Engineering (3392)
  /// Level: IV
  /// Time: Starts in 6h, finishes in ~1d
  static SkillQueueEntriesCompanion skillEngineeringIV({
    required int characterId,
  }) {
    return SkillQueueEntriesCompanion.insert(
      characterId: characterId,
      queuePosition: 1,
      skillId: 3392, // Engineering
      finishedLevel: 4,
      startDate: Value(DateTime.now().add(const Duration(hours: 6))),
      finishDate: Value(DateTime.now().add(const Duration(days: 1, hours: 2))),
      trainingStartSp: const Value(22627),
      levelEndSp: const Value(45255),
      levelStartSp: const Value(5657),
    );
  }

  /// Queued skill - Spaceship Command V.
  ///
  /// Position: 2 (third in queue)
  /// Skill: Spaceship Command (3327)
  /// Level: V
  /// Time: Starts in ~1d, finishes in ~3.5d
  static SkillQueueEntriesCompanion skillSpaceshipCommandV({
    required int characterId,
  }) {
    return SkillQueueEntriesCompanion.insert(
      characterId: characterId,
      queuePosition: 2,
      skillId: 3327, // Spaceship Command
      finishedLevel: 5,
      startDate: Value(DateTime.now().add(const Duration(days: 1, hours: 2))),
      finishDate: Value(DateTime.now().add(const Duration(days: 3, hours: 12))),
      trainingStartSp: const Value(0),
      levelEndSp: const Value(256000),
      levelStartSp: const Value(0),
    );
  }

  /// Get full active skill queue (3 skills).
  static List<SkillQueueEntriesCompanion> activeQueue({
    required int characterId,
  }) {
    return [
      skillMechanicsV(characterId: characterId),
      skillEngineeringIV(characterId: characterId),
      skillSpaceshipCommandV(characterId: characterId),
    ];
  }

  // =========================================================================
  // Empty Queue Fixture
  // =========================================================================

  /// Empty skill queue (no training).
  static List<SkillQueueEntriesCompanion> emptyQueue() {
    return [];
  }

  // =========================================================================
  // Helper Methods
  // =========================================================================

  /// Create a custom skill queue entry.
  static SkillQueueEntriesCompanion customSkill({
    required int characterId,
    required int queuePosition,
    required int skillId,
    required int finishedLevel,
    DateTime? startDate,
    DateTime? finishDate,
    int? trainingStartSp,
    int? levelEndSp,
    int? levelStartSp,
  }) {
    return SkillQueueEntriesCompanion.insert(
      characterId: characterId,
      queuePosition: queuePosition,
      skillId: skillId,
      finishedLevel: finishedLevel,
      startDate: Value(startDate),
      finishDate: Value(finishDate),
      trainingStartSp: Value(trainingStartSp),
      levelEndSp: Value(levelEndSp),
      levelStartSp: Value(levelStartSp),
    );
  }

  /// Create a single-skill queue (for simple tests).
  static List<SkillQueueEntriesCompanion> singleSkillQueue({
    required int characterId,
    required int skillId,
    int finishedLevel = 5,
  }) {
    return [
      SkillQueueEntriesCompanion.insert(
        characterId: characterId,
        queuePosition: 0,
        skillId: skillId,
        finishedLevel: finishedLevel,
        startDate: Value(DateTime.now().subtract(const Duration(hours: 1))),
        finishDate: Value(DateTime.now().add(const Duration(hours: 12))),
        trainingStartSp: const Value(0),
        levelEndSp: const Value(256000),
        levelStartSp: const Value(0),
      ),
    ];
  }
}
