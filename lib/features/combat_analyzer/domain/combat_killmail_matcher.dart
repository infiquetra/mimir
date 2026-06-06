import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import 'parsed_combat_encounter.dart';

enum CombatKillmailMatchStatus { matched, ambiguous, noMatch }

class CombatKillmailCandidate {
  const CombatKillmailCandidate({
    required this.detail,
    required this.confidence,
    required this.reason,
  });

  final EsiKillmailDetail detail;
  final double confidence;
  final String reason;
}

class CombatKillmailMatchResult {
  const CombatKillmailMatchResult({
    required this.status,
    required this.confidence,
    required this.reason,
    this.detail,
    this.candidates = const [],
  });

  final CombatKillmailMatchStatus status;
  final double confidence;
  final String reason;
  final EsiKillmailDetail? detail;
  final List<CombatKillmailCandidate> candidates;
}

class CombatKillmailMatcher {
  static const double matchThreshold = 0.70;
  static const double ambiguityMargin = 0.10;

  static CombatKillmailMatchResult selectBest(
    ParsedCombatEncounter encounter,
    List<EsiKillmailDetail> killmails,
  ) {
    Log.d(
      'COMBAT.ENRICH',
      'CombatKillmailMatcher.selectBest(${encounter.id}, ${killmails.length}) - START',
    );
    final candidates =
        killmails
            .map((detail) => score(encounter, detail))
            .where((candidate) => candidate.confidence > 0)
            .toList()
          ..sort((a, b) => b.confidence.compareTo(a.confidence));

    if (candidates.isEmpty || candidates.first.confidence < matchThreshold) {
      Log.i('COMBAT.ENRICH', 'No killmail match met threshold');
      return const CombatKillmailMatchResult(
        status: CombatKillmailMatchStatus.noMatch,
        confidence: 0,
        reason:
            'No candidate matched the selected character and encounter time.',
      );
    }

    if (candidates.length > 1 &&
        candidates.first.confidence - candidates[1].confidence <
            ambiguityMargin) {
      Log.w(
        'COMBAT.ENRICH',
        'Ambiguous killmail match: top=${candidates.first.detail.killmailId} second=${candidates[1].detail.killmailId}',
      );
      return CombatKillmailMatchResult(
        status: CombatKillmailMatchStatus.ambiguous,
        confidence: candidates.first.confidence,
        reason: 'Multiple killmails matched within the ambiguity margin.',
        candidates: candidates.take(3).toList(),
      );
    }

    final best = candidates.first;
    Log.i(
      'COMBAT.ENRICH',
      'Matched killmail ${best.detail.killmailId} confidence=${best.confidence.toStringAsFixed(2)}',
    );
    return CombatKillmailMatchResult(
      status: CombatKillmailMatchStatus.matched,
      confidence: best.confidence,
      reason: best.reason,
      detail: best.detail,
      candidates: candidates.take(3).toList(),
    );
  }

  static CombatKillmailCandidate score(
    ParsedCombatEncounter encounter,
    EsiKillmailDetail detail,
  ) {
    Log.d(
      'COMBAT.ENRICH',
      'CombatKillmailMatcher.score(${encounter.id}, ${detail.killmailId}) - START',
    );
    final characterId = encounter.characterId;
    if (characterId == null) {
      return CombatKillmailCandidate(
        detail: detail,
        confidence: 0,
        reason: 'Encounter has no selected character ID.',
      );
    }

    final isVictim = detail.victim.characterId == characterId;
    final isAttacker = detail.attackers.any(
      (attacker) => attacker.characterId == characterId,
    );
    if (!isVictim && !isAttacker) {
      return CombatKillmailCandidate(
        detail: detail,
        confidence: 0,
        reason: 'Selected character was not a killmail participant.',
      );
    }

    final reasons = <String>['selected character participant'];
    var confidence = 0.30;

    final lowerBound = encounter.startTime.toUtc().subtract(
      const Duration(minutes: 2),
    );
    final upperBound = encounter.endTime.toUtc().add(
      const Duration(minutes: 10),
    );
    final killTime = detail.killmailTime.toUtc();
    if (!killTime.isBefore(lowerBound) && !killTime.isAfter(upperBound)) {
      confidence += 0.40;
      reasons.add('killmail time inside encounter window');
    } else {
      final distance = _windowDistance(killTime, lowerBound, upperBound);
      if (distance <= const Duration(minutes: 30)) {
        confidence += 0.15;
        reasons.add('killmail time near encounter window');
      } else {
        return CombatKillmailCandidate(
          detail: detail,
          confidence: 0,
          reason: 'Killmail time was outside the encounter window.',
        );
      }
    }

    final names = _encounterEntityNames(encounter);
    if (_matchesEncounterName(detail.victim.characterName, names) ||
        detail.attackers.any(
          (attacker) => _matchesEncounterName(attacker.characterName, names),
        )) {
      confidence += 0.20;
      reasons.add('participant name appeared in combat log');
    }

    final killmailDamage = isVictim
        ? detail.victim.damageTaken
        : detail.attackers
              .where((attacker) => attacker.characterId == characterId)
              .fold<int>(0, (sum, attacker) => sum + attacker.damageDone);
    final logDamage = isVictim
        ? encounter.totalDamageReceived
        : encounter.totalDamageDealt;
    if (killmailDamage > 0 && logDamage > 0) {
      final ratio = killmailDamage > logDamage
          ? logDamage / killmailDamage
          : killmailDamage / logDamage;
      if (ratio >= 0.25) {
        confidence += 0.10;
        reasons.add('damage totals are directionally compatible');
      }
    }

    return CombatKillmailCandidate(
      detail: detail,
      confidence: confidence.clamp(0, 1).toDouble(),
      reason: reasons.join('; '),
    );
  }

  static Duration _windowDistance(
    DateTime value,
    DateTime lowerBound,
    DateTime upperBound,
  ) {
    if (value.isBefore(lowerBound)) return lowerBound.difference(value);
    if (value.isAfter(upperBound)) return value.difference(upperBound);
    return Duration.zero;
  }

  static Set<String> _encounterEntityNames(ParsedCombatEncounter encounter) {
    return {
          ...encounter.aggregates.damageByTarget.keys,
          ...encounter.aggregates.incomingBySource.keys,
          for (final event in encounter.events)
            if (event.targetName != null) event.targetName!,
        }
        .map((name) => name.trim().toLowerCase())
        .where((name) => name.isNotEmpty && name != 'unknown')
        .toSet();
  }

  static bool _matchesEncounterName(String? name, Set<String> encounterNames) {
    final normalized = name?.trim().toLowerCase();
    return normalized != null && encounterNames.contains(normalized);
  }
}
