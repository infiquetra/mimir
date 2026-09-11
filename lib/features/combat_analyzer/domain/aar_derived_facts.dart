import '../../../core/logging/logger.dart';
import '../../fitting/domain/models.dart';
import 'aar_fit_derivation.dart';
import 'combat_damage_matchup.dart';
import 'combat_damage_profile.dart';
import 'combat_evidence_ledger.dart';

class AarDerivedFactsBuilder {
  static List<CombatEvidenceFact> facts(
    AarFitDerivation derivation, {
    required String encounterId,
    CombatDamageMatchup? matchup,
  }) {
    Log.d(
      'AAR',
      'AarDerivedFactsBuilder.facts subject=${derivation.subject.name} '
          'encounter=$encounterId matchup=${matchup != null}',
    );
    final subject = derivation.subject.name;
    final stats = derivation.stats;
    final defenses = stats.defenses;
    final keys = <String, (String, String)>{
      'skills': ('Skill assumption', derivation.skills.label),
      'ehp-omni': (
        'Derived EHP (omni 25/25/25/25)',
        '${_comma(defenses.totalEhp.round())} EHP '
            '(shield ${_comma(defenses.shieldEhp.round())} / '
            'armor ${_comma(defenses.armorEhp.round())} / '
            'hull ${_comma(defenses.hullEhp.round())})',
      ),
      'resists-shield': (
        'Derived shield resists',
        _resists(defenses.shieldResists, defenses.shieldHp),
      ),
      'resists-armor': (
        'Derived armor resists',
        _resists(defenses.armorResists, defenses.armorHp),
      ),
      'resists-hull': (
        'Derived hull resists',
        _resists(defenses.hullResists, defenses.hullHp),
      ),
      'tank': ('Derived tank layer', derivation.tank.reasoning),
      'repair': (
        'Derived active repair',
        'armor ${defenses.effectiveArmorRepair.toStringAsFixed(1)} HP/s, '
            'shield ${defenses.effectiveShieldBoost.toStringAsFixed(1)} HP/s, '
            'hull ${defenses.effectiveHullRepair.toStringAsFixed(1)} HP/s; '
            'passive shield ${defenses.peakShieldRecharge.toStringAsFixed(1)} HP/s',
      ),
      'cap': ('Derived capacitor', _cap(stats)),
      'dps': (
        'Derived DPS',
        '${stats.dpsTotal.toStringAsFixed(1)} DPS '
            '(guns ${stats.dpsGuns.toStringAsFixed(1)} / '
            'missiles ${stats.dpsMissiles.toStringAsFixed(1)} / '
            'drones ${stats.dpsDrones.toStringAsFixed(1)} / '
            'fighters ${stats.dpsFighters.toStringAsFixed(1)}); '
            'volley ${stats.volley.round()}',
      ),
      'mobility': (
        'Derived speed and signature',
        '${_comma(stats.maxVelocity.round())} m/s; '
            'sig ${stats.signatureRadius.round()} m; '
            'align ${stats.alignTime.toStringAsFixed(1)} s',
      ),
      'coverage': ('Fit coverage', derivation.coverage.describe()),
    };
    if (matchup != null) {
      keys['matchup'] = ('Damage matchup', _matchupValue(matchup));
    }

    return [
      for (final entry in keys.entries)
        CombatEvidenceFact(
          id: 'ev-derived-$subject-${entry.key}-$encounterId',
          label: entry.value.$1,
          value: entry.value.$2,
          source: EvidenceSource.dogmaDerivation,
          confidence: derivation.skills.confidence,
          evidenceTime: derivation.derivedAt,
          limitations: derivation.limitations,
        ),
    ];
  }

  static List<AarUnknown> unknownsFor(
    AarDerivationBundle bundle, {
    required bool hasPilotEvidence,
    required bool hasOpponentEvidence,
    required CombatDamageProfile incoming,
  }) {
    Log.d(
      'AAR',
      'AarDerivedFactsBuilder.unknownsFor pilot=$hasPilotEvidence '
          'opponent=$hasOpponentEvidence unknownWeapons=${incoming.unknownWeapons.length}',
    );
    final unknowns = <AarUnknown>[];
    if (!hasOpponentEvidence) {
      unknowns.add(
        const AarUnknown(
          category: AarUnknownCategory.opponentFit,
          label: 'Opponent defense profile',
          detail:
              'No opponent fit evidence: resists, EHP and tank layer cannot be derived. '
              'A matched killmail of the opponent\'s loss or a manual fit import resolves it.',
        ),
      );
    }
    if (!hasPilotEvidence) {
      unknowns.add(
        const AarUnknown(
          category: AarUnknownCategory.pilotFit,
          label: 'Pilot fit',
          detail:
              'No pilot fit evidence: resists, EHP and tank layer cannot be derived. '
              'A current-ship snapshot or a manual fit import resolves it.',
        ),
      );
    }
    _addFitUnknowns(
      unknowns,
      bundle.self,
      AarUnknownCategory.pilotFit,
      'Pilot skills',
    );
    _addFitUnknowns(
      unknowns,
      bundle.opponent,
      AarUnknownCategory.opponentFit,
      'Opponent skills',
    );
    if (incoming.unknownWeapons.isNotEmpty) {
      unknowns.add(
        AarUnknown(
          category: AarUnknownCategory.telemetry,
          label: 'Unresolved incoming weapons',
          detail:
              'Incoming damage from ${incoming.unknownWeapons.join(', ')} '
              'could not be typed and is excluded from the matchup.',
        ),
      );
    }
    return unknowns;
  }

  static void _addFitUnknowns(
    List<AarUnknown> out,
    AarFitDerivation? derivation,
    AarUnknownCategory category,
    String skillsLabel,
  ) {
    if (derivation == null) return;
    if (derivation.coverage.hasUnresolved) {
      final ids = [
        for (final id in derivation.coverage.unresolvedTypeIds) 'Type #$id',
      ].join(', ');
      out.add(
        AarUnknown(
          category: category,
          label: 'Modules not in SDE',
          detail:
              '${derivation.coverage.unresolvedTypeIds.length} modules not in the bundled SDE '
              '($ids); derived EHP and DPS are a floor.',
        ),
      );
    }
    if (derivation.skills.basis == AarSkillBasis.allFive) {
      out.add(
        AarUnknown(
          category: AarUnknownCategory.skills,
          label: skillsLabel,
          detail:
              'Skills unknown; derived figures assume All V and are an upper bound. '
              'ESI skill data for the character resolves it.',
        ),
      );
    }
  }

  static String _resists(ResistProfile r, double hp) =>
      'EM ${r.em.toStringAsFixed(1)}% / Th ${r.thermal.toStringAsFixed(1)}% / '
      'Kin ${r.kinetic.toStringAsFixed(1)}% / Exp ${r.explosive.toStringAsFixed(1)}%; '
      '${_comma(hp.round())} HP';

  static String _cap(FittingStats stats) {
    if (stats.capacitorCapacity <= 0 && stats.capacitorRecharge <= 0) {
      return 'Not modelled (no capacitor attributes)';
    }
    if (stats.isCapStable) {
      return 'Stable at ${stats.capacitorStable.round()}%';
    }
    return 'Unstable: empty in ${stats.capacitorStable.round()} s';
  }

  static String _matchupValue(CombatDamageMatchup matchup) {
    final parts = [
      for (final entry in matchup.entries)
        '${entry.type} ${(entry.percent * 100).round()}% vs '
            '${entry.resistPercent?.toStringAsFixed(1) ?? '?'}% '
            '(${_assessmentWord(entry.assessment)})',
    ];
    final ehp = matchup.ehpAgainstPattern?.total;
    final omni = matchup.ehpOmni?.total;
    if (ehp != null && omni != null) {
      parts.add(
        'EHP vs this profile ${_comma(ehp.round())} (omni ${_comma(omni.round())})',
      );
    }
    if (matchup.primaryHole != null) {
      parts.add('primary hole ${matchup.primaryHole}');
    }
    return parts.join('; ');
  }

  static String _assessmentWord(DamageMatchupAssessment assessment) {
    return switch (assessment) {
      DamageMatchupAssessment.resistHole => 'hole',
      DamageMatchupAssessment.strongResist => 'strong',
      DamageMatchupAssessment.neutral => 'neutral',
      DamageMatchupAssessment.unknown => 'unknown',
    };
  }

  static String _comma(int n) {
    final sign = n < 0 ? '-' : '';
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$sign$buf';
  }
}
