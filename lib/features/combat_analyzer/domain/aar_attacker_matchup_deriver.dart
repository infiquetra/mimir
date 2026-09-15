import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/logging/logger.dart';
import 'aar_attacker_matchup.dart';
import 'aar_attacker_matchup_facts.dart';
import 'aar_fit_derivation.dart';
import 'combat_attacker_correlation.dart';
import 'combat_damage_matchup.dart';
import 'combat_evidence_ledger.dart';
import 'incoming_damage_allocation.dart';
import 'incoming_damage_matchup.dart';

final class AarAttackerMatchupDeriver {
  static AarIncomingMatchupBundle derive({
    required IncomingDamageAllocation allocation,
    required IncomingCorrelationContext correlation,
    required AarFitDerivation? pilotFit,
    required FitEvidence? pilotFitEvidence,
    required String? pilotFitKey,
    required List<String> dependencyLimitations,
  }) {
    Log.d(
      'AAR.MATCHUP',
      'AarAttackerMatchupDeriver.derive encounter=${allocation.encounterId} '
          'sources=${allocation.sources.length}',
    );
    final partitioned = _partition(allocation, correlation);
    final defenseLimitations = [
      ...dependencyLimitations,
      ...partitioned.limitations,
    ];
    AarIncomingDefenseMatchup defenseFor(IncomingSourceAllocation source) {
      final result = CombatDamageMatchupAnalyzer.analyzeIncoming(
        components: source.components,
        defense: pilotFit?.stats.defenses,
        tank: pilotFit?.tank,
        pilotFitKey: pilotFitKey,
      );
      if (source.untypedDamage > 0 && source.resolvedDamage > 0) {
        return AarIncomingDefenseMatchup(
          status: result.status,
          pressureStatus: result.pressureStatus,
          pattern: result.pattern,
          ehp: result.ehp,
          omniEhp: result.omniEhp,
          layer: result.layer,
          entries: result.entries,
          primaryHole: result.primaryHole,
          guardedLayers: result.guardedLayers,
          limitationCodes: [...result.limitationCodes, 'resolvedPortionOnly'],
          pilotFitKey: result.pilotFitKey,
        );
      }
      return result;
    }

    final attackers = [
      for (final source in partitioned.attributed)
        AarAttackerMatchup(
          source: source,
          defense: defenseFor(source.allocation),
        ),
    ];
    final aggregateDefense = CombatDamageMatchupAnalyzer.analyzeIncoming(
      components: allocation.components,
      defense: pilotFit?.stats.defenses,
      tank: pilotFit?.tank,
      pilotFitKey: pilotFitKey,
    );
    final snapshotKey = sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'allocationKey': allocation.allocationKey,
              'killmailId': correlation.selectedKillmailId,
              'pilotFitKey': pilotFitKey,
              'sourceIds': [
                for (final source in allocation.sources) source.sourceId,
              ],
              'attributed': [
                for (final row in partitioned.attributed)
                  row.allocation.sourceId,
              ],
              'limitations': defenseLimitations,
            }),
          ),
        )
        .toString();
    final draft = AarIncomingMatchupBundle(
      encounterId: allocation.encounterId,
      snapshotKey: snapshotKey,
      allocation: allocation,
      attackers: attackers,
      unattributed: partitioned.unattributed,
      npc: partitioned.npc,
      notObserved: partitioned.notObserved,
      aggregateDefense: aggregateDefense,
      pilotFit: pilotFit,
      pilotFitEvidence: pilotFitEvidence,
      limitationCodes: defenseLimitations,
      evidence: const CombatEvidenceLedger(),
    );
    final complete = draft.withEvidence(AarAttackerMatchupFacts.build(draft));
    Log.i(
      'AAR.MATCHUP',
      'derived attackers=${complete.attackers.length} '
          'unattributed=${complete.unattributed.length} '
          'npc=${complete.npc.length}',
    );
    return complete;
  }

  static _Partition _partition(
    IncomingDamageAllocation allocation,
    IncomingCorrelationContext context,
  ) {
    final usable = _usableCorrelation(context, allocation);
    if (!usable) {
      final attributed = <AarIncomingSource>[];
      final unattributed = <AarIncomingSource>[];
      final npc = <AarIncomingSource>[];
      for (final source in allocation.sources) {
        final cls = _classifyName(source.rawActorName, context);
        final row = AarIncomingSource(
          allocation: source,
          bucket: cls == CombatActorClass.npc
              ? IncomingSourceBucket.npc
              : IncomingSourceBucket.unattributed,
          identity: null,
          binding: context.correlation == null
              ? CorrelationBindingStatus.unavailable
              : CorrelationBindingStatus.rejected,
          limitationCodes: context.correlation == null
              ? const ['correlationUnavailable']
              : const ['correlationRejected'],
        );
        if (row.bucket == IncomingSourceBucket.npc) {
          npc.add(row);
        } else {
          unattributed.add(row);
        }
      }
      return _Partition(
        attributed: attributed,
        unattributed: unattributed,
        npc: npc,
        notObserved: const [],
        limitations: context.correlation == null
            ? const ['correlationUnavailable']
            : const ['correlationRejected'],
      );
    }

    final correlation = context.correlation!;
    final actorRows = <_ActorRef>[
      for (final row in correlation.correlated)
        _ActorRef(actor: row.actor, correlated: row),
      for (final actor in correlation.unattributedActors)
        _ActorRef(actor: actor, correlated: null),
    ];
    final boundSources = <String, _ActorRef>{};
    final boundActors = <CombatLogActor>{};

    void bind(IncomingSourceAllocation source, _ActorRef ref) {
      boundSources[source.sourceId] = ref;
      boundActors.add(ref.actor);
    }

    for (final source in allocation.sources) {
      final exact = [
        for (final ref in actorRows)
          if (ref.actor.displayName == source.rawActorName &&
              !boundActors.contains(ref.actor))
            ref,
      ];
      if (exact.length == 1) bind(source, exact.single);
    }
    for (final source in allocation.sources) {
      if (boundSources.containsKey(source.sourceId)) continue;
      final unmatchedSources = [
        for (final candidate in allocation.sources)
          if (!boundSources.containsKey(candidate.sourceId) &&
              candidate.normalizedActorName == source.normalizedActorName)
            candidate,
      ];
      final unmatchedActors = [
        for (final ref in actorRows)
          if (!boundActors.contains(ref.actor) &&
              ref.actor.key == source.normalizedActorName)
            ref,
      ];
      if (unmatchedSources.length == 1 && unmatchedActors.length == 1) {
        bind(source, unmatchedActors.single);
      }
    }

    final attributed = <AarIncomingSource>[];
    final unattributed = <AarIncomingSource>[];
    final npc = <AarIncomingSource>[];
    final usedParticipants = <int?>{};

    for (final source in allocation.sources) {
      final ref = boundSources[source.sourceId];
      final limitations = <String>['legacyStructuralValidation'];
      if (ref == null) {
        final cls = _classifyName(source.rawActorName, context);
        final row = AarIncomingSource(
          allocation: source,
          bucket: cls == CombatActorClass.npc
              ? IncomingSourceBucket.npc
              : IncomingSourceBucket.unattributed,
          identity: null,
          binding: CorrelationBindingStatus.legacyStructuralValidation,
          limitationCodes: [...limitations, 'unboundSource'],
        );
        if (row.bucket == IncomingSourceBucket.npc) {
          npc.add(row);
        } else {
          unattributed.add(row);
        }
        continue;
      }
      usedParticipants.add(ref.correlated?.participant.characterId);
      if (ref.correlated != null) {
        final identity = ref.correlated!;
        if (identity.actor.actorClass == CombatActorClass.shipType &&
            identity.confidence == AttackerCorrelationConfidence.confirmed) {
          unattributed.add(
            AarIncomingSource(
              allocation: source,
              bucket: IncomingSourceBucket.unattributed,
              identity: identity,
              binding: CorrelationBindingStatus.rejected,
              limitationCodes: [
                ...limitations,
                'inconsistentShipTypeConfirmed',
              ],
            ),
          );
          continue;
        }
        if (identity.confidence == AttackerCorrelationConfidence.possible) {
          unattributed.add(
            AarIncomingSource(
              allocation: source,
              bucket: IncomingSourceBucket.unattributed,
              identity: identity,
              binding: CorrelationBindingStatus.legacyStructuralValidation,
              limitationCodes: [...limitations, 'possibleUncertain'],
            ),
          );
          continue;
        }
        if (identity.participant.isPlayer &&
            (identity.confidence == AttackerCorrelationConfidence.confirmed ||
                identity.confidence ==
                    AttackerCorrelationConfidence.probable)) {
          attributed.add(
            AarIncomingSource(
              allocation: source,
              bucket: IncomingSourceBucket.attributed,
              identity: identity,
              binding: CorrelationBindingStatus.legacyStructuralValidation,
              limitationCodes: limitations,
            ),
          );
          continue;
        }
        unattributed.add(
          AarIncomingSource(
            allocation: source,
            bucket: IncomingSourceBucket.unattributed,
            identity: identity,
            binding: CorrelationBindingStatus.legacyStructuralValidation,
            limitationCodes: [...limitations, 'notEligibleNamedCard'],
          ),
        );
        continue;
      }
      if (ref.actor.actorClass == CombatActorClass.npc) {
        npc.add(
          AarIncomingSource(
            allocation: source,
            bucket: IncomingSourceBucket.npc,
            identity: null,
            binding: CorrelationBindingStatus.legacyStructuralValidation,
            limitationCodes: limitations,
          ),
        );
      } else {
        unattributed.add(
          AarIncomingSource(
            allocation: source,
            bucket: IncomingSourceBucket.unattributed,
            identity: null,
            binding: CorrelationBindingStatus.legacyStructuralValidation,
            limitationCodes: [...limitations, 'm4Unattributed'],
          ),
        );
      }
    }

    final notObserved = [
      for (final participant in correlation.uncorrelatedPlayerParticipants)
        if (!usedParticipants.contains(participant.characterId)) participant,
    ];
    attributed.sort(
      (a, b) => a.allocation.sourceId.compareTo(b.allocation.sourceId),
    );
    unattributed.sort(
      (a, b) => a.allocation.sourceId.compareTo(b.allocation.sourceId),
    );
    npc.sort((a, b) => a.allocation.sourceId.compareTo(b.allocation.sourceId));
    return _Partition(
      attributed: attributed,
      unattributed: unattributed,
      npc: npc,
      notObserved: notObserved,
      limitations: const ['legacyStructuralValidation'],
    );
  }

  static bool _usableCorrelation(
    IncomingCorrelationContext context,
    IncomingDamageAllocation allocation,
  ) {
    final correlation = context.correlation;
    if (correlation == null) return false;
    if (context.parsedEncounterId != allocation.encounterId) return false;
    if (context.selectedKillmailId != correlation.killmailId) return false;
    if (correlation.rulesVersion != 1) return false;
    if (context.selfIsVictim != null &&
        context.selfIsVictim != correlation.selfIsVictim) {
      return false;
    }
    if (correlation.correlatedIncomingDamage +
            correlation.unattributedIncomingDamage +
            correlation.npcIncomingDamage !=
        correlation.totalIncomingDamage) {
      return false;
    }
    return true;
  }

  static CombatActorClass _classifyName(
    String raw,
    IncomingCorrelationContext context,
  ) {
    final key = normalizeCombatName(raw);
    if (key.isEmpty || key == 'unknown') return CombatActorClass.unnamed;
    final playerNames = <String>{
      for (final participant in context.currentParticipants)
        if (participant.isPlayer && participant.characterName != null)
          normalizeCombatName(participant.characterName!),
    };
    final type = context.localActorTypes[key];
    final matchesPlayer = playerNames.contains(key);
    if (matchesPlayer && type != null) return CombatActorClass.ambiguous;
    if (matchesPlayer) return CombatActorClass.player;
    if (type?.categoryId == AttackerCorrelationRules.entityCategoryId) {
      return CombatActorClass.npc;
    }
    if (type?.categoryId == AttackerCorrelationRules.shipCategoryId) {
      return CombatActorClass.shipType;
    }
    return CombatActorClass.player;
  }
}

class _ActorRef {
  const _ActorRef({required this.actor, required this.correlated});

  final CombatLogActor actor;
  final CorrelatedAttacker? correlated;
}

class _Partition {
  const _Partition({
    required this.attributed,
    required this.unattributed,
    required this.npc,
    required this.notObserved,
    required this.limitations,
  });

  final List<AarIncomingSource> attributed;
  final List<AarIncomingSource> unattributed;
  final List<AarIncomingSource> npc;
  final List<CombatKillmailParticipant> notObserved;
  final List<String> limitations;
}
