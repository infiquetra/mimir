/// Calculates reaction yields and requirements.
class ReactionCalculator {
  /// Calculates the required input materials for a reaction job.
  /// 
  /// [baseInputs] - Map of typeId to base quantity required per run.
  /// [runs] - Number of runs for the job.
  /// [facilityMaterialBonus] - Material efficiency bonus of the structure (e.g., 0.02 for a 2% reduction).
  static Map<int, int> calculateInputs(
    Map<int, int> baseInputs,
    int runs, {
    double facilityMaterialBonus = 0.0,
  }) {
    final inputs = <int, int>{};
    for (final entry in baseInputs.entries) {
      final typeId = entry.key;
      final baseQty = entry.value;

      // In EVE, reactions don't have ME/TE researched on the blueprint itself,
      // but the facility (Tatara/Athanor) and its rigs can provide a material bonus.
      // EVE's math for ME reduction applies to the total base amount.
      // round(runs * baseQty * (1.0 - facilityMaterialBonus))
      final totalBaseQty = runs * baseQty;
      final actualQty = (totalBaseQty * (1.0 - facilityMaterialBonus)).round();

      // You can never use less than 1 if it requires it, unless mathematically it rounds down to 0, 
      // but in Eve it usually has a minimum of 1 per run or rounds appropriately.
      inputs[typeId] = actualQty > 0 ? actualQty : 1;
    }
    return inputs;
  }

  /// Calculates the output products for a reaction job.
  static Map<int, int> calculateOutputs(
    Map<int, int> baseOutputs,
    int runs,
  ) {
    final outputs = <int, int>{};
    for (final entry in baseOutputs.entries) {
      outputs[entry.key] = entry.value * runs;
    }
    return outputs;
  }
}
