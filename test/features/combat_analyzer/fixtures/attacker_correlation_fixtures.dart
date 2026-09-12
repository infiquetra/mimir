import 'package:drift/drift.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_actor_classifier.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlator.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';

final now = DateTime.utc(2026, 9, 11, 12);

/// Incoming-only encounter from parser lines: one line per (actor, amount, weapon, second).
ParsedCombatEncounter incomingEncounter(
  List<(String actor, int amount, String weapon, int second)> hits, {
  int? characterId = 42,
  String listener = 'Pilot',
}) {
  final lines = <String>['Listener: $listener'];
  for (final hit in hits) {
    final second = hit.$4.toString().padLeft(2, '0');
    lines.add(
      '[ 2026.05.20 20:00:$second ] (combat) ${hit.$2} from ${hit.$1} - ${hit.$3} - Hits',
    );
  }
  final parsed = CombatLogParser.parseLines(lines).single;
  if (characterId == null) return parsed;
  return parsed.copyWith(characterId: characterId);
}

EsiKillmailAttacker attacker({
  int? characterId,
  String? characterName,
  int? shipTypeId,
  int? weaponTypeId,
  int damageDone = 0,
  bool finalBlow = false,
  int? factionId,
}) {
  return EsiKillmailAttacker(
    characterId: characterId,
    characterName: characterName,
    shipTypeId: shipTypeId,
    weaponTypeId: weaponTypeId,
    damageDone: damageDone,
    finalBlow: finalBlow,
  );
}

EsiKillmailVictim victim({
  int? characterId = 42,
  String? characterName = 'Pilot',
  int shipTypeId = 587,
  int damageTaken = 0,
}) {
  return EsiKillmailVictim(
    characterId: characterId,
    characterName: characterName,
    shipTypeId: shipTypeId,
    damageTaken: damageTaken,
    items: const [],
  );
}

EsiKillmailDetail detail({
  int killmailId = 1234567,
  required EsiKillmailVictim victim,
  required List<EsiKillmailAttacker> attackers,
}) {
  return EsiKillmailDetail(
    killmailId: killmailId,
    killmailTime: DateTime.utc(2026, 5, 20, 20),
    solarSystemId: 30000142,
    victim: victim,
    attackers: attackers,
  );
}

CombatTypeRef ref(int typeId, String name, int groupId, int categoryId) {
  return CombatTypeRef(
    typeId: typeId,
    typeName: name,
    groupId: groupId,
    categoryId: categoryId,
  );
}

/// Hand-built index of ships, the Watchman entity, and weapons.
CombatActorTypeIndex typeIndex() {
  final refs = [
    ref(587, 'Rifter', 25, 6),
    ref(22456, 'Sabre', 541, 6),
    ref(22464, 'Sabre Fleet Issue', 541, 6),
    ref(24702, 'Hurricane', 419, 6),
    ref(34828, 'Jackdaw', 1305, 6),
    ref(30001, 'Serpentis Watchman', 2001, 11),
    ref(2410, 'Heavy Missile', 385, 8),
    ref(2412, 'Light Missile', 385, 8),
    ref(2905, '425mm AutoCannon II', 55, 7),
    ref(2514, 'Scourge Rocket', 384, 8),
  ];
  return CombatActorTypeIndex(
    byName: {for (final type in refs) normalizeCombatName(type.typeName): type},
    byId: {for (final type in refs) type.typeId: type},
  );
}

({ParsedCombatEncounter encounter, EsiKillmailDetail detail}) s1Kill() {
  return (
    encounter: incomingEncounter([('Vex Kalari', 300, 'Scourge Rocket', 4)]),
    detail: detail(
      victim: victim(
        characterId: 7001,
        characterName: 'Vex Kalari',
        shipTypeId: 587,
        damageTaken: 300,
      ),
      attackers: [
        attacker(
          characterId: 42,
          characterName: 'Pilot',
          shipTypeId: 587,
          damageDone: 300,
          finalBlow: true,
        ),
      ],
    ),
  );
}

({ParsedCombatEncounter encounter, EsiKillmailDetail detail}) s2Loss() {
  return (
    encounter: incomingEncounter([
      ('Artem S3', 4200, 'Heavy Missile', 4),
      ('Sabre', 1100, '425mm AutoCannon II', 8),
      ('Kite Mondeo', 3100, 'Light Missile', 12),
    ]),
    detail: detail(
      victim: victim(damageTaken: 8400),
      attackers: [
        attacker(
          characterId: 9001,
          characterName: 'Artem S3',
          shipTypeId: 24702,
          weaponTypeId: 2410,
          damageDone: 4200,
        ),
        attacker(
          characterId: 9002,
          characterName: 'Kite Mondeo',
          shipTypeId: 34828,
          weaponTypeId: 2412,
          damageDone: 3100,
          finalBlow: true,
        ),
        attacker(
          characterId: 9003,
          characterName: 'Dax Rho',
          shipTypeId: 22456,
          weaponTypeId: 2905,
          damageDone: 1250,
        ),
        attacker(
          characterId: 9004,
          characterName: 'Pell Ivo',
          shipTypeId: 24702,
          damageDone: 2000,
        ),
      ],
    ),
  );
}

({ParsedCombatEncounter encounter, EsiKillmailDetail detail}) s3Fleet() {
  return (
    encounter: incomingEncounter([
      ('Alice', 1000, 'Heavy Missile', 4),
      ('Bob', 900, 'Heavy Missile', 8),
      ('Carol', 800, 'Heavy Missile', 12),
      ('Dave', 700, 'Heavy Missile', 16),
      ('Hurricane', 1800, '425mm AutoCannon II', 20),
      ('Jackdaw', 1500, 'Light Missile', 24),
      ('Sabre', 1100, '425mm AutoCannon II', 28),
    ]),
    detail: detail(
      victim: victim(damageTaken: 7800),
      attackers: [
        attacker(
          characterId: 1,
          characterName: 'Alice',
          shipTypeId: 587,
          damageDone: 1000,
        ),
        attacker(
          characterId: 2,
          characterName: 'Bob',
          shipTypeId: 587,
          damageDone: 900,
        ),
        attacker(
          characterId: 3,
          characterName: 'Carol',
          shipTypeId: 587,
          damageDone: 800,
        ),
        attacker(
          characterId: 4,
          characterName: 'Dave',
          shipTypeId: 587,
          damageDone: 700,
        ),
        attacker(
          characterId: 5,
          characterName: 'Eve',
          shipTypeId: 24702,
          damageDone: 2000,
        ),
        attacker(
          characterId: 6,
          characterName: 'Frank',
          shipTypeId: 34828,
          damageDone: 1600,
        ),
        attacker(
          characterId: 7,
          characterName: 'Gina',
          shipTypeId: 22456,
          damageDone: 1250,
        ),
        attacker(
          characterId: 8,
          characterName: 'Hank',
          shipTypeId: 22456,
          damageDone: 1250,
        ),
        attacker(
          characterId: 9,
          characterName: 'Ivy',
          shipTypeId: 587,
          damageDone: 500,
        ),
        attacker(
          characterId: 10,
          characterName: 'Jade',
          shipTypeId: 587,
          damageDone: 400,
        ),
        attacker(
          characterId: 11,
          characterName: 'Kate',
          shipTypeId: 587,
          damageDone: 300,
        ),
        attacker(
          characterId: 12,
          characterName: 'Liam',
          shipTypeId: 587,
          damageDone: 200,
        ),
      ],
    ),
  );
}

({ParsedCombatEncounter encounter, EsiKillmailDetail detail}) s4ThirdParty() {
  return (
    encounter: incomingEncounter([
      ('Artem S3', 4200, 'Heavy Missile', 4),
      ('Kite Mondeo', 1100, 'Light Missile', 8),
    ]),
    detail: detail(
      victim: victim(damageTaken: 5300),
      attackers: [
        attacker(
          characterId: 9001,
          characterName: 'Artem S3',
          shipTypeId: 24702,
          weaponTypeId: 2410,
          damageDone: 4200,
          finalBlow: true,
        ),
      ],
    ),
  );
}

({ParsedCombatEncounter encounter, EsiKillmailDetail detail}) s5NpcMix() {
  return (
    encounter: incomingEncounter([
      ('Artem S3', 3000, 'Heavy Missile', 4),
      ('Serpentis Watchman', 1400, 'Light Missile', 8),
    ]),
    detail: detail(
      victim: victim(damageTaken: 4400),
      attackers: [
        attacker(
          characterId: 9001,
          characterName: 'Artem S3',
          shipTypeId: 24702,
          weaponTypeId: 2410,
          damageDone: 3000,
          finalBlow: true,
        ),
        attacker(shipTypeId: 30001, damageDone: 1400, factionId: 500020),
      ],
    ),
  );
}

AttackerCorrelation correlate(
  ({ParsedCombatEncounter encounter, EsiKillmailDetail detail}) scenario,
) {
  return const CombatAttackerCorrelator().correlate(
    encounter: scenario.encounter,
    detail: scenario.detail,
    typeIndex: typeIndex(),
    now: now,
  );
}

CombatLogActor actor(
  String name, {
  CombatActorClass cls = CombatActorClass.player,
  int damage = 1000,
  List<String> weapons = const [],
  int? typeId,
}) {
  return CombatLogActor(
    displayName: name,
    actorClass: cls,
    damageDealt: damage,
    weaponNames: weapons,
    resolvedTypeId: typeId,
  );
}

CombatKillmailParticipant participant({
  String key = 'a0',
  int? characterId = 9001,
  String? name = 'Artem S3',
  int? shipTypeId = 24702,
  int? weaponTypeId,
  int? weaponGroupId,
  int? damageDone = 1000,
  bool finalBlow = false,
  bool isVictim = false,
}) {
  return CombatKillmailParticipant(
    key: key,
    characterId: characterId,
    characterName: name,
    shipTypeId: shipTypeId,
    weaponTypeId: weaponTypeId,
    weaponGroupId: weaponGroupId,
    damageDone: damageDone,
    finalBlow: finalBlow,
    isVictim: isVictim,
  );
}

CorrelationContext context({
  bool selfIsVictim = true,
  String? lastIncomingActor,
  int playerActorCount = 2,
  int playerParticipantCount = 2,
}) {
  return CorrelationContext(
    selfIsVictim: selfIsVictim,
    lastIncomingActor: lastIncomingActor,
    playerActorCount: playerActorCount,
    playerParticipantCount: playerParticipantCount,
  );
}

/// Seed the in-memory SDE with the §7.0 type index (ships, Watchman, weapons).
Future<void> seedAttackerCorrelationSde(SdeDatabase database) async {
  final refs = typeIndex().byId.values.toList();
  const categoryNames = {6: 'Ship', 7: 'Module', 8: 'Charge', 11: 'Entity'};
  const groupNames = {
    25: 'Frigate',
    541: 'Interdictor',
    419: 'Combat Battlecruiser',
    1305: 'Tactical Destroyer',
    2001: 'Watchman',
    385: 'Missile',
    55: 'Projectile Weapon',
    384: 'Rocket',
  };
  final categories = {for (final ref in refs) ref.categoryId};
  final groups = <int, CombatTypeRef>{for (final ref in refs) ref.groupId: ref};
  await database.upsertCategories([
    for (final id in categories)
      SdeCategoriesCompanion.insert(
        categoryId: Value(id),
        categoryName: categoryNames[id] ?? 'Category $id',
      ),
  ]);
  await database.upsertGroups([
    for (final group in groups.values)
      SdeGroupsCompanion.insert(
        groupId: Value(group.groupId),
        groupName: groupNames[group.groupId] ?? 'Group ${group.groupId}',
        categoryId: group.categoryId,
      ),
  ]);
  await database.upsertTypes([
    for (final ref in refs)
      SdeTypesCompanion.insert(
        typeId: Value(ref.typeId),
        typeName: ref.typeName,
        groupId: ref.groupId,
      ),
  ]);
}

/// S2 killmail as ESI would return it live: ids and damage, no character names.
EsiKillmailDetail unnamedS2Detail({String hash = 'hash-s2'}) {
  final named = s2Loss().detail;
  return EsiKillmailDetail(
    killmailId: named.killmailId,
    killmailHash: hash,
    killmailTime: named.killmailTime,
    solarSystemId: named.solarSystemId,
    victim: EsiKillmailVictim(
      characterId: named.victim.characterId,
      shipTypeId: named.victim.shipTypeId,
      damageTaken: named.victim.damageTaken,
      items: named.victim.items,
    ),
    attackers: [
      for (final attacker in named.attackers)
        EsiKillmailAttacker(
          characterId: attacker.characterId,
          shipTypeId: attacker.shipTypeId,
          weaponTypeId: attacker.weaponTypeId,
          damageDone: attacker.damageDone,
          finalBlow: attacker.finalBlow,
        ),
    ],
  );
}
