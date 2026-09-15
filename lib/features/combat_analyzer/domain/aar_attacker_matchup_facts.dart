import '../../../core/logging/logger.dart';
import 'aar_attacker_matchup.dart';
import 'aar_fit_derivation.dart';
import 'combat_attacker_correlation.dart';
import 'combat_evidence_ledger.dart';

final class AarAttackerMatchupFacts {
  static CombatEvidenceLedger build(AarIncomingMatchupBundle bundle) {
    Log.d(
      'AAR.MATCHUP',
      'AarAttackerMatchupFacts.build encounter=${bundle.encounterId}',
    );
    final token = bundle.encounterId;
    final time = bundle.allocation.encounterEnd;
    final facts = <CombatEvidenceFact>[];

    void add({
      required String suffix,
      required String label,
      required String value,
      required EvidenceSource source,
      required EvidenceConfidence confidence,
    }) {
      facts.add(
        CombatEvidenceFact(
          id: 'ev-m5-$token-$suffix',
          label: label,
          value: value,
          source: source,
          confidence: confidence,
          evidenceTime: time,
        ),
      );
    }

    for (final row in bundle.attackers) {
      final source = row.source;
      final raw = source.allocation.rawActorName;
      add(
        suffix: '${source.allocation.sourceId}-logged',
        label: 'Logged incoming from $raw',
        value: '${source.allocation.loggedDamage}',
        source: EvidenceSource.combatLog,
        confidence: EvidenceConfidence.proven,
      );
      add(
        suffix: '${source.allocation.sourceId}-profile',
        label: 'Resolved incoming profile for $raw',
        value:
            'resolved ${source.allocation.resolvedDamage} / '
            'untyped ${source.allocation.untypedDamage}',
        source: EvidenceSource.sde,
        confidence: EvidenceConfidence.derived,
      );
      final identity = source.identity;
      if (identity != null) {
        add(
          suffix: '${_participantToken(identity)}-identity',
          label: 'Identity for $raw',
          value: identity.confidence.label,
          source: EvidenceSource.killmail,
          confidence: _identityConfidence(identity.confidence),
        );
        add(
          suffix: '${_participantToken(identity)}-defense',
          label: 'Defense matchup for $raw',
          value: row.defense.primaryHole?.name ?? 'none',
          source: EvidenceSource.dogmaDerivation,
          confidence: _defenseConfidence(bundle.pilotFit, identity.confidence),
        );
      }
    }

    add(
      suffix: 'aggregate-profile',
      label: 'Aggregate incoming profile',
      value:
          'resolved ${bundle.allocation.resolvedDamage} / '
          'untyped ${bundle.allocation.untypedDamage}',
      source: EvidenceSource.sde,
      confidence: EvidenceConfidence.derived,
    );
    add(
      suffix: 'aggregate-defense',
      label: 'Aggregate incoming defense',
      value: bundle.aggregateDefense.primaryHole?.name ?? 'none',
      source: EvidenceSource.dogmaDerivation,
      confidence: _defenseConfidence(bundle.pilotFit, null),
    );

    if (bundle.unattributed.isNotEmpty) {
      final logged = bundle.unattributed.fold<int>(
        0,
        (sum, source) => sum + source.allocation.loggedDamage,
      );
      add(
        suffix: 'residual-x',
        label: 'Unattributed incoming residual',
        value: '$logged',
        source: EvidenceSource.combatLog,
        confidence: EvidenceConfidence.derived,
      );
    }
    if (bundle.npc.isNotEmpty) {
      final logged = bundle.npc.fold<int>(
        0,
        (sum, source) => sum + source.allocation.loggedDamage,
      );
      add(
        suffix: 'residual-npc',
        label: 'NPC incoming residual',
        value: '$logged',
        source: EvidenceSource.combatLog,
        confidence: EvidenceConfidence.derived,
      );
    }

    return CombatEvidenceLedger(facts: List.unmodifiable(facts));
  }

  static String _participantToken(CorrelatedAttacker identity) {
    final id = identity.participant.characterId ?? 0;
    final victim = identity.participant.isVictim ? 'v' : 'a';
    return '$victim-$id';
  }

  static EvidenceConfidence _identityConfidence(
    AttackerCorrelationConfidence band,
  ) {
    return switch (band) {
      AttackerCorrelationConfidence.confirmed => EvidenceConfidence.proven,
      AttackerCorrelationConfidence.probable => EvidenceConfidence.derived,
      AttackerCorrelationConfidence.possible => EvidenceConfidence.reference,
    };
  }

  static EvidenceConfidence _defenseConfidence(
    AarFitDerivation? fit,
    AttackerCorrelationConfidence? band,
  ) {
    final deps = <EvidenceConfidence>[
      EvidenceConfidence.derived,
      EvidenceConfidence.derived,
      if (band != null) _identityConfidence(band),
      fit?.skills.confidence ?? EvidenceConfidence.unknown,
    ];
    return _weakestCapped(deps);
  }

  static EvidenceConfidence _weakestCapped(List<EvidenceConfidence> deps) {
    var weakest = EvidenceConfidence.proven;
    for (final dep in deps) {
      if (_rank(dep) < _rank(weakest)) weakest = dep;
    }
    if (_rank(weakest) > _rank(EvidenceConfidence.derived)) {
      return EvidenceConfidence.derived;
    }
    return weakest;
  }

  static int _rank(EvidenceConfidence confidence) {
    return switch (confidence) {
      EvidenceConfidence.unknown => 0,
      EvidenceConfidence.reference => 1,
      EvidenceConfidence.derived => 2,
      EvidenceConfidence.confirmed => 3,
      EvidenceConfidence.proven => 4,
    };
  }
}
