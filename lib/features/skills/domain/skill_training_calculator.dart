import '../../../core/logging/logger.dart';

/// Calculator for skill training time estimates.
///
/// Uses EVE Online's skill training formula:
/// - Training rate = Primary attribute + (Secondary attribute / 2)
/// - SP per minute = Training rate
/// - Time to train = SP needed / Training rate
///
/// Each skill level requires: 250 × rank × 2^(level - 1) SP
class SkillTrainingCalculator {
  /// Calculate SP required to train a skill from one level to another.
  ///
  /// Formula: 250 × rank × 2^(level - 1) for each level
  ///
  /// Example:
  /// - Gunnery (rank 1) from 0→5: 250×1×(1+2+4+8+16) = 7,750 SP
  /// - Caldari Frigate (rank 1) from 3→4: 250×1×8 = 2,000 SP
  int calculateSpRequired({
    required int skillRank,
    required int fromLevel,
    required int toLevel,
  }) {
    if (fromLevel < 0 || fromLevel > 5 || toLevel < 0 || toLevel > 5) {
      throw ArgumentError('Skill levels must be 0-5');
    }
    if (fromLevel >= toLevel) {
      return 0; // Already trained or invalid
    }

    int totalSp = 0;
    for (int level = fromLevel + 1; level <= toLevel; level++) {
      // Each level: 250 × rank × 2^(level - 1)
      final spForLevel = 250 * skillRank * (1 << (level - 1));
      totalSp += spForLevel;
    }

    Log.d('SKILLS', 'calculateSpRequired - rank $skillRank, $fromLevel→$toLevel: $totalSp SP');
    return totalSp;
  }

  /// Calculate training time for a given amount of SP.
  ///
  /// Uses character attributes to determine training rate.
  /// If attributes not provided, uses defaults (20/20).
  ///
  /// Training rate = Primary + (Secondary / 2)
  /// Time = SP needed / (Training rate SP/min)
  Duration calculateTrainingTime({
    required int spRequired,
    int primaryAttribute = 20,
    int secondaryAttribute = 20,
  }) {
    if (spRequired <= 0) {
      return Duration.zero;
    }

    // Training rate in SP per minute
    final trainingRate = primaryAttribute + (secondaryAttribute / 2);
    final minutes = spRequired / trainingRate;

    Log.d('SKILLS',
        'calculateTrainingTime - $spRequired SP, rate $trainingRate SP/min: ${minutes.toInt()} min');

    return Duration(minutes: minutes.ceil());
  }

  /// Calculate time to train a skill from one level to another.
  ///
  /// Combines SP calculation and time calculation.
  Duration calculateSkillTrainingTime({
    required int skillRank,
    required int fromLevel,
    required int toLevel,
    int primaryAttribute = 20,
    int secondaryAttribute = 20,
  }) {
    final spRequired = calculateSpRequired(
      skillRank: skillRank,
      fromLevel: fromLevel,
      toLevel: toLevel,
    );

    return calculateTrainingTime(
      spRequired: spRequired,
      primaryAttribute: primaryAttribute,
      secondaryAttribute: secondaryAttribute,
    );
  }

  /// Calculate total training time for a list of skills.
  ///
  /// Used for skill plan progress estimates.
  /// Assumes all skills train sequentially with the same attributes.
  Duration calculateTotalTrainingTime({
    required List<SkillTrainingEntry> skills,
    int primaryAttribute = 20,
    int secondaryAttribute = 20,
  }) {
    int totalSp = 0;

    for (final skill in skills) {
      final spForSkill = calculateSpRequired(
        skillRank: skill.skillRank,
        fromLevel: skill.fromLevel,
        toLevel: skill.toLevel,
      );
      totalSp += spForSkill;
    }

    Log.i('SKILLS',
        'calculateTotalTrainingTime - ${skills.length} skills, $totalSp total SP');

    return calculateTrainingTime(
      spRequired: totalSp,
      primaryAttribute: primaryAttribute,
      secondaryAttribute: secondaryAttribute,
    );
  }
}

/// Represents a skill entry for training time calculation.
class SkillTrainingEntry {
  final int skillId;
  final int skillRank;
  final int fromLevel;
  final int toLevel;

  const SkillTrainingEntry({
    required this.skillId,
    required this.skillRank,
    required this.fromLevel,
    required this.toLevel,
  });
}
