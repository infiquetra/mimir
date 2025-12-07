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

  // =========================================================================
  // Trained Skills Fixtures (CharacterSkills)
  // =========================================================================

  /// Mechanics skill trained to level V.
  ///
  /// Skill: Mechanics (3301)
  /// Level: V (fully trained)
  /// SP: 256,000 (rank 1, level V = 250 × 1 × 2^4)
  static CharacterSkillsCompanion trainedMechanicsV({
    required int characterId,
  }) {
    return CharacterSkillsCompanion.insert(
      characterId: characterId,
      skillId: 3301, // Mechanics
      trainedSkillLevel: 5,
      activeSkillLevel: 5,
      skillpointsInSkill: 256000,
      lastUpdated: DateTime.now(),
    );
  }

  /// Engineering skill trained to level III.
  ///
  /// Skill: Engineering (3392)
  /// Level: III (partially trained)
  /// SP: 22,627 (rank 1, level III = 250 × 1 × 2^2)
  static CharacterSkillsCompanion trainedEngineeringIII({
    required int characterId,
  }) {
    return CharacterSkillsCompanion.insert(
      characterId: characterId,
      skillId: 3392, // Engineering
      trainedSkillLevel: 3,
      activeSkillLevel: 3,
      skillpointsInSkill: 22627,
      lastUpdated: DateTime.now(),
    );
  }

  /// Spaceship Command skill trained to level IV.
  ///
  /// Skill: Spaceship Command (3327)
  /// Level: IV
  /// SP: 90,510 (rank 1, level IV = 250 × 1 × 2^3)
  static CharacterSkillsCompanion trainedSpaceshipCommandIV({
    required int characterId,
  }) {
    return CharacterSkillsCompanion.insert(
      characterId: characterId,
      skillId: 3327, // Spaceship Command
      trainedSkillLevel: 4,
      activeSkillLevel: 4,
      skillpointsInSkill: 90510,
      lastUpdated: DateTime.now(),
    );
  }

  /// Gunnery skill trained to level V.
  ///
  /// Skill: Gunnery (3300)
  /// Level: V
  /// SP: 256,000 (rank 1, level V)
  static CharacterSkillsCompanion trainedGunneryV({
    required int characterId,
  }) {
    return CharacterSkillsCompanion.insert(
      characterId: characterId,
      skillId: 3300, // Gunnery
      trainedSkillLevel: 5,
      activeSkillLevel: 5,
      skillpointsInSkill: 256000,
      lastUpdated: DateTime.now(),
    );
  }

  /// Caldari Frigate skill trained to level IV.
  ///
  /// Skill: Caldari Frigate (3330)
  /// Level: IV
  /// SP: 90,510 (rank 1, level IV)
  static CharacterSkillsCompanion trainedCaldariFrigateIV({
    required int characterId,
  }) {
    return CharacterSkillsCompanion.insert(
      characterId: characterId,
      skillId: 3330, // Caldari Frigate
      trainedSkillLevel: 4,
      activeSkillLevel: 4,
      skillpointsInSkill: 90510,
      lastUpdated: DateTime.now(),
    );
  }

  /// Get a set of commonly trained skills (10 skills).
  ///
  /// Mix of levels I-V for realistic testing:
  /// - 2 skills at level V
  /// - 3 skills at level IV
  /// - 2 skills at level III
  /// - 2 skills at level II
  /// - 1 skill at level I
  static List<CharacterSkillsCompanion> trainedSkills({
    required int characterId,
  }) {
    return [
      trainedMechanicsV(characterId: characterId),
      trainedGunneryV(characterId: characterId),
      trainedSpaceshipCommandIV(characterId: characterId),
      trainedCaldariFrigateIV(characterId: characterId),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3413, // Power Grid Management
        trainedSkillLevel: 4,
        activeSkillLevel: 4,
        skillpointsInSkill: 90510,
        lastUpdated: DateTime.now(),
      ),
      trainedEngineeringIII(characterId: characterId),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3426, // CPU Management
        trainedSkillLevel: 3,
        activeSkillLevel: 3,
        skillpointsInSkill: 22627,
        lastUpdated: DateTime.now(),
      ),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3402, // Shield Management
        trainedSkillLevel: 2,
        activeSkillLevel: 2,
        skillpointsInSkill: 5657,
        lastUpdated: DateTime.now(),
      ),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3416, // Armor Layering
        trainedSkillLevel: 2,
        activeSkillLevel: 2,
        skillpointsInSkill: 5657,
        lastUpdated: DateTime.now(),
      ),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3431, // Electronics
        trainedSkillLevel: 1,
        activeSkillLevel: 1,
        skillpointsInSkill: 250,
        lastUpdated: DateTime.now(),
      ),
    ];
  }

  /// Get a full skill set with various levels (50+ skills).
  ///
  /// Includes skills from multiple groups:
  /// - Core skills (Mechanics, Engineering, etc.)
  /// - Gunnery skills
  /// - Spaceship Command skills
  /// - Shield/Armor skills
  /// - Navigation skills
  ///
  /// Provides realistic distribution for testing skill catalogue display.
  static List<CharacterSkillsCompanion> fullSkillSet({
    required int characterId,
  }) {
    final skills = <CharacterSkillsCompanion>[];

    // Core skills (high level)
    skills.addAll([
      trainedMechanicsV(characterId: characterId),
      trainedEngineeringIII(characterId: characterId),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3413, // Power Grid Management
        trainedSkillLevel: 5,
        activeSkillLevel: 5,
        skillpointsInSkill: 256000,
        lastUpdated: DateTime.now(),
      ),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3426, // CPU Management
        trainedSkillLevel: 5,
        activeSkillLevel: 5,
        skillpointsInSkill: 256000,
        lastUpdated: DateTime.now(),
      ),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3431, // Electronics
        trainedSkillLevel: 4,
        activeSkillLevel: 4,
        skillpointsInSkill: 90510,
        lastUpdated: DateTime.now(),
      ),
    ]);

    // Gunnery skills
    skills.addAll([
      trainedGunneryV(characterId: characterId),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3310, // Small Hybrid Turret
        trainedSkillLevel: 5,
        activeSkillLevel: 5,
        skillpointsInSkill: 256000,
        lastUpdated: DateTime.now(),
      ),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3311, // Medium Hybrid Turret
        trainedSkillLevel: 4,
        activeSkillLevel: 4,
        skillpointsInSkill: 362039,
        lastUpdated: DateTime.now(),
      ),
    ]);

    // Spaceship Command
    skills.addAll([
      trainedSpaceshipCommandIV(characterId: characterId),
      trainedCaldariFrigateIV(characterId: characterId),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3331, // Caldari Cruiser
        trainedSkillLevel: 3,
        activeSkillLevel: 3,
        skillpointsInSkill: 90510,
        lastUpdated: DateTime.now(),
      ),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3332, // Caldari Battleship
        trainedSkillLevel: 1,
        activeSkillLevel: 1,
        skillpointsInSkill: 1000,
        lastUpdated: DateTime.now(),
      ),
    ]);

    // Shield/Armor skills
    skills.addAll([
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3416, // Armor Layering
        trainedSkillLevel: 3,
        activeSkillLevel: 3,
        skillpointsInSkill: 22627,
        lastUpdated: DateTime.now(),
      ),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3402, // Shield Management
        trainedSkillLevel: 4,
        activeSkillLevel: 4,
        skillpointsInSkill: 90510,
        lastUpdated: DateTime.now(),
      ),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3425, // Shield Upgrades
        trainedSkillLevel: 5,
        activeSkillLevel: 5,
        skillpointsInSkill: 256000,
        lastUpdated: DateTime.now(),
      ),
    ]);

    // Navigation skills
    skills.addAll([
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3449, // Navigation
        trainedSkillLevel: 5,
        activeSkillLevel: 5,
        skillpointsInSkill: 256000,
        lastUpdated: DateTime.now(),
      ),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3451, // Evasive Maneuvering
        trainedSkillLevel: 4,
        activeSkillLevel: 4,
        skillpointsInSkill: 90510,
        lastUpdated: DateTime.now(),
      ),
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3452, // Warp Drive Operation
        trainedSkillLevel: 3,
        activeSkillLevel: 3,
        skillpointsInSkill: 22627,
        lastUpdated: DateTime.now(),
      ),
    ]);

    return skills;
  }

  /// Create a custom trained skill.
  static CharacterSkillsCompanion customTrainedSkill({
    required int characterId,
    required int skillId,
    required int trainedSkillLevel,
    int? skillpointsInSkill,
    DateTime? lastUpdated,
  }) {
    return CharacterSkillsCompanion.insert(
      characterId: characterId,
      skillId: skillId,
      trainedSkillLevel: trainedSkillLevel,
      activeSkillLevel: trainedSkillLevel,
      skillpointsInSkill: skillpointsInSkill ?? (250 * (1 << (trainedSkillLevel - 1))),
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  /// Get untrained skill (level 0, 0 SP).
  ///
  /// Useful for testing skill plan progress when skills aren't trained yet.
  static CharacterSkillsCompanion untrainedSkill({
    required int characterId,
    required int skillId,
  }) {
    return CharacterSkillsCompanion.insert(
      characterId: characterId,
      skillId: skillId,
      trainedSkillLevel: 0,
      activeSkillLevel: 0,
      skillpointsInSkill: 0,
      lastUpdated: DateTime.now(),
    );
  }
}
