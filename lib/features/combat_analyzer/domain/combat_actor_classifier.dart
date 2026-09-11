import '../../../core/logging/logger.dart';
import 'combat_attacker_correlation.dart';
import 'parsed_combat_encounter.dart';

class CombatTypeRef {
  const CombatTypeRef({
    required this.typeId,
    required this.typeName,
    required this.groupId,
    required this.categoryId,
  });

  final int typeId;
  final String typeName;
  final int groupId;
  final int categoryId;
}

class CombatActorTypeIndex {
  const CombatActorTypeIndex({this.byName = const {}, this.byId = const {}});

  final Map<String, CombatTypeRef> byName;
  final Map<int, CombatTypeRef> byId;

  static const empty = CombatActorTypeIndex();
}

class CombatActorClassifier {
  static List<CombatLogActor> classify({
    required ParsedCombatEncounter encounter,
    required List<CombatKillmailParticipant> participants,
    required CombatActorTypeIndex typeIndex,
  }) {
    Log.d(
      'COMBAT.CORRELATE',
      'classify sources=${encounter.aggregates.incomingBySource.length} '
          'participants=${participants.length}',
    );
    final playerNames = <String>{
      for (final participant in participants)
        if (participant.isPlayer && participant.characterName != null)
          normalizeCombatName(participant.characterName!),
    };

    final actors = <CombatLogActor>[];
    for (final entry in encounter.aggregates.incomingBySource.entries) {
      actors.add(
        _actorFor(
          displayName: entry.key,
          damageDealt: entry.value,
          encounter: encounter,
          playerNames: playerNames,
          typeIndex: typeIndex,
        ),
      );
    }
    actors.sort((a, b) {
      final byDamage = b.damageDealt.compareTo(a.damageDealt);
      if (byDamage != 0) return byDamage;
      return a.displayName.compareTo(b.displayName);
    });
    return actors;
  }

  static CombatLogActor _actorFor({
    required String displayName,
    required int damageDealt,
    required ParsedCombatEncounter encounter,
    required Set<String> playerNames,
    required CombatActorTypeIndex typeIndex,
  }) {
    final key = normalizeCombatName(displayName);
    final events = [
      for (final event in encounter.events)
        if (event.isIncomingDamage &&
            normalizeCombatName(event.targetName ?? '') == key)
          event,
    ];
    final weapons = <String>{
      for (final event in events)
        if (event.weaponName != null && event.weaponName!.trim().isNotEmpty)
          event.weaponName!,
    }.toList()..sort();
    DateTime? firstSeen;
    DateTime? lastSeen;
    for (final event in events) {
      if (firstSeen == null || event.timestamp.isBefore(firstSeen)) {
        firstSeen = event.timestamp;
      }
      if (lastSeen == null || event.timestamp.isAfter(lastSeen)) {
        lastSeen = event.timestamp;
      }
    }

    final type = typeIndex.byName[key];
    final actorClass = _classify(key, playerNames, type);
    final resolved =
        actorClass == CombatActorClass.npc ||
        actorClass == CombatActorClass.shipType ||
        actorClass == CombatActorClass.ambiguous;
    return CombatLogActor(
      displayName: displayName,
      actorClass: actorClass,
      damageDealt: damageDealt,
      weaponNames: weapons,
      firstSeen: firstSeen,
      lastSeen: lastSeen,
      resolvedTypeId: resolved ? type?.typeId : null,
      resolvedGroupId: resolved ? type?.groupId : null,
    );
  }

  static CombatActorClass _classify(
    String key,
    Set<String> playerNames,
    CombatTypeRef? type,
  ) {
    if (key.isEmpty || key == 'unknown') return CombatActorClass.unnamed;
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
