import '../../../core/logging/logger.dart';
import '../../../core/sde/sde_database.dart';
import '../../../core/sde/sde_service.dart';
import '../data/skill_repository.dart';

/// Service for validating skill prerequisites.
///
/// Handles:
/// - Checking if a character meets prerequisites for a skill
/// - Recursively finding all unmet prerequisites
/// - Determining if prerequisites should be auto-added to a plan
class SkillPrerequisiteService {
  SkillPrerequisiteService({
    required this.sdeService,
    required this.skillRepository,
  });

  final SdeService sdeService;
  final SkillRepository skillRepository;

  /// Checks if a character meets all prerequisites for a skill at a given level.
  ///
  /// Returns true if the character can train the skill to the target level,
  /// false if prerequisites are missing.
  Future<bool> canTrainSkill({
    required int characterId,
    required int skillId,
    required int targetLevel,
  }) async {
    Log.d(
      'SKILLS.PREREQ',
      'canTrainSkill - characterId: $characterId, skillId: $skillId, level: $targetLevel',
    );

    final unmet = await getUnmetPrerequisites(
      characterId: characterId,
      skillId: skillId,
      targetLevel: targetLevel,
    );

    final canTrain = unmet.isEmpty;
    Log.i(
      'SKILLS.PREREQ',
      'canTrainSkill - skillId: $skillId → ${canTrain ? 'CAN TRAIN' : 'MISSING ${unmet.length} PREREQS'}',
    );

    return canTrain;
  }

  /// Gets all unmet prerequisites for a skill at a given target level.
  ///
  /// Returns a list of prerequisite requirements that the character
  /// does not currently meet. Each requirement specifies the skill
  /// and level needed.
  Future<List<PrerequisiteRequirement>> getUnmetPrerequisites({
    required int characterId,
    required int skillId,
    required int targetLevel,
  }) async {
    Log.d(
      'SKILLS.PREREQ',
      'getUnmetPrerequisites - characterId: $characterId, skillId: $skillId, level: $targetLevel',
    );

    // Get prerequisites from SDE
    final prerequisites = await sdeService.getSkillPrerequisites(skillId);
    Log.d('SKILLS.PREREQ', 'getUnmetPrerequisites - found ${prerequisites.length} prerequisites');

    if (prerequisites.isEmpty) {
      return [];
    }

    final unmet = <PrerequisiteRequirement>[];

    for (final prereq in prerequisites) {
      final trainedLevel = await skillRepository.getTrainedLevel(
        characterId,
        prereq.requiredSkillId,
      );

      if (trainedLevel < prereq.requiredLevel) {
        final skillName = await sdeService.getSkillName(prereq.requiredSkillId);
        unmet.add(
          PrerequisiteRequirement(
            skillId: prereq.requiredSkillId,
            skillName: skillName ?? 'Skill #${prereq.requiredSkillId}',
            requiredLevel: prereq.requiredLevel,
            trainedLevel: trainedLevel,
          ),
        );

        Log.d(
          'SKILLS.PREREQ',
          'getUnmetPrerequisites - UNMET: ${skillName ?? prereq.requiredSkillId} '
          '(need level ${prereq.requiredLevel}, have $trainedLevel)',
        );
      }
    }

    Log.i('SKILLS.PREREQ', 'getUnmetPrerequisites - found ${unmet.length} unmet prerequisites');
    return unmet;
  }

  /// Gets all prerequisites (including nested) needed for a skill.
  ///
  /// This recursively traverses the prerequisite tree to find all
  /// skills that must be trained before the target skill can be trained.
  ///
  /// Returns a flattened list of all prerequisites with their required levels.
  /// The list is ordered such that dependencies come before dependents.
  Future<List<PrerequisiteChain>> getAllPrerequisites({
    required int characterId,
    required int skillId,
    required int targetLevel,
  }) async {
    Log.d(
      'SKILLS.PREREQ',
      'getAllPrerequisites - characterId: $characterId, skillId: $skillId, level: $targetLevel',
    );

    final visited = <int>{};
    final result = <PrerequisiteChain>[];

    await _collectPrerequisitesRecursive(
      characterId: characterId,
      skillId: skillId,
      targetLevel: targetLevel,
      visited: visited,
      result: result,
      depth: 0,
    );

    Log.i('SKILLS.PREREQ', 'getAllPrerequisites - found ${result.length} total prerequisites');
    return result;
  }

  /// Recursively collects prerequisites, avoiding cycles.
  Future<void> _collectPrerequisitesRecursive({
    required int characterId,
    required int skillId,
    required int targetLevel,
    required Set<int> visited,
    required List<PrerequisiteChain> result,
    required int depth,
  }) async {
    // Prevent infinite loops (though EVE shouldn't have circular deps)
    if (visited.contains(skillId)) {
      Log.w('SKILLS.PREREQ', '_collectPrerequisitesRecursive - circular dependency detected for skill $skillId');
      return;
    }

    visited.add(skillId);

    // Get direct prerequisites
    final prerequisites = await sdeService.getSkillPrerequisites(skillId);

    for (final prereq in prerequisites) {
      final trainedLevel = await skillRepository.getTrainedLevel(
        characterId,
        prereq.requiredSkillId,
      );

      // Recursively collect prerequisites of this prerequisite
      await _collectPrerequisitesRecursive(
        characterId: characterId,
        skillId: prereq.requiredSkillId,
        targetLevel: prereq.requiredLevel,
        visited: visited,
        result: result,
        depth: depth + 1,
      );

      // Add this prerequisite if not already trained
      if (trainedLevel < prereq.requiredLevel) {
        final skillName = await sdeService.getSkillName(prereq.requiredSkillId);
        result.add(
          PrerequisiteChain(
            skillId: prereq.requiredSkillId,
            skillName: skillName ?? 'Skill #${prereq.requiredSkillId}',
            requiredLevel: prereq.requiredLevel,
            trainedLevel: trainedLevel,
            depth: depth,
            forSkillId: skillId,
          ),
        );
      }
    }
  }

  /// Filters a list of prerequisites to only those not already in a plan.
  ///
  /// Useful for determining which prerequisites need to be added when
  /// auto-adding prerequisites to a plan.
  Future<List<PrerequisiteRequirement>> filterPrerequisitesNotInPlan({
    required List<PrerequisiteRequirement> prerequisites,
    required List<int> planSkillIds,
  }) async {
    return prerequisites
        .where((prereq) => !planSkillIds.contains(prereq.skillId))
        .toList();
  }
}

/// A prerequisite requirement that is not met.
class PrerequisiteRequirement {
  const PrerequisiteRequirement({
    required this.skillId,
    required this.skillName,
    required this.requiredLevel,
    required this.trainedLevel,
  });

  final int skillId;
  final String skillName;
  final int requiredLevel;
  final int trainedLevel;

  /// Human-readable description of the requirement.
  String get description {
    return '$skillName (need level $requiredLevel, have $trainedLevel)';
  }

  /// Whether this prerequisite is completely untrained.
  bool get isUntrained => trainedLevel == 0;
}

/// A prerequisite in a dependency chain.
///
/// Includes depth information for displaying the prerequisite tree.
class PrerequisiteChain {
  const PrerequisiteChain({
    required this.skillId,
    required this.skillName,
    required this.requiredLevel,
    required this.trainedLevel,
    required this.depth,
    required this.forSkillId,
  });

  final int skillId;
  final String skillName;
  final int requiredLevel;
  final int trainedLevel;
  final int depth; // 0 = direct prerequisite, 1 = prerequisite of prerequisite, etc.
  final int forSkillId; // Which skill requires this prerequisite

  /// Human-readable description of the requirement.
  String get description {
    return '$skillName (need level $requiredLevel, have $trainedLevel)';
  }

  /// Whether this prerequisite is completely untrained.
  bool get isUntrained => trainedLevel == 0;
}
