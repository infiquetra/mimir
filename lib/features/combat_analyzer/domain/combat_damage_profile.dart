enum CombatDamageConfidence { observed, sdeExact, modelInferred, unknown }

class CombatDamageTypeEstimate {
  const CombatDamageTypeEstimate({
    required this.type,
    required this.amount,
    required this.percent,
    required this.confidence,
    required this.source,
    required this.evidence,
  });

  final String type;
  final int amount;
  final double percent;
  final CombatDamageConfidence confidence;
  final String source;
  final String evidence;

  String get confidenceLabel => switch (confidence) {
    CombatDamageConfidence.observed => 'Observed',
    CombatDamageConfidence.sdeExact => 'SDE exact',
    CombatDamageConfidence.modelInferred => 'Model inferred',
    CombatDamageConfidence.unknown => 'Unknown',
  };
}

class CombatDamageProfile {
  const CombatDamageProfile({
    required this.entries,
    required this.unknownWeapons,
    required this.totalProfiledDamage,
  });

  final List<CombatDamageTypeEstimate> entries;
  final List<String> unknownWeapons;
  final int totalProfiledDamage;

  bool get hasKnownDamageTypes => entries.isNotEmpty;
}
