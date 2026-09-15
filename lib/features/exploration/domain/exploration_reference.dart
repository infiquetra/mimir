import 'dart:convert';

import 'package:crypto/crypto.dart';

enum SecurityCategory { highsec, lowsec, nullsec, unknown, special }

enum SystemEffectState { applied, none, unknown }

enum EffectFamily {
  pulsar,
  blackHole,
  cataclysmicVariable,
  magnetar,
  redGiant,
  wolfRayet,
}

class ReferenceManifest {
  ReferenceManifest({
    this.sdeBuild = 0,
    this.datasetSchema = 0,
    List<String> sourceUrls = const [],
    Map<String, String> checksums = const {},
    Map<String, int> rowCounts = const {},
    this.importedAt,
    this.coverage = '',
    this.validation = '',
  }) : sourceUrls = List.unmodifiable(List.of(sourceUrls)),
       checksums = Map.unmodifiable(Map.of(checksums)),
       rowCounts = Map.unmodifiable(Map.of(rowCounts));

  final int sdeBuild;
  final int datasetSchema;
  final List<String> sourceUrls;
  final Map<String, String> checksums;
  final Map<String, int> rowCounts;
  final DateTime? importedAt;
  final String coverage;
  final String validation;

  Map<String, dynamic> toJson() => {
    'sdeBuild': sdeBuild,
    'datasetSchema': datasetSchema,
    'sourceUrls': sourceUrls,
    'checksums': checksums,
    'rowCounts': rowCounts,
    if (importedAt != null) 'importedAt': importedAt!.toIso8601String(),
    'coverage': coverage,
    'validation': validation,
  };

  factory ReferenceManifest.fromJson(Map<String, dynamic> json) {
    return ReferenceManifest(
      sdeBuild: json['sdeBuild'] as int? ?? 0,
      datasetSchema: json['datasetSchema'] as int? ?? 0,
      sourceUrls: [
        for (final value in json['sourceUrls'] as List? ?? const [])
          value.toString(),
      ],
      checksums: {
        for (final entry in (json['checksums'] as Map? ?? const {}).entries)
          entry.key.toString(): entry.value.toString(),
      },
      rowCounts: {
        for (final entry in (json['rowCounts'] as Map? ?? const {}).entries)
          entry.key.toString(): (entry.value as num).toInt(),
      },
      importedAt: json['importedAt'] == null
          ? null
          : DateTime.tryParse(json['importedAt'].toString())?.toUtc(),
      coverage: json['coverage']?.toString() ?? '',
      validation: json['validation']?.toString() ?? '',
    );
  }
}

class WormholeTypeReference {
  WormholeTypeReference({
    required this.typeId,
    required this.code,
    required this.name,
    this.rawTargetClass,
    this.rawTargetDistribution,
    this.reliableLifetimeSeconds,
    this.maxJumpMassKg,
    this.totalMassKg,
    this.regenerationKgPerCycle,
    this.recordedAt,
  });

  final int typeId;
  final String code;
  final String name;
  final int? rawTargetClass;
  final int? rawTargetDistribution;
  final int? reliableLifetimeSeconds;
  final double? maxJumpMassKg;
  final double? totalMassKg;
  final double? regenerationKgPerCycle;
  final DateTime? recordedAt;

  static const capitalJumpThresholdKg = 1000000000.0;

  factory WormholeTypeReference.fromRaw({
    required int typeId,
    required String code,
    required String name,
    int? rawTargetClass,
    int? rawTargetDistribution,
    int? rawMaxStableTimeMinutes,
    double? rawTotalMassKg,
    double? rawJumpMassKg,
    double? rawRegenKg,
    DateTime? recordedAt,
  }) {
    return WormholeTypeReference(
      typeId: typeId,
      code: code,
      name: name,
      rawTargetClass: rawTargetClass,
      rawTargetDistribution: rawTargetDistribution,
      reliableLifetimeSeconds: rawMaxStableTimeMinutes == null
          ? null
          : rawMaxStableTimeMinutes * 60,
      maxJumpMassKg: rawJumpMassKg,
      totalMassKg: rawTotalMassKg,
      regenerationKgPerCycle: rawRegenKg,
      recordedAt: recordedAt,
    );
  }

  String get destinationLabel {
    final target = rawTargetClass;
    if (target == null) return 'Unknown';
    return switch (target) {
      7 => 'Highsec',
      8 => 'Lowsec',
      9 => 'Nullsec',
      12 => 'Thera',
      25 => 'Pochven',
      -1 => 'Varies',
      _ when target >= 1 && target <= 6 => 'C$target',
      _ when target >= 14 && target <= 18 => 'Drifter',
      13 => 'Shattered',
      _ => 'Unknown',
    };
  }

  bool get isCapitalSize =>
      maxJumpMassKg != null && maxJumpMassKg! >= capitalJumpThresholdKg;

  Map<String, dynamic> toJson() => {
    'typeId': typeId,
    'code': code,
    'name': name,
    if (rawTargetClass != null) 'rawTargetClass': rawTargetClass,
    if (rawTargetDistribution != null)
      'rawTargetDistribution': rawTargetDistribution,
    if (reliableLifetimeSeconds != null)
      'reliableLifetimeSeconds': reliableLifetimeSeconds,
    if (maxJumpMassKg != null) 'maxJumpMassKg': maxJumpMassKg,
    if (totalMassKg != null) 'totalMassKg': totalMassKg,
    if (regenerationKgPerCycle != null)
      'regenerationKgPerCycle': regenerationKgPerCycle,
    if (recordedAt != null) 'recordedAt': recordedAt!.toUtc().toIso8601String(),
  };

  factory WormholeTypeReference.fromJson(Map<String, dynamic> json) {
    return WormholeTypeReference(
      typeId: json['typeId'] as int? ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      rawTargetClass: (json['rawTargetClass'] as num?)?.toInt(),
      rawTargetDistribution: (json['rawTargetDistribution'] as num?)?.toInt(),
      reliableLifetimeSeconds: (json['reliableLifetimeSeconds'] as num?)
          ?.toInt(),
      maxJumpMassKg: (json['maxJumpMassKg'] as num?)?.toDouble(),
      totalMassKg: (json['totalMassKg'] as num?)?.toDouble(),
      regenerationKgPerCycle: (json['regenerationKgPerCycle'] as num?)
          ?.toDouble(),
      recordedAt: json['recordedAt'] == null
          ? null
          : DateTime.tryParse(json['recordedAt'].toString())?.toUtc(),
    );
  }

  String get contentFingerprint {
    final payload = {
      'code': code,
      'rawTargetClass': rawTargetClass,
      'rawTargetDistribution': rawTargetDistribution,
      'reliableLifetimeSeconds': reliableLifetimeSeconds,
      'maxJumpMassKg': maxJumpMassKg,
      'totalMassKg': totalMassKg,
      'regenerationKgPerCycle': regenerationKgPerCycle,
    };
    return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
  }

  @override
  bool operator ==(Object other) {
    return other is WormholeTypeReference &&
        typeId == other.typeId &&
        code == other.code &&
        name == other.name &&
        rawTargetClass == other.rawTargetClass &&
        rawTargetDistribution == other.rawTargetDistribution &&
        reliableLifetimeSeconds == other.reliableLifetimeSeconds &&
        maxJumpMassKg == other.maxJumpMassKg &&
        totalMassKg == other.totalMassKg &&
        regenerationKgPerCycle == other.regenerationKgPerCycle &&
        recordedAt == other.recordedAt;
  }

  @override
  int get hashCode => Object.hash(
    typeId,
    code,
    name,
    rawTargetClass,
    rawTargetDistribution,
    reliableLifetimeSeconds,
    maxJumpMassKg,
    totalMassKg,
    regenerationKgPerCycle,
    recordedAt,
  );
}

class WormholeCodeGroup {
  WormholeCodeGroup({
    required this.code,
    required List<WormholeTypeReference> variants,
    this.sharedLifetimeSeconds,
    this.sharedJumpMassKg,
    this.jumpVaries = false,
  }) : variants = List.unmodifiable(List<WormholeTypeReference>.from(variants));

  final String code;
  final List<WormholeTypeReference> variants;
  final int? sharedLifetimeSeconds;
  final double? sharedJumpMassKg;
  final bool jumpVaries;

  factory WormholeCodeGroup.fromVariants(List<WormholeTypeReference> variants) {
    final copy = List<WormholeTypeReference>.from(variants);
    final code = copy.isEmpty ? '' : copy.first.code;
    final lifetimes = {
      for (final variant in copy) variant.reliableLifetimeSeconds,
    };
    final jumps = {for (final variant in copy) variant.maxJumpMassKg};
    final jumpVaries = jumps.length > 1;
    return WormholeCodeGroup(
      code: code,
      variants: copy,
      sharedLifetimeSeconds: lifetimes.length == 1 ? lifetimes.single : null,
      sharedJumpMassKg: jumpVaries
          ? null
          : (jumps.isEmpty ? null : jumps.single),
      jumpVaries: jumpVaries,
    );
  }
}

class SystemReference {
  SystemReference({
    required this.systemId,
    required this.name,
    this.constellationId,
    this.regionId,
    this.constellationName,
    this.regionName,
    this.rawSecurity,
    this.rawClass,
    this.inheritedClass,
    this.inheritanceSource,
    this.effectBeaconTypeId,
    this.visualSunTypeId,
    List<StaticAssignment> statics = const [],
  }) : statics = List.unmodifiable(List<StaticAssignment>.from(statics));

  final int systemId;
  final String name;
  final int? constellationId;
  final int? regionId;
  final String? constellationName;
  final String? regionName;
  final double? rawSecurity;
  final int? rawClass;
  final int? inheritedClass;
  final String? inheritanceSource;
  final int? effectBeaconTypeId;
  final int? visualSunTypeId;
  final List<StaticAssignment> statics;

  SecurityCategory get category {
    if (_isSpecialClass(rawClass)) return SecurityCategory.special;
    return classifySecurity(rawSecurity);
  }

  String get securityDisplay => formatSecurity(rawSecurity);

  static bool _isSpecialClass(int? rawClass) {
    if (rawClass == null) return false;
    if (rawClass >= 1 && rawClass <= 6) return true;
    if (rawClass == 12 || rawClass == 13 || rawClass == 25) return true;
    if (rawClass >= 14 && rawClass <= 18) return true;
    return false;
  }

  static SecurityCategory classifySecurity(double? x) {
    if (x == null) return SecurityCategory.unknown;
    if (x >= 0.45) return SecurityCategory.highsec;
    if (x > 0) return SecurityCategory.lowsec;
    return SecurityCategory.nullsec;
  }

  static String formatSecurity(double? x) {
    if (x == null) return 'Unknown';
    if (x <= 0) return '0.0';
    if (x < 0.05) return '0.1';
    return ((x * 10).round() / 10).toStringAsFixed(1);
  }
}

class StaticAssignment {
  const StaticAssignment({
    required this.systemId,
    this.code,
    this.typeId,
    this.meaning = '',
    this.source = '',
    this.confidence = '',
  });

  final int systemId;
  final String? code;
  final int? typeId;
  final String meaning;
  final String source;
  final String confidence;
}

class EffectModifier {
  const EffectModifier({
    required this.attributeId,
    required this.label,
    required this.percentChange,
    this.scope = '',
  });

  final int attributeId;
  final String label;
  final double percentChange;
  final String scope;
}

class SystemEffect {
  SystemEffect({
    required this.family,
    required this.strength,
    required this.beaconTypeId,
    List<EffectModifier> modifiers = const [],
    this.state = SystemEffectState.applied,
    this.visualSunTypeId,
  }) : modifiers = List.unmodifiable(List<EffectModifier>.from(modifiers));

  final EffectFamily family;
  final int strength;
  final int beaconTypeId;
  final List<EffectModifier> modifiers;
  final SystemEffectState state;
  final int? visualSunTypeId;

  static const _pulsarShield = [30.0, 44.0, 58.0, 72.0, 86.0, 100.0];
  static const _magnetarExplosion = [30.0, 44.0, 58.0, 72.0, 86.0, 100.0];
  static const _wolfRayetSmall = [60.0, 88.0, 116.0, 144.0, 172.0, 200.0];
  static const _pulsarCapRecharge = [-15.0, -22.0, -29.0, -36.0, -43.0, -50.0];

  static const _beaconIndex = <int, (EffectFamily, int)>{
    30844: (EffectFamily.pulsar, 1),
    30865: (EffectFamily.pulsar, 2),
    30866: (EffectFamily.pulsar, 3),
    30867: (EffectFamily.pulsar, 4),
    30868: (EffectFamily.pulsar, 5),
    30869: (EffectFamily.pulsar, 6),
    30845: (EffectFamily.blackHole, 1),
    30850: (EffectFamily.blackHole, 2),
    30851: (EffectFamily.blackHole, 3),
    30852: (EffectFamily.blackHole, 4),
    30853: (EffectFamily.blackHole, 5),
    30854: (EffectFamily.blackHole, 6),
    30846: (EffectFamily.cataclysmicVariable, 1),
    30880: (EffectFamily.cataclysmicVariable, 2),
    30881: (EffectFamily.cataclysmicVariable, 3),
    30884: (EffectFamily.cataclysmicVariable, 4),
    30883: (EffectFamily.cataclysmicVariable, 5),
    30882: (EffectFamily.cataclysmicVariable, 6),
    30847: (EffectFamily.magnetar, 1),
    30860: (EffectFamily.magnetar, 2),
    30861: (EffectFamily.magnetar, 3),
    30862: (EffectFamily.magnetar, 4),
    30863: (EffectFamily.magnetar, 5),
    30864: (EffectFamily.magnetar, 6),
    30848: (EffectFamily.redGiant, 1),
    30870: (EffectFamily.redGiant, 2),
    30871: (EffectFamily.redGiant, 3),
    30872: (EffectFamily.redGiant, 4),
    30873: (EffectFamily.redGiant, 5),
    30874: (EffectFamily.redGiant, 6),
    30849: (EffectFamily.wolfRayet, 1),
    30875: (EffectFamily.wolfRayet, 2),
    30876: (EffectFamily.wolfRayet, 3),
    30877: (EffectFamily.wolfRayet, 4),
    30878: (EffectFamily.wolfRayet, 5),
    30879: (EffectFamily.wolfRayet, 6),
  };

  factory SystemEffect.resolve({
    required int? beaconTypeId,
    int? visualSunTypeId,
    bool verifiedAbsent = false,
    bool dataMissing = false,
  }) {
    if (dataMissing) {
      return SystemEffect(
        family: EffectFamily.pulsar,
        strength: 1,
        beaconTypeId: beaconTypeId ?? 0,
        state: SystemEffectState.unknown,
        visualSunTypeId: visualSunTypeId,
      );
    }
    if (verifiedAbsent || beaconTypeId == null) {
      return SystemEffect(
        family: EffectFamily.pulsar,
        strength: 1,
        beaconTypeId: beaconTypeId ?? 0,
        state: SystemEffectState.none,
        visualSunTypeId: visualSunTypeId,
      );
    }
    return SystemEffect(
      family: familyForBeacon(beaconTypeId),
      strength: strengthForBeacon(beaconTypeId),
      beaconTypeId: beaconTypeId,
      visualSunTypeId: visualSunTypeId,
    );
  }

  static EffectFamily familyForBeacon(int beaconTypeId) {
    return _beaconIndex[beaconTypeId]?.$1 ?? EffectFamily.pulsar;
  }

  static int strengthForBeacon(int beaconTypeId) {
    return _beaconIndex[beaconTypeId]?.$2 ?? 1;
  }

  static double pulsarShieldPercent(int strength) =>
      _atStrength(_pulsarShield, strength);

  static double magnetarExplosionRadiusFrom100(int strength) =>
      100 + _atStrength(_magnetarExplosion, strength);

  static double wolfRayetSmallWeaponFrom100(int strength) =>
      100 + _atStrength(_wolfRayetSmall, strength);

  static double pulsarCapRechargeFrom100(int strength) =>
      100 + _atStrength(_pulsarCapRecharge, strength);

  static double applyResonance({
    required double oldResist,
    required double percentIncrease,
  }) {
    final oldResonance = 1 - oldResist;
    final newResonance = oldResonance * (1 + percentIncrease / 100);
    return 1 - newResonance;
  }

  static double _atStrength(List<double> table, int strength) {
    if (strength < 1 || strength > table.length) return 0;
    return table[strength - 1];
  }
}

class GateEdge {
  GateEdge({
    required this.gateId,
    required this.fromSystemId,
    required this.toSystemId,
    this.topologyVersion = 0,
    List<String> restrictions = const [],
  }) : restrictions = List.unmodifiable(List<String>.from(restrictions));

  final int gateId;
  final int fromSystemId;
  final int toSystemId;
  final int topologyVersion;
  final List<String> restrictions;
}

class UniverseTopology {
  UniverseTopology({List<GateEdge> gates = const [], this.manifest})
    : gates = List.unmodifiable(List<GateEdge>.from(gates));

  final List<GateEdge> gates;
  final ReferenceManifest? manifest;
}
