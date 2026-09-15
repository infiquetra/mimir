import 'aar_fit_derivation.dart';
import 'combat_actor_classifier.dart';
import 'combat_attacker_correlation.dart';
import 'combat_evidence_ledger.dart';
import 'incoming_damage_allocation.dart';
import 'incoming_damage_matchup.dart';

enum IncomingSourceBucket { attributed, unattributed, npc }

enum CorrelationBindingStatus {
  valid,
  legacyStructuralValidation,
  unavailable,
  rejected,
}

final class IncomingCorrelationContext {
  const IncomingCorrelationContext({
    required this.parsedEncounterId,
    required this.selectedKillmailId,
    required this.selfCharacterId,
    required this.selfIsVictim,
    required this.correlation,
    required this.currentParticipants,
    required this.localActorTypes,
  });

  final String parsedEncounterId;
  final int? selectedKillmailId;
  final int? selfCharacterId;
  final bool? selfIsVictim;
  final AttackerCorrelation? correlation;
  final List<CombatKillmailParticipant> currentParticipants;
  final Map<String, CombatTypeRef> localActorTypes;
}

final class AarIncomingSource {
  const AarIncomingSource({
    required this.allocation,
    required this.bucket,
    required this.binding,
    required this.limitationCodes,
    this.identity,
  });

  final IncomingSourceAllocation allocation;
  final IncomingSourceBucket bucket;
  final CorrelatedAttacker? identity;
  final CorrelationBindingStatus binding;
  final List<String> limitationCodes;

  bool get namedCardEligible =>
      bucket == IncomingSourceBucket.attributed &&
      identity != null &&
      (identity!.confidence == AttackerCorrelationConfidence.confirmed ||
          identity!.confidence == AttackerCorrelationConfidence.probable) &&
      allocation.loggedDamage > 0;
}

final class AarAttackerMatchup {
  const AarAttackerMatchup({required this.source, required this.defense});

  final AarIncomingSource source;
  final AarIncomingDefenseMatchup defense;
}

final class AarIncomingMatchupBundle {
  AarIncomingMatchupBundle({
    required this.encounterId,
    required this.snapshotKey,
    required this.allocation,
    required List<AarAttackerMatchup> attackers,
    required List<AarIncomingSource> unattributed,
    required List<AarIncomingSource> npc,
    required List<CombatKillmailParticipant> notObserved,
    required this.aggregateDefense,
    required this.pilotFit,
    required this.pilotFitEvidence,
    required List<String> limitationCodes,
    required this.evidence,
  }) : attackers = List.unmodifiable(attackers),
       unattributed = List.unmodifiable(unattributed),
       npc = List.unmodifiable(npc),
       notObserved = List.unmodifiable(notObserved),
       limitationCodes = List.unmodifiable(limitationCodes);

  final String encounterId;
  final String snapshotKey;
  final IncomingDamageAllocation allocation;
  final List<AarAttackerMatchup> attackers;
  final List<AarIncomingSource> unattributed;
  final List<AarIncomingSource> npc;
  final List<CombatKillmailParticipant> notObserved;
  final AarIncomingDefenseMatchup aggregateDefense;
  final AarFitDerivation? pilotFit;
  final FitEvidence? pilotFitEvidence;
  final List<String> limitationCodes;
  final CombatEvidenceLedger evidence;

  AarIncomingMatchupBundle withEvidence(CombatEvidenceLedger evidence) {
    return AarIncomingMatchupBundle(
      encounterId: encounterId,
      snapshotKey: snapshotKey,
      allocation: allocation,
      attackers: attackers,
      unattributed: unattributed,
      npc: npc,
      notObserved: notObserved,
      aggregateDefense: aggregateDefense,
      pilotFit: pilotFit,
      pilotFitEvidence: pilotFitEvidence,
      limitationCodes: limitationCodes,
      evidence: evidence,
    );
  }

  Map<String, dynamic> toPromptJson() {
    Map<String, dynamic> sourceJson(AarIncomingSource source) => {
      'rawActorName': source.allocation.rawActorName,
      'loggedDamage': source.allocation.loggedDamage,
      'resolvedDamage': source.allocation.resolvedDamage,
      'untypedDamage': source.allocation.untypedDamage,
      'components': source.allocation.components.toJson(),
      'bucket': source.bucket.name,
      if (source.identity != null)
        'confidence': source.identity!.confidence.name,
      'limitations': source.limitationCodes,
    };
    Map<String, dynamic> defenseJson(AarIncomingDefenseMatchup defense) => {
      'status': defense.status.name,
      'pressureStatus': defense.pressureStatus.name,
      'layer': defense.layer.name,
      if (defense.ehp != null) 'ehp': defense.ehp!.total,
      if (defense.omniEhp != null) 'omniEhp': defense.omniEhp!.total,
      if (defense.primaryHole != null) 'primaryHole': defense.primaryHole!.name,
      'limitations': defense.limitationCodes,
    };
    return {
      'quantityBasis': 'sde-decimal-v1',
      'encounterId': encounterId,
      'totalIncomingDamage': allocation.totalIncomingDamage,
      'resolvedDamage': allocation.resolvedDamage,
      'untypedDamage': allocation.untypedDamage,
      'components': allocation.components.toJson(),
      'attackers': [
        for (final row in attackers)
          {...sourceJson(row.source), 'defense': defenseJson(row.defense)},
      ],
      'unattributed': [for (final row in unattributed) sourceJson(row)],
      'npc': [for (final row in npc) sourceJson(row)],
      'aggregateDefense': defenseJson(aggregateDefense),
      'notObservedCount': notObserved.length,
      'limitations': limitationCodes,
    };
  }
}
