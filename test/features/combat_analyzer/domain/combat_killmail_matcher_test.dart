import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_killmail_matcher.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';

void main() {
  group('CombatKillmailMatcher', () {
    test(
      'matches a killmail when the pilot participated inside the time window',
      () {
        final encounter = _encounter(characterId: 9001);
        final detail = _killmail(
          killmailId: 42,
          killmailTime: DateTime.utc(2026, 5, 20, 20, 1, 10),
          victimCharacterId: 9002,
          attackerCharacterIds: const [9001],
        );

        final result = CombatKillmailMatcher.selectBest(encounter, [detail]);

        expect(result.status, CombatKillmailMatchStatus.matched);
        expect(result.detail?.killmailId, 42);
        expect(result.confidence, greaterThanOrEqualTo(0.7));
        expect(result.reason, contains('participant'));
      },
    );

    test('rejects killmails where the selected pilot did not participate', () {
      final encounter = _encounter(characterId: 9001);
      final detail = _killmail(
        killmailId: 42,
        killmailTime: DateTime.utc(2026, 5, 20, 20, 1, 10),
        victimCharacterId: 9002,
        attackerCharacterIds: const [9003],
      );

      final result = CombatKillmailMatcher.selectBest(encounter, [detail]);

      expect(result.status, CombatKillmailMatchStatus.noMatch);
      expect(result.detail, isNull);
    });

    test('marks close competing matches as ambiguous', () {
      final encounter = _encounter(characterId: 9001);
      final first = _killmail(
        killmailId: 42,
        killmailTime: DateTime.utc(2026, 5, 20, 20, 1, 10),
        victimCharacterId: 9002,
        attackerCharacterIds: const [9001],
      );
      final second = _killmail(
        killmailId: 43,
        killmailTime: DateTime.utc(2026, 5, 20, 20, 1, 20),
        victimCharacterId: 9003,
        attackerCharacterIds: const [9001],
      );

      final result = CombatKillmailMatcher.selectBest(encounter, [
        first,
        second,
      ]);

      expect(result.status, CombatKillmailMatchStatus.ambiguous);
      expect(result.detail, isNull);
      expect(result.candidates, hasLength(2));
    });
  });
}

ParsedCombatEncounter _encounter({required int characterId}) {
  final events = [
    CombatEvent(
      id: 'e1',
      timestamp: DateTime.utc(2026, 5, 20, 20),
      second: 0,
      direction: CombatEventDirection.outgoing,
      kind: CombatEventKind.damage,
      amount: 100,
      targetName: 'Artem S3',
      weaponName: 'Light Neutron Blaster II',
      hitQuality: 'Hits',
      rawLine: '100 to Artem S3 - Light Neutron Blaster II - Hits',
    ),
    CombatEvent(
      id: 'e2',
      timestamp: DateTime.utc(2026, 5, 20, 20, 1),
      second: 60,
      direction: CombatEventDirection.incoming,
      kind: CombatEventKind.damage,
      amount: 200,
      targetName: 'Artem S3',
      weaponName: 'Scourge Rocket',
      hitQuality: 'Hits',
      rawLine: '200 from Artem S3 - Scourge Rocket - Hits',
    ),
  ];
  return ParsedCombatEncounter(
    id: 'encounter-1',
    sourceFilePath: 'combat.txt',
    sourceModified: DateTime.utc(2026, 5, 20, 20, 2),
    sourceSize: 100,
    characterName: 'Metorian Gaterau',
    characterId: characterId,
    startTime: DateTime.utc(2026, 5, 20, 20),
    endTime: DateTime.utc(2026, 5, 20, 20, 1),
    durationSeconds: 60,
    outcome: CombatOutcome.likelyVictory,
    outcomeConfidence: 0.7,
    outcomeEvidence: 'Test encounter',
    events: events,
    aggregates: CombatAggregates(
      totalDamageDealt: 100,
      totalDamageReceived: 200,
      cumulativeDamage: const [],
      damageByTarget: const {'Artem S3': 100},
      damageByWeapon: const {'Light Neutron Blaster II': 100},
      incomingBySource: const {'Artem S3': 200},
      hitQualityCounts: const {'Hits': 1},
      outgoingHitQualityCounts: const {'Hits': 1},
      incomingHitQualityCounts: const {'Hits': 1},
      outgoingHitCount: 1,
      incomingHitCount: 1,
      peakOutgoingHit: 100,
      peakIncomingHit: 200,
      averageOutgoingHit: 100,
      averageIncomingHit: 200,
      missCount: 0,
      idleGapCount: 0,
      ewarEventCount: 0,
    ),
    llmPayloadString: 'test payload',
  );
}

EsiKillmailDetail _killmail({
  required int killmailId,
  required DateTime killmailTime,
  required int victimCharacterId,
  required List<int> attackerCharacterIds,
}) {
  return EsiKillmailDetail(
    killmailId: killmailId,
    killmailTime: killmailTime,
    solarSystemId: 30000142,
    victim: EsiKillmailVictim(
      characterId: victimCharacterId,
      characterName: 'Artem S3',
      corporationId: 98000001,
      allianceId: null,
      shipTypeId: 603,
      damageTaken: 100,
      items: const [],
    ),
    attackers: [
      for (final characterId in attackerCharacterIds)
        EsiKillmailAttacker(
          characterId: characterId,
          characterName: characterId == 9001 ? 'Metorian Gaterau' : 'Other',
          corporationId: 98000002,
          allianceId: null,
          shipTypeId: 602,
          weaponTypeId: 123,
          damageDone: 100,
          finalBlow: characterId == attackerCharacterIds.first,
        ),
    ],
  );
}
