import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import '../../../core/sde/sde_service.dart';

/// Calculator for skill training time estimates.
///
/// Uses EVE Online's skill training formula:
/// - Training rate = Primary attribute + (Secondary attribute / 2)
/// - SP per minute = Training rate
/// - Time to train = SP needed / Training rate
///
/// Each skill level requires: 250 × rank × 2^(level - 1) SP
class SkillTrainingCalculator {
  final SdeService _sdeService;

  SkillTrainingCalculator({
    required SdeService sdeService,
  }) : _sdeService = sdeService;
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

  /// Calculate SP required to train a skill using SDE data.
  ///
  /// Fetches skill rank from SDE and calculates SP required.
  Future<int> calculateSpRequiredFromSde({
    required int skillId,
    required int fromLevel,
    required int toLevel,
  }) async {
    Log.d('SKILLS', 'calculateSpRequiredFromSde - skillId: $skillId, $fromLevel→$toLevel');

    final skillRank = await _sdeService.getSkillRank(skillId);
    if (skillRank == null) {
      Log.w('SKILLS', 'calculateSpRequiredFromSde - skill $skillId has no rank in SDE, using rank 1');
      return calculateSpRequired(
        skillRank: 1,
        fromLevel: fromLevel,
        toLevel: toLevel,
      );
    }

    return calculateSpRequired(
      skillRank: skillRank,
      fromLevel: fromLevel,
      toLevel: toLevel,
    );
  }

  /// Calculate training time using character attributes from ESI.
  ///
  /// Uses the skill's primary/secondary attributes from SDE
  /// and the character's attribute values from ESI.
  Future<Duration> calculateTrainingTimeFromSde({
    required int skillId,
    required int spRequired,
    required CharacterAttributes characterAttributes,
  }) async {
    Log.d('SKILLS', 'calculateTrainingTimeFromSde - skillId: $skillId, SP: $spRequired');

    if (spRequired <= 0) {
      return Duration.zero;
    }

    final attributes = await _sdeService.getSkillAttributes(skillId);
    if (attributes == null || attributes.primary == null || attributes.secondary == null) {
      Log.w('SKILLS', 'calculateTrainingTimeFromSde - skill $skillId has no attributes in SDE');
      // Fallback to default 20/20
      return calculateTrainingTime(
        spRequired: spRequired,
        primaryAttribute: 20,
        secondaryAttribute: 20,
      );
    }

    // Get actual attribute values from character
    final primaryValue = _getAttributeValue(
      attributes.primary!,
      characterAttributes,
    );
    final secondaryValue = _getAttributeValue(
      attributes.secondary!,
      characterAttributes,
    );

    Log.d('SKILLS',
        'calculateTrainingTimeFromSde - using attributes: primary=${attributes.primary}($primaryValue), secondary=${attributes.secondary}($secondaryValue)');

    return calculateTrainingTime(
      spRequired: spRequired,
      primaryAttribute: primaryValue,
      secondaryAttribute: secondaryValue,
    );
  }

  /// Calculate complete skill training time using SDE and character attributes.
  ///
  /// This is the main method for calculating accurate training times.
  Future<Duration> calculateSkillTrainingTimeFromSde({
    required int skillId,
    required int fromLevel,
    required int toLevel,
    required CharacterAttributes characterAttributes,
  }) async {
    Log.d('SKILLS', 'calculateSkillTrainingTimeFromSde - skillId: $skillId, $fromLevel→$toLevel');

    final spRequired = await calculateSpRequiredFromSde(
      skillId: skillId,
      fromLevel: fromLevel,
      toLevel: toLevel,
    );

    return calculateTrainingTimeFromSde(
      skillId: skillId,
      spRequired: spRequired,
      characterAttributes: characterAttributes,
    );
  }

  /// Get the numeric value for a character's attribute.
  ///
  /// Maps attribute names from SDE (e.g., "perception") to character attribute values.
  int _getAttributeValue(String attributeName, CharacterAttributes attributes) {
    switch (attributeName.toLowerCase()) {
      case 'charisma':
        return attributes.charisma;
      case 'intelligence':
        return attributes.intelligence;
      case 'memory':
        return attributes.memory;
      case 'perception':
        return attributes.perception;
      case 'willpower':
        return attributes.willpower;
      default:
        Log.w('SKILLS', '_getAttributeValue - unknown attribute: $attributeName, defaulting to 20');
        return 20;
    }
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
