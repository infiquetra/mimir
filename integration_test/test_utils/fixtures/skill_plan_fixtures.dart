import 'package:drift/drift.dart';
import 'package:mimir/core/database/app_database.dart';

/// Test fixtures for skill plan data.
///
/// Provides pre-built SkillPlansCompanion and SkillPlanEntriesCompanion
/// objects for integration tests. These work with SkillFixtures for
/// complete test coverage.
class SkillPlanFixtures {
  // =========================================================================
  // Skill Plan Fixtures
  // =========================================================================

  /// PvP Frigate plan (10 skills).
  ///
  /// Plan name: "PvP Frigate Skills"
  /// Description: "T2 frigate PvP training"
  /// Target: Caldari frigate PvP skills
  static SkillPlansCompanion pvpFrigatePlan({
    required int characterId,
  }) {
    return SkillPlansCompanion.insert(
      characterId: characterId,
      name: 'PvP Frigate Skills',
      description: const Value('T2 frigate PvP training'),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Industry skills plan (8 skills).
  ///
  /// Plan name: "Manufacturing Basics"
  /// Description: "Basic industry and manufacturing"
  /// Target: Industry and production skills
  static SkillPlansCompanion industryPlan({
    required int characterId,
  }) {
    return SkillPlansCompanion.insert(
      characterId: characterId,
      name: 'Manufacturing Basics',
      description: const Value('Basic industry and manufacturing'),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Empty plan (no description, no skills).
  ///
  /// Plan name: "Empty Plan"
  /// Useful for testing plan creation and skill addition flows.
  static SkillPlansCompanion emptyPlan({
    required int characterId,
  }) {
    return SkillPlansCompanion.insert(
      characterId: characterId,
      name: 'Empty Plan',
      description: const Value.absent(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Completed plan (all skills trained to target level).
  ///
  /// Plan name: "Basic Training"
  /// Description: "Core skills complete"
  /// All skills in this plan should be already trained.
  static SkillPlansCompanion completedPlan({
    required int characterId,
  }) {
    return SkillPlansCompanion.insert(
      characterId: characterId,
      name: 'Basic Training',
      description: const Value('Core skills complete'),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // =========================================================================
  // Skill Plan Entry Fixtures
  // =========================================================================

  /// Get entries for PvP Frigate plan (10 skills).
  ///
  /// Skills:
  /// 1. Caldari Frigate V
  /// 2. Small Hybrid Turret V
  /// 3. Gunnery V
  /// 4. Motion Prediction IV
  /// 5. Rapid Firing IV
  /// 6. Sharpshooter IV
  /// 7. Trajectory Analysis III
  /// 8. Evasive Maneuvering V
  /// 9. Navigation V
  /// 10. Warp Drive Operation IV
  static List<SkillPlanEntriesCompanion> pvpFrigateEntries({
    required int planId,
  }) {
    return [
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3330, // Caldari Frigate
        targetLevel: 5,
        sortOrder: 0,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3310, // Small Hybrid Turret
        targetLevel: 5,
        sortOrder: 1,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3300, // Gunnery
        targetLevel: 5,
        sortOrder: 2,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3320, // Motion Prediction
        targetLevel: 4,
        sortOrder: 3,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3312, // Rapid Firing
        targetLevel: 4,
        sortOrder: 4,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3315, // Sharpshooter
        targetLevel: 4,
        sortOrder: 5,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3321, // Trajectory Analysis
        targetLevel: 3,
        sortOrder: 6,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3451, // Evasive Maneuvering
        targetLevel: 5,
        sortOrder: 7,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3449, // Navigation
        targetLevel: 5,
        sortOrder: 8,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3452, // Warp Drive Operation
        targetLevel: 4,
        sortOrder: 9,
      ),
    ];
  }

  /// Get entries for Industry plan (8 skills).
  ///
  /// Skills:
  /// 1. Industry V
  /// 2. Mass Production IV
  /// 3. Advanced Industry IV
  /// 4. Production Efficiency V
  /// 5. Material Efficiency V
  /// 6. Science V
  /// 7. Research IV
  /// 8. Metallurgy III
  static List<SkillPlanEntriesCompanion> industryEntries({
    required int planId,
  }) {
    return [
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3380, // Industry
        targetLevel: 5,
        sortOrder: 0,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3387, // Mass Production
        targetLevel: 4,
        sortOrder: 1,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3388, // Advanced Industry
        targetLevel: 4,
        sortOrder: 2,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3394, // Production Efficiency
        targetLevel: 5,
        sortOrder: 3,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3395, // Material Efficiency
        targetLevel: 5,
        sortOrder: 4,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3403, // Science
        targetLevel: 5,
        sortOrder: 5,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3406, // Research
        targetLevel: 4,
        sortOrder: 6,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3409, // Metallurgy
        targetLevel: 3,
        sortOrder: 7,
      ),
    ];
  }

  /// Get entries for completed plan (5 skills, all should be trained).
  ///
  /// Skills:
  /// 1. Mechanics V (trained)
  /// 2. Gunnery V (trained)
  /// 3. Spaceship Command IV (trained)
  /// 4. Caldari Frigate IV (trained)
  /// 5. Engineering III (trained)
  static List<SkillPlanEntriesCompanion> completedEntries({
    required int planId,
  }) {
    return [
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3301, // Mechanics
        targetLevel: 5,
        sortOrder: 0,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3300, // Gunnery
        targetLevel: 5,
        sortOrder: 1,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3327, // Spaceship Command
        targetLevel: 4,
        sortOrder: 2,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3330, // Caldari Frigate
        targetLevel: 4,
        sortOrder: 3,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3392, // Engineering
        targetLevel: 3,
        sortOrder: 4,
      ),
    ];
  }

  /// Get entries for partially trained plan (5 skills, 2 trained, 3 not).
  ///
  /// Skills:
  /// 1. Mechanics V (trained ✓)
  /// 2. Gunnery V (trained ✓)
  /// 3. Small Hybrid Turret V (not trained ✗)
  /// 4. Medium Hybrid Turret IV (not trained ✗)
  /// 5. Motion Prediction IV (not trained ✗)
  static List<SkillPlanEntriesCompanion> partiallyTrainedEntries({
    required int planId,
  }) {
    return [
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3301, // Mechanics (trained)
        targetLevel: 5,
        sortOrder: 0,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3300, // Gunnery (trained)
        targetLevel: 5,
        sortOrder: 1,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3310, // Small Hybrid Turret (not trained)
        targetLevel: 5,
        sortOrder: 2,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3311, // Medium Hybrid Turret (not trained)
        targetLevel: 4,
        sortOrder: 3,
      ),
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: 3320, // Motion Prediction (not trained)
        targetLevel: 4,
        sortOrder: 4,
      ),
    ];
  }

  // =========================================================================
  // Helper Methods
  // =========================================================================

  /// Create a custom skill plan entry.
  static SkillPlanEntriesCompanion customEntry({
    required int planId,
    required int skillId,
    required int targetLevel,
    int sortOrder = 0,
  }) {
    return SkillPlanEntriesCompanion.insert(
      planId: planId,
      skillId: skillId,
      targetLevel: targetLevel,
      sortOrder: sortOrder,
    );
  }

  /// Get empty entries (for testing plan creation).
  static List<SkillPlanEntriesCompanion> noEntries() {
    return [];
  }
}
