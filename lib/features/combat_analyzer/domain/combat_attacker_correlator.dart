import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import 'combat_actor_classifier.dart';
import 'combat_attacker_correlation.dart';
import 'parsed_combat_encounter.dart';

class CorrelationContext {
  const CorrelationContext({
    required this.selfIsVictim,
    required this.lastIncomingActor,
    required this.playerActorCount,
    required this.playerParticipantCount,
  });

  final bool selfIsVictim;
  final String? lastIncomingActor;
  final int playerActorCount;
  final int playerParticipantCount;
}

class PairScore {
  const PairScore({
    required this.actor,
    required this.participant,
    required this.score,
    required this.signals,
  });

  final CombatLogActor actor;
  final CombatKillmailParticipant participant;
  final double score;
  final List<CorrelationSignal> signals;

  AttackerCorrelationConfidence? get band =>
      AttackerCorrelationRules.bandFor(score);

  AttackerCorrelationConfidence? get cappedBand {
    final uncapped = band;
    if (uncapped == null) return null;
    if (actor.actorClass == CombatActorClass.shipType &&
        uncapped == AttackerCorrelationConfidence.confirmed) {
      return AttackerCorrelationConfidence.probable;
    }
    return uncapped;
  }
}

class CombatAttackerCorrelator {
  const CombatAttackerCorrelator();

  AttackerCorrelation correlate({
    required ParsedCombatEncounter encounter,
    required EsiKillmailDetail detail,
    required CombatActorTypeIndex typeIndex,
    required DateTime now,
  }) {
    Log.d(
      'COMBAT.CORRELATE',
      'correlate(killmail=${detail.killmailId}, encounter=${encounter.id}) - START',
    );
    final selfIsVictim = detail.victim.characterId == encounter.characterId;
    final people = participants(
      detail,
      selfCharacterId: encounter.characterId,
      typeIndex: typeIndex,
    );
    final actors = CombatActorClassifier.classify(
      encounter: encounter,
      participants: people,
      typeIndex: typeIndex,
    );
    final context = contextFor(
      encounter,
      actors,
      people,
      selfIsVictim: selfIsVictim,
    );
    final pairs = <PairScore>[];
    for (final actor in actors) {
      if (!actor.isScorable) continue;
      for (final participant in people) {
        if (!participant.isPlayer) continue;
        final pair = score(
          actor: actor,
          participant: participant,
          context: context,
          typeIndex: typeIndex,
        );
        pairs.add(pair);
        Log.d(
          'COMBAT.CORRELATE',
          'actor=${actor.displayName} participant=${participant.key} '
              'score=${pair.score.toStringAsFixed(2)} '
              'signals=${pair.signals.map((s) => s.name).join(',')}',
        );
      }
    }
    final result = assign(
      actors: actors,
      participants: people,
      pairs: pairs,
      totalIncomingDamage: encounter.totalDamageReceived,
      killmailId: detail.killmailId,
      selfIsVictim: selfIsVictim,
      now: now,
    );
    Log.i(
      'COMBAT.CORRELATE',
      'correlated=${result.correlated.length} '
          'unattributed=${result.unattributedActors.where((a) => a.isScorable).length} '
          'npc=${result.npcIncomingDamage} '
          'uncorrelated=${result.uncorrelatedParticipants.length}',
    );
    return result;
  }

  static List<CombatKillmailParticipant> participants(
    EsiKillmailDetail detail, {
    required int? selfCharacterId,
    required CombatActorTypeIndex typeIndex,
  }) {
    final people = <CombatKillmailParticipant>[];
    for (var i = 0; i < detail.attackers.length; i++) {
      final attacker = detail.attackers[i];
      if (selfCharacterId != null && attacker.characterId == selfCharacterId) {
        continue;
      }
      final ship = attacker.shipTypeId == null
          ? null
          : typeIndex.byId[attacker.shipTypeId];
      people.add(
        CombatKillmailParticipant.fromAttacker(
          attacker,
          i,
          shipTypeName: ship?.typeName,
        ),
      );
    }
    final victim = detail.victim;
    if (selfCharacterId == null || victim.characterId != selfCharacterId) {
      final ship = typeIndex.byId[victim.shipTypeId];
      people.add(
        CombatKillmailParticipant.fromVictim(
          victim,
          shipTypeName: ship?.typeName,
        ),
      );
    }
    return people;
  }

  static CorrelationContext contextFor(
    ParsedCombatEncounter encounter,
    List<CombatLogActor> actors,
    List<CombatKillmailParticipant> people, {
    required bool selfIsVictim,
  }) {
    String? lastIncomingActor;
    DateTime? lastTimestamp;
    for (final event in encounter.events) {
      if (!event.isIncomingDamage) continue;
      final name = normalizeCombatName(event.targetName ?? '');
      if (lastTimestamp == null ||
          event.timestamp.isAfter(lastTimestamp) ||
          event.timestamp.isAtSameMomentAs(lastTimestamp)) {
        lastTimestamp = event.timestamp;
        lastIncomingActor = name.isEmpty ? null : name;
      }
    }
    return CorrelationContext(
      selfIsVictim: selfIsVictim,
      lastIncomingActor: lastIncomingActor,
      playerActorCount: actors
          .where(
            (actor) =>
                actor.actorClass == CombatActorClass.player ||
                actor.actorClass == CombatActorClass.ambiguous,
          )
          .length,
      playerParticipantCount: people.where((p) => p.isPlayer).length,
    );
  }

  static PairScore score({
    required CombatLogActor actor,
    required CombatKillmailParticipant participant,
    required CorrelationContext context,
    required CombatActorTypeIndex typeIndex,
  }) {
    final signals = <CorrelationSignal>[];
    var total = 0.0;

    final actorName = normalizeCombatName(actor.displayName);
    final participantName = participant.characterName;
    if (participantName != null &&
        participantName.trim().isNotEmpty &&
        actorName == normalizeCombatName(participantName)) {
      signals.add(CorrelationSignal.name);
      total += CorrelationSignal.name.weight;
    }

    if (actor.resolvedTypeId != null &&
        actor.resolvedTypeId == participant.shipTypeId) {
      signals.add(CorrelationSignal.ship);
      total += CorrelationSignal.ship.weight;
    }

    if (_weaponMatches(actor, participant, typeIndex)) {
      signals.add(CorrelationSignal.weapon);
      total += CorrelationSignal.weapon.weight;
    }

    final damageDone = participant.damageDone;
    if (damageDone != null && damageDone > 0 && actor.damageDealt > 0) {
      final min = actor.damageDealt < damageDone
          ? actor.damageDealt
          : damageDone;
      final max = actor.damageDealt > damageDone
          ? actor.damageDealt
          : damageDone;
      final ratio = min / max;
      if (ratio >= AttackerCorrelationRules.damageRatioFull) {
        signals.add(CorrelationSignal.damage);
        total += CorrelationSignal.damage.weight;
      } else if (ratio >= AttackerCorrelationRules.damageRatioHalf) {
        signals.add(CorrelationSignal.damage);
        total += AttackerCorrelationRules.damageHalfWeight;
      }
    }

    if (context.selfIsVictim &&
        participant.finalBlow &&
        context.lastIncomingActor == actorName) {
      signals.add(CorrelationSignal.timing);
      total += CorrelationSignal.timing.weight;
    }

    final playerClass =
        actor.actorClass == CombatActorClass.player ||
        actor.actorClass == CombatActorClass.ambiguous;
    if (playerClass &&
        context.playerActorCount == 1 &&
        context.playerParticipantCount == 1) {
      signals.add(CorrelationSignal.sole);
      total += CorrelationSignal.sole.weight;
    }

    if (total > 1) total = 1;
    if (total < 0) total = 0;
    return PairScore(
      actor: actor,
      participant: participant,
      score: total,
      signals: signals,
    );
  }

  static AttackerCorrelation assign({
    required List<CombatLogActor> actors,
    required List<CombatKillmailParticipant> participants,
    required List<PairScore> pairs,
    required int totalIncomingDamage,
    required int killmailId,
    required bool selfIsVictim,
    required DateTime now,
  }) {
    final bestScore = <String, double>{};
    for (final pair in pairs) {
      final current = bestScore[pair.actor.key] ?? 0;
      if (pair.score > current) bestScore[pair.actor.key] = pair.score;
    }

    final eligible = [
      for (final pair in pairs)
        if (pair.score >= AttackerCorrelationRules.possibleThreshold) pair,
    ]..sort(_comparePairs);

    final remainingActors = <String, CombatLogActor>{
      for (final actor in actors)
        if (actor.isScorable) actor.key: actor,
    };
    final remainingParticipants = <String, CombatKillmailParticipant>{
      for (final participant in participants)
        if (participant.isPlayer) participant.key: participant,
    };
    final correlated = <CorrelatedAttacker>[];
    final reasons = <String, UncorrelatedReason>{};

    while (eligible.isNotEmpty) {
      final p1 = eligible.first;
      final conflicts = [
        for (final other in eligible.skip(1))
          if ((other.actor.key == p1.actor.key ||
                  other.participant.key == p1.participant.key) &&
              p1.score - other.score < AttackerCorrelationRules.ambiguityMargin)
            other,
      ];
      if (conflicts.isEmpty) {
        final confidence = PairScore(
          actor: p1.actor,
          participant: p1.participant,
          score: p1.score,
          signals: p1.signals,
        ).cappedBand;
        if (confidence != null) {
          correlated.add(
            CorrelatedAttacker(
              actor: p1.actor,
              participant: p1.participant,
              confidence: confidence,
              score: p1.score,
              signals: p1.signals,
            ),
          );
        }
        remainingActors.remove(p1.actor.key);
        remainingParticipants.remove(p1.participant.key);
        eligible.removeWhere(
          (pair) =>
              pair.actor.key == p1.actor.key ||
              pair.participant.key == p1.participant.key,
        );
        continue;
      }
      final actorConflict = conflicts.any(
        (pair) => pair.actor.key == p1.actor.key,
      );
      final participantConflict = conflicts.any(
        (pair) => pair.participant.key == p1.participant.key,
      );
      if (actorConflict) {
        reasons['actor:${p1.actor.key}'] = UncorrelatedReason.ambiguous;
        remainingActors.remove(p1.actor.key);
        eligible.removeWhere((pair) => pair.actor.key == p1.actor.key);
      }
      if (participantConflict) {
        reasons['participant:${p1.participant.key}'] =
            UncorrelatedReason.ambiguous;
        remainingParticipants.remove(p1.participant.key);
        eligible.removeWhere(
          (pair) => pair.participant.key == p1.participant.key,
        );
      }
    }

    correlated.sort((a, b) {
      final byDamage = b.actor.damageDealt.compareTo(a.actor.damageDealt);
      if (byDamage != 0) return byDamage;
      return a.actor.displayName.compareTo(b.actor.displayName);
    });
    final correlatedKeys = {for (final row in correlated) row.actor.key};

    final unattributed = <CombatLogActor>[];
    var npcIncoming = 0;
    var unattributedIncoming = 0;
    for (final actor in actors) {
      if (correlatedKeys.contains(actor.key)) continue;
      unattributed.add(actor);
      if (actor.actorClass == CombatActorClass.npc) {
        npcIncoming += actor.damageDealt;
        reasons.putIfAbsent(
          'actor:${actor.key}',
          () => UncorrelatedReason.npcActor,
        );
        continue;
      }
      unattributedIncoming += actor.damageDealt;
      if (actor.actorClass == CombatActorClass.unnamed) {
        reasons.putIfAbsent(
          'actor:${actor.key}',
          () => UncorrelatedReason.unnamed,
        );
        continue;
      }
      if (reasons.containsKey('actor:${actor.key}')) continue;
      final best = bestScore[actor.key] ?? 0;
      reasons['actor:${actor.key}'] = best == 0
          ? UncorrelatedReason.notOnKillmail
          : UncorrelatedReason.belowThreshold;
    }

    final correlatedParticipantKeys = {
      for (final row in correlated) row.participant.key,
    };
    final uncorrelated = <CombatKillmailParticipant>[];
    for (final participant in participants) {
      if (correlatedParticipantKeys.contains(participant.key)) continue;
      uncorrelated.add(participant);
      if (!participant.isPlayer) {
        reasons.putIfAbsent(
          'participant:${participant.key}',
          () => UncorrelatedReason.npcAttacker,
        );
        continue;
      }
      reasons.putIfAbsent(
        'participant:${participant.key}',
        () => UncorrelatedReason.noLogPresence,
      );
    }

    return AttackerCorrelation(
      killmailId: killmailId,
      selfIsVictim: selfIsVictim,
      correlated: correlated,
      unattributedActors: unattributed,
      uncorrelatedParticipants: uncorrelated,
      correlatedIncomingDamage: [
        for (final row in correlated) row.actor.damageDealt,
      ].fold<int>(0, (sum, value) => sum + value),
      unattributedIncomingDamage: unattributedIncoming,
      npcIncomingDamage: npcIncoming,
      totalIncomingDamage: totalIncomingDamage,
      reasons: reasons,
      correlatedAt: now,
    );
  }

  static bool _weaponMatches(
    CombatLogActor actor,
    CombatKillmailParticipant participant,
    CombatActorTypeIndex typeIndex,
  ) {
    for (final name in actor.weaponNames) {
      final type = typeIndex.byName[normalizeCombatName(name)];
      if (type == null) continue;
      if (participant.weaponTypeId != null &&
          type.typeId == participant.weaponTypeId) {
        return true;
      }
      if (participant.weaponGroupId != null &&
          type.groupId == participant.weaponGroupId) {
        return true;
      }
    }
    return false;
  }

  static int _comparePairs(PairScore a, PairScore b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final aDamage = a.participant.damageDone;
    final bDamage = b.participant.damageDone;
    if (aDamage == null && bDamage != null) return 1;
    if (aDamage != null && bDamage == null) return -1;
    if (aDamage != null && bDamage != null) {
      final byDamage = bDamage.compareTo(aDamage);
      if (byDamage != 0) return byDamage;
    }
    final aId = a.participant.characterId ?? 0x7fffffff;
    final bId = b.participant.characterId ?? 0x7fffffff;
    final byId = aId.compareTo(bId);
    if (byId != 0) return byId;
    return a.actor.displayName.compareTo(b.actor.displayName);
  }
}
