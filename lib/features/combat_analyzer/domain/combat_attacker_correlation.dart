import '../../../core/network/esi_client.dart';

enum CombatActorClass { player, npc, shipType, ambiguous, unnamed }

enum AttackerCorrelationConfidence {
  confirmed,
  probable,
  possible;

  String get label => switch (this) {
    AttackerCorrelationConfidence.confirmed => 'Confirmed',
    AttackerCorrelationConfidence.probable => 'Probable',
    AttackerCorrelationConfidence.possible => 'Possible',
  };
}

enum UncorrelatedReason {
  noLogPresence,
  notOnKillmail,
  belowThreshold,
  ambiguous,
  npcAttacker,
  npcActor,
  unnamed,
  soleAttackerMismatch;

  String get label => switch (this) {
    UncorrelatedReason.noLogPresence => 'not in the combat log',
    UncorrelatedReason.notOnKillmail => 'not on the killmail',
    UncorrelatedReason.belowThreshold => 'below threshold',
    UncorrelatedReason.ambiguous => 'ambiguous',
    UncorrelatedReason.npcAttacker => 'NPC attacker',
    UncorrelatedReason.npcActor => 'NPC',
    UncorrelatedReason.unnamed => 'unnamed',
    UncorrelatedReason.soleAttackerMismatch => 'sole attacker mismatch',
  };
}

enum CorrelationSignal {
  name,
  ship,
  weapon,
  damage,
  timing,
  sole;

  double get weight => AttackerCorrelationRules.weights[this]!;

  String get label => switch (this) {
    CorrelationSignal.name => 'name match',
    CorrelationSignal.ship => 'ship type match',
    CorrelationSignal.weapon => 'weapon type match',
    CorrelationSignal.damage => 'damage proportion',
    CorrelationSignal.timing => 'final blow timing',
    CorrelationSignal.sole => 'sole participant',
  };
}

abstract final class AttackerCorrelationRules {
  static const Map<CorrelationSignal, double> weights = {
    CorrelationSignal.name: 0.75,
    CorrelationSignal.ship: 0.30,
    CorrelationSignal.weapon: 0.20,
    CorrelationSignal.damage: 0.20,
    CorrelationSignal.timing: 0.15,
    CorrelationSignal.sole: 0.10,
  };
  static const double damageHalfWeight = 0.10;
  static const double damageRatioFull = 0.60;
  static const double damageRatioHalf = 0.35;
  static const double confirmedThreshold = 0.75;
  static const double probableThreshold = 0.50;
  static const double possibleThreshold = 0.30;
  static const double ambiguityMargin = 0.10;
  static const int entityCategoryId = 11;
  static const int shipCategoryId = 6;

  static AttackerCorrelationConfidence? bandFor(double score) {
    if (score >= confirmedThreshold) {
      return AttackerCorrelationConfidence.confirmed;
    }
    if (score >= probableThreshold) {
      return AttackerCorrelationConfidence.probable;
    }
    if (score >= possibleThreshold) {
      return AttackerCorrelationConfidence.possible;
    }
    return null;
  }
}

String normalizeCombatName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

class CombatLogActor {
  const CombatLogActor({
    required this.displayName,
    required this.actorClass,
    required this.damageDealt,
    this.weaponNames = const [],
    this.firstSeen,
    this.lastSeen,
    this.resolvedTypeId,
    this.resolvedGroupId,
  });

  final String displayName;
  final CombatActorClass actorClass;
  final int damageDealt;
  final List<String> weaponNames;
  final DateTime? firstSeen;
  final DateTime? lastSeen;
  final int? resolvedTypeId;
  final int? resolvedGroupId;

  String get key => normalizeCombatName(displayName);

  bool get isScorable =>
      actorClass == CombatActorClass.player ||
      actorClass == CombatActorClass.ambiguous ||
      actorClass == CombatActorClass.shipType;

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'actorClass': actorClass.name,
    'damageDealt': damageDealt,
    'weaponNames': weaponNames,
    if (firstSeen != null) 'firstSeen': firstSeen!.toUtc().toIso8601String(),
    if (lastSeen != null) 'lastSeen': lastSeen!.toUtc().toIso8601String(),
    if (resolvedTypeId != null) 'resolvedTypeId': resolvedTypeId,
    if (resolvedGroupId != null) 'resolvedGroupId': resolvedGroupId,
  };

  factory CombatLogActor.fromJson(Map<String, dynamic> json) {
    return CombatLogActor(
      displayName: json['displayName']?.toString() ?? '',
      actorClass:
          _enumFromName(
            CombatActorClass.values,
            json['actorClass']?.toString(),
          ) ??
          CombatActorClass.player,
      damageDealt: _intFromJson(json['damageDealt']),
      weaponNames: _stringList(json['weaponNames']),
      firstSeen: DateTime.tryParse(json['firstSeen']?.toString() ?? ''),
      lastSeen: DateTime.tryParse(json['lastSeen']?.toString() ?? ''),
      resolvedTypeId: _nullableInt(json['resolvedTypeId']),
      resolvedGroupId: _nullableInt(json['resolvedGroupId']),
    );
  }
}

class CombatKillmailParticipant {
  const CombatKillmailParticipant({
    required this.key,
    this.characterId,
    this.characterName,
    this.shipTypeId,
    this.shipTypeName,
    this.weaponTypeId,
    this.weaponGroupId,
    this.damageDone,
    required this.finalBlow,
    required this.isVictim,
    this.factionId,
  });

  final String key;
  final int? characterId;
  final String? characterName;
  final int? shipTypeId;
  final String? shipTypeName;
  final int? weaponTypeId;
  final int? weaponGroupId;
  final int? damageDone;
  final bool finalBlow;
  final bool isVictim;
  final int? factionId;

  bool get isPlayer => characterId != null;

  factory CombatKillmailParticipant.fromAttacker(
    EsiKillmailAttacker attacker,
    int index, {
    String? shipTypeName,
    int? weaponGroupId,
    int? factionId,
  }) {
    return CombatKillmailParticipant(
      key: 'a$index',
      characterId: attacker.characterId,
      characterName: attacker.characterName,
      shipTypeId: attacker.shipTypeId,
      shipTypeName: shipTypeName,
      weaponTypeId: attacker.weaponTypeId,
      weaponGroupId: weaponGroupId,
      damageDone: attacker.damageDone,
      finalBlow: attacker.finalBlow,
      isVictim: false,
      factionId: factionId,
    );
  }

  factory CombatKillmailParticipant.fromVictim(
    EsiKillmailVictim victim, {
    String? shipTypeName,
  }) {
    return CombatKillmailParticipant(
      key: 'v',
      characterId: victim.characterId,
      characterName: victim.characterName,
      shipTypeId: victim.shipTypeId,
      shipTypeName: shipTypeName,
      damageDone: null,
      finalBlow: false,
      isVictim: true,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    if (characterId != null) 'characterId': characterId,
    if (characterName != null) 'characterName': characterName,
    if (shipTypeId != null) 'shipTypeId': shipTypeId,
    if (shipTypeName != null) 'shipTypeName': shipTypeName,
    if (weaponTypeId != null) 'weaponTypeId': weaponTypeId,
    if (weaponGroupId != null) 'weaponGroupId': weaponGroupId,
    if (damageDone != null) 'damageDone': damageDone,
    'finalBlow': finalBlow,
    'isVictim': isVictim,
    if (factionId != null) 'factionId': factionId,
  };

  factory CombatKillmailParticipant.fromJson(Map<String, dynamic> json) {
    return CombatKillmailParticipant(
      key: json['key']?.toString() ?? '',
      characterId: _nullableInt(json['characterId']),
      characterName: json['characterName']?.toString(),
      shipTypeId: _nullableInt(json['shipTypeId']),
      shipTypeName: json['shipTypeName']?.toString(),
      weaponTypeId: _nullableInt(json['weaponTypeId']),
      weaponGroupId: _nullableInt(json['weaponGroupId']),
      damageDone: _nullableInt(json['damageDone']),
      finalBlow: json['finalBlow'] == true,
      isVictim: json['isVictim'] == true,
      factionId: _nullableInt(json['factionId']),
    );
  }
}

class CorrelatedAttacker {
  const CorrelatedAttacker({
    required this.actor,
    required this.participant,
    required this.confidence,
    required this.score,
    required this.signals,
  });

  final CombatLogActor actor;
  final CombatKillmailParticipant participant;
  final AttackerCorrelationConfidence confidence;
  final double score;
  final List<CorrelationSignal> signals;

  List<String> get signalLabels =>
      signals.map((signal) => signal.label).toList();

  Map<String, dynamic> toJson() => {
    'actor': actor.toJson(),
    'participant': participant.toJson(),
    'confidence': confidence.name,
    'score': score,
    'signals': signals.map((signal) => signal.name).toList(),
  };

  static CorrelatedAttacker? tryFromJson(Map<String, dynamic> json) {
    final actorJson = json['actor'];
    final participantJson = json['participant'];
    if (actorJson is! Map || participantJson is! Map) return null;
    final confidence = _enumFromName(
      AttackerCorrelationConfidence.values,
      json['confidence']?.toString(),
    );
    if (confidence == null) return null;
    final signals = <CorrelationSignal>[];
    final rawSignals = json['signals'];
    if (rawSignals is List) {
      for (final item in rawSignals) {
        final signal = _enumFromName(
          CorrelationSignal.values,
          item?.toString(),
        );
        if (signal != null) signals.add(signal);
      }
    }
    return CorrelatedAttacker(
      actor: CombatLogActor.fromJson(Map<String, dynamic>.from(actorJson)),
      participant: CombatKillmailParticipant.fromJson(
        Map<String, dynamic>.from(participantJson),
      ),
      confidence: confidence,
      score: _doubleFromJson(json['score']),
      signals: signals,
    );
  }
}

class AttackerCorrelation {
  const AttackerCorrelation({
    required this.killmailId,
    required this.selfIsVictim,
    required this.correlated,
    required this.unattributedActors,
    required this.uncorrelatedParticipants,
    required this.correlatedIncomingDamage,
    required this.unattributedIncomingDamage,
    required this.npcIncomingDamage,
    required this.totalIncomingDamage,
    required this.reasons,
    required this.correlatedAt,
    this.rulesVersion = 1,
  });

  final int killmailId;
  final bool selfIsVictim;
  final List<CorrelatedAttacker> correlated;
  final List<CombatLogActor> unattributedActors;
  final List<CombatKillmailParticipant> uncorrelatedParticipants;
  final int correlatedIncomingDamage;
  final int unattributedIncomingDamage;
  final int npcIncomingDamage;
  final int totalIncomingDamage;
  final Map<String, UncorrelatedReason> reasons;
  final DateTime correlatedAt;
  final int rulesVersion;

  bool get accountsForAllDamage =>
      correlatedIncomingDamage +
          unattributedIncomingDamage +
          npcIncomingDamage ==
      totalIncomingDamage;

  List<CombatKillmailParticipant> get uncorrelatedPlayerParticipants => [
    for (final participant in uncorrelatedParticipants)
      if (participant.isPlayer) participant,
  ];

  List<CombatKillmailParticipant> get npcParticipants => [
    for (final participant in uncorrelatedParticipants)
      if (!participant.isPlayer) participant,
  ];

  int get identifiedCount => correlated.length;

  String get summaryLine {
    final buffer = StringBuffer(
      '$identifiedCount identified · ${unattributedActors.length} unattributed',
    );
    if (npcIncomingDamage > 0) {
      buffer.write(' · ${_comma(npcIncomingDamage)} NPC');
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
    'killmailId': killmailId,
    'selfIsVictim': selfIsVictim,
    'rulesVersion': rulesVersion,
    'correlated': correlated.map((row) => row.toJson()).toList(),
    'unattributedActors': unattributedActors
        .map((actor) => actor.toJson())
        .toList(),
    'uncorrelatedParticipants': uncorrelatedParticipants
        .map((participant) => participant.toJson())
        .toList(),
    'correlatedIncomingDamage': correlatedIncomingDamage,
    'unattributedIncomingDamage': unattributedIncomingDamage,
    'npcIncomingDamage': npcIncomingDamage,
    'totalIncomingDamage': totalIncomingDamage,
    'reasons': {
      for (final entry in reasons.entries) entry.key: entry.value.name,
    },
    'correlatedAt': correlatedAt.toUtc().toIso8601String(),
  };

  static AttackerCorrelation? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final killmailId = _nullableInt(map['killmailId']);
    if (killmailId == null) return null;
    final correlated = <CorrelatedAttacker>[];
    final rawCorrelated = map['correlated'];
    if (rawCorrelated is List) {
      for (final item in rawCorrelated) {
        if (item is! Map) continue;
        final row = CorrelatedAttacker.tryFromJson(
          Map<String, dynamic>.from(item),
        );
        if (row != null) correlated.add(row);
      }
    }
    final unattributed = <CombatLogActor>[];
    final rawActors = map['unattributedActors'];
    if (rawActors is List) {
      for (final item in rawActors) {
        if (item is Map) {
          unattributed.add(
            CombatLogActor.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    final uncorrelated = <CombatKillmailParticipant>[];
    final rawParticipants = map['uncorrelatedParticipants'];
    if (rawParticipants is List) {
      for (final item in rawParticipants) {
        if (item is Map) {
          uncorrelated.add(
            CombatKillmailParticipant.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    final reasons = <String, UncorrelatedReason>{};
    final rawReasons = map['reasons'];
    if (rawReasons is Map) {
      for (final entry in rawReasons.entries) {
        final reason = _enumFromName(
          UncorrelatedReason.values,
          entry.value?.toString(),
        );
        if (reason != null) reasons[entry.key.toString()] = reason;
      }
    }
    return AttackerCorrelation(
      killmailId: killmailId,
      selfIsVictim: map['selfIsVictim'] == true,
      correlated: correlated,
      unattributedActors: unattributed,
      uncorrelatedParticipants: uncorrelated,
      correlatedIncomingDamage: _intFromJson(map['correlatedIncomingDamage']),
      unattributedIncomingDamage: _intFromJson(
        map['unattributedIncomingDamage'],
      ),
      npcIncomingDamage: _intFromJson(map['npcIncomingDamage']),
      totalIncomingDamage: _intFromJson(map['totalIncomingDamage']),
      reasons: reasons,
      correlatedAt:
          DateTime.tryParse(map['correlatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      rulesVersion: _intFromJson(map['rulesVersion'], fallback: 1),
    );
  }

  Map<String, dynamic> toPromptJson() => {
    'selfIsVictim': selfIsVictim,
    'correlated': [
      for (final row in correlated)
        {
          'actor': row.actor.displayName,
          'characterId': row.participant.characterId,
          'shipTypeId': row.participant.shipTypeId,
          'damage': row.actor.damageDealt,
          'confidence': row.confidence.name,
          'signals': row.signalLabels,
        },
    ],
    'unattributedIncomingDamage': unattributedIncomingDamage,
    'npcIncomingDamage': npcIncomingDamage,
    'uncorrelatedAttackerCount': uncorrelatedPlayerParticipants.length,
    'uncorrelatedAttackers': [
      for (final participant in uncorrelatedPlayerParticipants)
        {
          'characterId': participant.characterId,
          'shipTypeId': participant.shipTypeId,
          'damageDone': participant.damageDone,
        },
    ],
  };
}

T? _enumFromName<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

int _intFromJson(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _doubleFromJson(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) item.toString()];
}

String _comma(int n) {
  final sign = n < 0 ? '-' : '';
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '$sign$buf';
}
