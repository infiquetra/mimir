enum CombatEventDirection { outgoing, incoming, neutral }

enum CombatEventKind { damage, miss, ewar, other }

enum CombatOutcome { likelyVictory, likelyDefeat, unknown }

class CombatTimelinePoint {
  const CombatTimelinePoint({
    required this.second,
    required this.outgoing,
    required this.incoming,
  });

  final int second;
  final int outgoing;
  final int incoming;

  Map<String, dynamic> toJson() => {
    'second': second,
    'outgoing': outgoing,
    'incoming': incoming,
  };

  factory CombatTimelinePoint.fromJson(Map<String, dynamic> json) {
    return CombatTimelinePoint(
      second: _intFromJson(json['second']),
      outgoing: _intFromJson(json['outgoing']),
      incoming: _intFromJson(json['incoming']),
    );
  }
}

class CombatEvent {
  const CombatEvent({
    required this.id,
    required this.timestamp,
    required this.second,
    required this.direction,
    required this.kind,
    required this.rawLine,
    this.amount = 0,
    this.targetName,
    this.weaponName,
    this.hitQuality,
  });

  final String id;
  final DateTime timestamp;
  final int second;
  final CombatEventDirection direction;
  final CombatEventKind kind;
  final int amount;
  final String? targetName;
  final String? weaponName;
  final String? hitQuality;
  final String rawLine;

  bool get isOutgoingDamage =>
      kind == CombatEventKind.damage &&
      direction == CombatEventDirection.outgoing &&
      amount > 0;

  bool get isIncomingDamage =>
      kind == CombatEventKind.damage &&
      direction == CombatEventDirection.incoming &&
      amount > 0;

  String get compactDescription {
    final directionText = switch (direction) {
      CombatEventDirection.outgoing => 'to',
      CombatEventDirection.incoming => 'from',
      CombatEventDirection.neutral => 'event',
    };
    final target = targetName == null ? '' : ' $directionText $targetName';
    final weapon = weaponName == null ? '' : ' - $weaponName';
    final quality = hitQuality == null ? '' : ' - $hitQuality';
    final prefix = amount > 0 ? '$amount' : kind.name;
    return '[$_timeText] $prefix$target$weapon$quality';
  }

  String get _timeText {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'second': second,
    'direction': direction.name,
    'kind': kind.name,
    'amount': amount,
    if (targetName != null) 'targetName': targetName,
    if (weaponName != null) 'weaponName': weaponName,
    if (hitQuality != null) 'hitQuality': hitQuality,
    'rawLine': rawLine,
  };

  factory CombatEvent.fromJson(Map<String, dynamic> json) {
    return CombatEvent(
      id: json['id']?.toString() ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      second: _intFromJson(json['second']),
      direction: _enumFromName(
        CombatEventDirection.values,
        json['direction']?.toString(),
        CombatEventDirection.neutral,
      ),
      kind: _enumFromName(
        CombatEventKind.values,
        json['kind']?.toString(),
        CombatEventKind.other,
      ),
      amount: _intFromJson(json['amount']),
      targetName: _nullableString(json['targetName']),
      weaponName: _nullableString(json['weaponName']),
      hitQuality: _nullableString(json['hitQuality']),
      rawLine: json['rawLine']?.toString() ?? '',
    );
  }
}

class CombatAggregates {
  const CombatAggregates({
    required this.totalDamageDealt,
    required this.totalDamageReceived,
    required this.cumulativeDamage,
    required this.damageByTarget,
    required this.damageByWeapon,
    required this.incomingBySource,
    required this.hitQualityCounts,
    required this.outgoingHitQualityCounts,
    required this.incomingHitQualityCounts,
    required this.outgoingHitCount,
    required this.incomingHitCount,
    required this.peakOutgoingHit,
    required this.peakIncomingHit,
    required this.averageOutgoingHit,
    required this.averageIncomingHit,
    required this.missCount,
    required this.idleGapCount,
    required this.ewarEventCount,
  });

  final int totalDamageDealt;
  final int totalDamageReceived;
  final List<CombatTimelinePoint> cumulativeDamage;
  final Map<String, int> damageByTarget;
  final Map<String, int> damageByWeapon;
  final Map<String, int> incomingBySource;
  final Map<String, int> hitQualityCounts;
  final Map<String, int> outgoingHitQualityCounts;
  final Map<String, int> incomingHitQualityCounts;
  final int outgoingHitCount;
  final int incomingHitCount;
  final int peakOutgoingHit;
  final int peakIncomingHit;
  final double averageOutgoingHit;
  final double averageIncomingHit;
  final int missCount;
  final int idleGapCount;
  final int ewarEventCount;

  String get primaryTarget => _topKey(damageByTarget);

  String get primaryWeapon => _topKey(damageByWeapon);

  int get outgoingShotCount => outgoingHitCount + missCount;

  double get outgoingHitRate =>
      outgoingShotCount == 0 ? 0 : outgoingHitCount / outgoingShotCount;

  double get outgoingMissRate =>
      outgoingShotCount == 0 ? 0 : missCount / outgoingShotCount;

  double hitQualityRate(String quality) {
    if (outgoingShotCount == 0) return 0;
    final count = outgoingHitQualityCounts[quality] ?? 0;
    return count / outgoingShotCount;
  }

  Map<String, dynamic> toJson() => {
    'totalDamageDealt': totalDamageDealt,
    'totalDamageReceived': totalDamageReceived,
    'cumulativeDamage': cumulativeDamage
        .map((point) => point.toJson())
        .toList(),
    'damageByTarget': damageByTarget,
    'damageByWeapon': damageByWeapon,
    'incomingBySource': incomingBySource,
    'hitQualityCounts': hitQualityCounts,
    'outgoingHitQualityCounts': outgoingHitQualityCounts,
    'incomingHitQualityCounts': incomingHitQualityCounts,
    'outgoingHitCount': outgoingHitCount,
    'incomingHitCount': incomingHitCount,
    'peakOutgoingHit': peakOutgoingHit,
    'peakIncomingHit': peakIncomingHit,
    'averageOutgoingHit': averageOutgoingHit,
    'averageIncomingHit': averageIncomingHit,
    'missCount': missCount,
    'idleGapCount': idleGapCount,
    'ewarEventCount': ewarEventCount,
  };

  factory CombatAggregates.fromJson(Map<String, dynamic> json) {
    final totalDamageDealt = _intFromJson(json['totalDamageDealt']);
    final totalDamageReceived = _intFromJson(json['totalDamageReceived']);
    final hitQualityCounts = _intMapFromJson(json['hitQualityCounts']);
    final outgoingHitQualityCounts = _intMapFromJson(
      json['outgoingHitQualityCounts'],
    );
    final outgoingHitCount = _intFromJson(
      json['outgoingHitCount'],
      fallback: hitQualityCounts.values.fold(0, (sum, count) => sum + count),
    );
    final incomingHitCount = _intFromJson(json['incomingHitCount']);
    return CombatAggregates(
      totalDamageDealt: totalDamageDealt,
      totalDamageReceived: totalDamageReceived,
      cumulativeDamage: _listFromJson(json['cumulativeDamage'])
          .whereType<Map>()
          .map(
            (point) =>
                CombatTimelinePoint.fromJson(Map<String, dynamic>.from(point)),
          )
          .toList(),
      damageByTarget: _intMapFromJson(json['damageByTarget']),
      damageByWeapon: _intMapFromJson(json['damageByWeapon']),
      incomingBySource: _intMapFromJson(json['incomingBySource']),
      hitQualityCounts: hitQualityCounts,
      outgoingHitQualityCounts: outgoingHitQualityCounts.isEmpty
          ? hitQualityCounts
          : outgoingHitQualityCounts,
      incomingHitQualityCounts: _intMapFromJson(
        json['incomingHitQualityCounts'],
      ),
      outgoingHitCount: outgoingHitCount,
      incomingHitCount: incomingHitCount,
      peakOutgoingHit: _intFromJson(json['peakOutgoingHit']),
      peakIncomingHit: _intFromJson(json['peakIncomingHit']),
      averageOutgoingHit: _doubleFromJson(
        json['averageOutgoingHit'],
        fallback: outgoingHitCount == 0
            ? 0
            : totalDamageDealt / outgoingHitCount,
      ),
      averageIncomingHit: _doubleFromJson(
        json['averageIncomingHit'],
        fallback: incomingHitCount == 0
            ? 0
            : totalDamageReceived / incomingHitCount,
      ),
      missCount: _intFromJson(json['missCount']),
      idleGapCount: _intFromJson(json['idleGapCount']),
      ewarEventCount: _intFromJson(json['ewarEventCount']),
    );
  }

  static String _topKey(Map<String, int> values) {
    if (values.isEmpty) return 'Unknown';
    return values.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

class ParsedCombatEncounter {
  const ParsedCombatEncounter({
    required this.id,
    required this.sourceFilePath,
    required this.sourceModified,
    required this.sourceSize,
    required this.characterName,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.outcome,
    required this.outcomeConfidence,
    required this.outcomeEvidence,
    required this.events,
    required this.aggregates,
    required this.llmPayloadString,
    this.characterId,
  });

  final String id;
  final String sourceFilePath;
  final DateTime? sourceModified;
  final int sourceSize;
  final String characterName;
  final int? characterId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final CombatOutcome outcome;
  final double outcomeConfidence;
  final String outcomeEvidence;
  final List<CombatEvent> events;
  final CombatAggregates aggregates;
  final String llmPayloadString;

  int get totalDamageDealt => aggregates.totalDamageDealt;

  int get totalDamageReceived => aggregates.totalDamageReceived;

  String get outcomeLabel => switch (outcome) {
    CombatOutcome.likelyVictory => 'Likely Victory',
    CombatOutcome.likelyDefeat => 'Likely Defeat',
    CombatOutcome.unknown => 'Unknown',
  };

  ParsedCombatEncounter copyWith({
    String? id,
    String? sourceFilePath,
    DateTime? sourceModified,
    int? sourceSize,
    String? characterName,
    int? characterId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    CombatOutcome? outcome,
    double? outcomeConfidence,
    String? outcomeEvidence,
    List<CombatEvent>? events,
    CombatAggregates? aggregates,
    String? llmPayloadString,
  }) {
    return ParsedCombatEncounter(
      id: id ?? this.id,
      sourceFilePath: sourceFilePath ?? this.sourceFilePath,
      sourceModified: sourceModified ?? this.sourceModified,
      sourceSize: sourceSize ?? this.sourceSize,
      characterName: characterName ?? this.characterName,
      characterId: characterId ?? this.characterId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      outcome: outcome ?? this.outcome,
      outcomeConfidence: outcomeConfidence ?? this.outcomeConfidence,
      outcomeEvidence: outcomeEvidence ?? this.outcomeEvidence,
      events: events ?? this.events,
      aggregates: aggregates ?? this.aggregates,
      llmPayloadString: llmPayloadString ?? this.llmPayloadString,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceFilePath': sourceFilePath,
    if (sourceModified != null)
      'sourceModified': sourceModified!.toUtc().toIso8601String(),
    'sourceSize': sourceSize,
    'characterName': characterName,
    if (characterId != null) 'characterId': characterId,
    'startTime': startTime.toUtc().toIso8601String(),
    'endTime': endTime.toUtc().toIso8601String(),
    'durationSeconds': durationSeconds,
    'outcome': outcome.name,
    'outcomeConfidence': outcomeConfidence,
    'outcomeEvidence': outcomeEvidence,
    'events': events.map((event) => event.toJson()).toList(),
    'aggregates': aggregates.toJson(),
    'llmPayloadString': llmPayloadString,
  };

  Map<String, dynamic> toListSummaryJson() => {
    'id': id,
    'characterName': characterName,
    if (characterId != null) 'characterId': characterId,
    'startTime': startTime.toUtc().toIso8601String(),
    'endTime': endTime.toUtc().toIso8601String(),
    'durationSeconds': durationSeconds,
    'outcome': outcome.name,
    'outcomeConfidence': outcomeConfidence,
    'totalDamageDealt': totalDamageDealt,
    'totalDamageReceived': totalDamageReceived,
    'primaryTarget': aggregates.primaryTarget,
    'primaryWeapon': aggregates.primaryWeapon,
  };

  factory ParsedCombatEncounter.fromJson(Map<String, dynamic> json) {
    final aggregatesJson = json['aggregates'];
    final aggregates = aggregatesJson is Map
        ? CombatAggregates.fromJson(Map<String, dynamic>.from(aggregatesJson))
        : CombatAggregates(
            totalDamageDealt: _intFromJson(json['totalDamageDealt']),
            totalDamageReceived: _intFromJson(json['totalDamageReceived']),
            cumulativeDamage: const [],
            damageByTarget: const {},
            damageByWeapon: const {},
            incomingBySource: const {},
            hitQualityCounts: const {},
            outgoingHitQualityCounts: const {},
            incomingHitQualityCounts: const {},
            outgoingHitCount: 0,
            incomingHitCount: 0,
            peakOutgoingHit: 0,
            peakIncomingHit: 0,
            averageOutgoingHit: 0,
            averageIncomingHit: 0,
            missCount: 0,
            idleGapCount: 0,
            ewarEventCount: 0,
          );
    return ParsedCombatEncounter(
      id: json['id']?.toString() ?? '',
      sourceFilePath: json['sourceFilePath']?.toString() ?? '',
      sourceModified: DateTime.tryParse(
        json['sourceModified']?.toString() ?? '',
      ),
      sourceSize: _intFromJson(json['sourceSize']),
      characterName: json['characterName']?.toString() ?? 'Unknown',
      characterId: _nullableInt(json['characterId']),
      startTime:
          DateTime.tryParse(json['startTime']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      endTime:
          DateTime.tryParse(json['endTime']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      durationSeconds: _intFromJson(json['durationSeconds']),
      outcome: _enumFromName(
        CombatOutcome.values,
        json['outcome']?.toString(),
        CombatOutcome.unknown,
      ),
      outcomeConfidence: _doubleFromJson(json['outcomeConfidence']),
      outcomeEvidence: json['outcomeEvidence']?.toString() ?? '',
      events: _listFromJson(json['events'])
          .whereType<Map>()
          .map(
            (event) => CombatEvent.fromJson(Map<String, dynamic>.from(event)),
          )
          .toList(),
      aggregates: aggregates,
      llmPayloadString: json['llmPayloadString']?.toString() ?? '',
    );
  }
}

T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

List<dynamic> _listFromJson(Object? value) => value is List ? value : const [];

Map<String, int> _intMapFromJson(Object? value) {
  if (value is! Map) return const {};
  return value.map(
    (key, value) => MapEntry(key.toString(), _intFromJson(value)),
  );
}

String? _nullableString(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return text;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

int _intFromJson(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _doubleFromJson(Object? value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
