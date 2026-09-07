/// Calculates invention probability.
class InventionCalculator {
  /// Calculates the invention probability of a blueprint.
  ///
  /// [baseProbability] - The base probability of the invention (e.g., 0.30 for ships).
  /// [encryptionSkillLevel] - Level of the encryption skill (1-5).
  /// [datacoreSkill1Level] - Level of the first datacore skill (1-5).
  /// [datacoreSkill2Level] - Level of the second datacore skill (1-5).
  /// [decryptorMultiplier] - The multiplier provided by the decryptor (e.g., 1.2 for +20%, 1.0 for none).
  static double calculateProbability({
    required double baseProbability,
    required int encryptionSkillLevel,
    required int datacoreSkill1Level,
    required int datacoreSkill2Level,
    double decryptorMultiplier = 1.0,
  }) {
    // Standard EVE Online Invention Formula
    final skillFactor =
        1.0 +
        (encryptionSkillLevel / 40.0) +
        (datacoreSkill1Level / 40.0) +
        (datacoreSkill2Level / 40.0);

    final finalChance = baseProbability * skillFactor * decryptorMultiplier;

    // Cap at 1.0 (100%)
    return finalChance > 1.0 ? 1.0 : finalChance;
  }
}
