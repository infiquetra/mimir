import 'package:collection/collection.dart';

/// Represents a killmail received from zKillboard
class ZKillmail {
  final int killmailId;
  final DateTime killmailTime;
  final int solarSystemId;
  final String? solarSystemName;
  final KillmailVictim victim;
  final List<KillmailAttacker> attackers;
  final double totalValue;
  final ZkbInfo zkbInfo;

  ZKillmail({
    required this.killmailId,
    required this.killmailTime,
    required this.solarSystemId,
    this.solarSystemName,
    required this.victim,
    required this.attackers,
    required this.totalValue,
    required this.zkbInfo,
  });

  int get attackerCount => attackers.length;
  bool get isSoloKill => attackerCount == 1;
  int? get finalBlowAttackerId =>
      attackers.firstWhereOrNull((a) => a.finalBlow)?.characterId;

  factory ZKillmail.fromJson(Map<String, dynamic> json) {
    final killmail = json['killmail'] ?? {};
    final zkb = json['zkb'] ?? {};

    return ZKillmail(
      killmailId: killmail['killmail_id'] ?? 0,
      killmailTime: DateTime.parse(killmail['killmail_time'] ?? DateTime.now().toIso8601String()),
      solarSystemId: killmail['solar_system_id'] ?? 0,
      victim: KillmailVictim.fromJson(killmail['victim'] ?? {}),
      attackers: (killmail['attackers'] as List?)
              ?.map((a) => KillmailAttacker.fromJson(a))
              .toList() ??
          [],
      totalValue: (zkb['totalValue'] as num?)?.toDouble() ?? 0.0,
      zkbInfo: ZkbInfo.fromJson(zkb),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'killmail': {
        'killmail_id': killmailId,
        'killmail_time': killmailTime.toIso8601String(),
        'solar_system_id': solarSystemId,
        'victim': victim.toJson(),
        'attackers': attackers.map((a) => a.toJson()).toList(),
      },
      'zkb': zkbInfo.toJson(),
    };
  }
}

class KillmailVictim {
  final int? characterId;
  final String? characterName;
  final int? corporationId;
  final String? corporationName;
  final int? allianceId;
  final String? allianceName;
  final int shipTypeId;
  final String? shipTypeName;
  final double damageTaken;

  KillmailVictim({
    this.characterId,
    this.characterName,
    this.corporationId,
    this.corporationName,
    this.allianceId,
    this.allianceName,
    required this.shipTypeId,
    this.shipTypeName,
    required this.damageTaken,
  });

  factory KillmailVictim.fromJson(Map<String, dynamic> json) {
    return KillmailVictim(
      characterId: json['character_id'],
      corporationId: json['corporation_id'],
      allianceId: json['alliance_id'],
      shipTypeId: json['ship_type_id'] ?? 0,
      damageTaken: (json['damage_taken'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (characterId != null) 'character_id': characterId,
      if (corporationId != null) 'corporation_id': corporationId,
      if (allianceId != null) 'alliance_id': allianceId,
      'ship_type_id': shipTypeId,
      'damage_taken': damageTaken,
    };
  }
}

class KillmailAttacker {
  final int? characterId;
  final String? characterName;
  final int? corporationId;
  final int? allianceId;
  final int? shipTypeId;
  final String? shipTypeName;
  final int? weaponTypeId;
  final double damageDone;
  final bool finalBlow;

  KillmailAttacker({
    this.characterId,
    this.characterName,
    this.corporationId,
    this.allianceId,
    this.shipTypeId,
    this.shipTypeName,
    this.weaponTypeId,
    required this.damageDone,
    required this.finalBlow,
  });

  factory KillmailAttacker.fromJson(Map<String, dynamic> json) {
    return KillmailAttacker(
      characterId: json['character_id'],
      corporationId: json['corporation_id'],
      allianceId: json['alliance_id'],
      shipTypeId: json['ship_type_id'],
      weaponTypeId: json['weapon_type_id'],
      damageDone: (json['damage_done'] as num?)?.toDouble() ?? 0.0,
      finalBlow: json['final_blow'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (characterId != null) 'character_id': characterId,
      if (corporationId != null) 'corporation_id': corporationId,
      if (allianceId != null) 'alliance_id': allianceId,
      if (shipTypeId != null) 'ship_type_id': shipTypeId,
      if (weaponTypeId != null) 'weapon_type_id': weaponTypeId,
      'damage_done': damageDone,
      'final_blow': finalBlow,
    };
  }
}

class ZkbInfo {
  final int locationId;
  final String hash;
  final double fittedValue;
  final double droppedValue;
  final double destroyedValue;
  final double totalValue;
  final int points;
  final bool npc;
  final bool solo;
  final bool awox;

  ZkbInfo({
    required this.locationId,
    required this.hash,
    required this.fittedValue,
    required this.droppedValue,
    required this.destroyedValue,
    required this.totalValue,
    required this.points,
    required this.npc,
    required this.solo,
    required this.awox,
  });

  factory ZkbInfo.fromJson(Map<String, dynamic> json) {
    return ZkbInfo(
      locationId: json['locationID'] ?? 0,
      hash: json['hash'] ?? '',
      fittedValue: (json['fittedValue'] as num?)?.toDouble() ?? 0.0,
      droppedValue: (json['droppedValue'] as num?)?.toDouble() ?? 0.0,
      destroyedValue: (json['destroyedValue'] as num?)?.toDouble() ?? 0.0,
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0.0,
      points: json['points'] ?? 0,
      npc: json['npc'] ?? false,
      solo: json['solo'] ?? false,
      awox: json['awox'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'locationID': locationId,
      'hash': hash,
      'fittedValue': fittedValue,
      'droppedValue': droppedValue,
      'destroyedValue': destroyedValue,
      'totalValue': totalValue,
      'points': points,
      'npc': npc,
      'solo': solo,
      'awox': awox,
    };
  }
}
