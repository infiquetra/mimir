import 'aar_fit_derivation.dart';
import 'combat_damage_matchup.dart';
import 'combat_damage_profile.dart';
import 'combat_evidence_ledger.dart';

class AarDerivedFactsBuilder {
  /// U2 stub: Devs emit deterministic `ev-derived-<subject>-<key>-<id>` facts.
  static List<CombatEvidenceFact> facts(
    AarFitDerivation derivation, {
    required String encounterId,
    CombatDamageMatchup? matchup,
  }) {
    return const [];
  }

  /// U2 stub: Devs emit R5.4 unknowns from the bundle and incoming profile.
  static List<AarUnknown> unknownsFor(
    AarDerivationBundle bundle, {
    required bool hasPilotEvidence,
    required bool hasOpponentEvidence,
    required CombatDamageProfile incoming,
  }) {
    return const [];
  }
}
