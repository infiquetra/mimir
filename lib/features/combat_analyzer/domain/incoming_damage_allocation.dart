import '../../fitting/domain/damage_pattern.dart';
import 'combat_damage_profile.dart';

enum IncomingDamageType { em, thermal, kinetic, explosive }

enum WeaponResolutionStatus {
  resolved,
  missingName,
  noExactType,
  ambiguousType,
  noPositiveDamage,
  invalidAttributes,
  lookupFailed,
}

final class DamageQuantity implements Comparable<DamageQuantity> {
  factory DamageQuantity(BigInt numerator, BigInt denominator) {
    if (denominator <= BigInt.zero) {
      throw ArgumentError.value(
        denominator,
        'denominator',
        'must be greater than 0',
      );
    }
    if (numerator < BigInt.zero) {
      throw ArgumentError.value(numerator, 'numerator', 'must be >= 0');
    }
    if (numerator == BigInt.zero) {
      return DamageQuantity._(BigInt.zero, BigInt.one);
    }
    final g = numerator.gcd(denominator);
    return DamageQuantity._(numerator ~/ g, denominator ~/ g);
  }

  factory DamageQuantity.fromInt(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'must be >= 0');
    }
    return DamageQuantity(BigInt.from(value), BigInt.one);
  }

  factory DamageQuantity.fromSdeNumber(num value) {
    if (value is int) return DamageQuantity.fromInt(value);
    if (value is! double || value.isNaN || value.isInfinite || value < 0) {
      throw ArgumentError.value(
        value,
        'value',
        'must be a finite non-negative number',
      );
    }
    return DamageQuantity._fromDecimalString(value.toString());
  }

  factory DamageQuantity.fromJson(Map<String, dynamic> json) {
    return DamageQuantity(
      BigInt.parse(json['n']?.toString() ?? '0'),
      BigInt.parse(json['d']?.toString() ?? '1'),
    );
  }

  factory DamageQuantity._fromDecimalString(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty || s == 'nan' || s == 'infinity' || s == '-infinity') {
      throw ArgumentError.value(raw, 'value', 'not a finite decimal');
    }
    var mantissa = s;
    var exponent = 0;
    final eIndex = s.indexOf('e');
    if (eIndex >= 0) {
      mantissa = s.substring(0, eIndex);
      exponent = int.parse(s.substring(eIndex + 1));
    }
    if (mantissa.startsWith('+')) mantissa = mantissa.substring(1);
    if (mantissa.startsWith('-')) {
      throw ArgumentError.value(raw, 'value', 'must be >= 0');
    }
    final dot = mantissa.indexOf('.');
    var digits = mantissa;
    var fracDigits = 0;
    if (dot >= 0) {
      digits = mantissa.substring(0, dot) + mantissa.substring(dot + 1);
      fracDigits = mantissa.length - dot - 1;
    }
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    if (digits.isEmpty) return DamageQuantity.fromInt(0);
    final scale = exponent - fracDigits;
    final n = BigInt.parse(digits);
    if (scale >= 0) {
      return DamageQuantity(n * _pow10(scale), BigInt.one);
    }
    return DamageQuantity(n, _pow10(-scale));
  }

  const DamageQuantity._(this.numerator, this.denominator);

  final BigInt numerator;
  final BigInt denominator;

  bool get isZero => numerator == BigInt.zero;

  DamageQuantity operator +(DamageQuantity other) {
    return DamageQuantity(
      numerator * other.denominator + other.numerator * denominator,
      denominator * other.denominator,
    );
  }

  DamageQuantity operator *(DamageQuantity other) {
    return DamageQuantity(
      numerator * other.numerator,
      denominator * other.denominator,
    );
  }

  DamageQuantity operator /(DamageQuantity other) {
    if (other.numerator == BigInt.zero) {
      throw ArgumentError('division by zero');
    }
    return DamageQuantity(
      numerator * other.denominator,
      denominator * other.numerator,
    );
  }

  @override
  int compareTo(DamageQuantity other) {
    final left = numerator * other.denominator;
    final right = other.numerator * denominator;
    return left.compareTo(right);
  }

  double toFiniteDouble() {
    if (numerator == BigInt.zero) return 0;
    const precision = 18;
    final scale = BigInt.from(10).pow(precision);
    final scaled = (numerator * scale) ~/ denominator;
    if (scaled.bitLength > 1023) return double.maxFinite;
    final value = scaled.toDouble() / scale.toDouble();
    if (!value.isFinite) return double.maxFinite;
    return value;
  }

  Map<String, String> toJson() => {
    'n': numerator.toString(),
    'd': denominator.toString(),
  };

  @override
  bool operator ==(Object other) {
    return other is DamageQuantity &&
        other.numerator == numerator &&
        other.denominator == denominator;
  }

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => '$numerator/$denominator';

  static BigInt _pow10(int exp) {
    var result = BigInt.one;
    final ten = BigInt.from(10);
    for (var i = 0; i < exp; i++) {
      result *= ten;
    }
    return result;
  }
}

final class IncomingDamageVector {
  IncomingDamageVector({
    required this.em,
    required this.thermal,
    required this.kinetic,
    required this.explosive,
  });

  factory IncomingDamageVector.zero() {
    return IncomingDamageVector(
      em: DamageQuantity.fromInt(0),
      thermal: DamageQuantity.fromInt(0),
      kinetic: DamageQuantity.fromInt(0),
      explosive: DamageQuantity.fromInt(0),
    );
  }

  factory IncomingDamageVector.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> asMap(Object? value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return const {'n': '0', 'd': '1'};
    }

    return IncomingDamageVector(
      em: DamageQuantity.fromJson(asMap(json['em'])),
      thermal: DamageQuantity.fromJson(asMap(json['thermal'])),
      kinetic: DamageQuantity.fromJson(asMap(json['kinetic'])),
      explosive: DamageQuantity.fromJson(asMap(json['explosive'])),
    );
  }

  final DamageQuantity em;
  final DamageQuantity thermal;
  final DamageQuantity kinetic;
  final DamageQuantity explosive;

  DamageQuantity operator [](IncomingDamageType type) {
    return switch (type) {
      IncomingDamageType.em => em,
      IncomingDamageType.thermal => thermal,
      IncomingDamageType.kinetic => kinetic,
      IncomingDamageType.explosive => explosive,
    };
  }

  DamageQuantity get total => em + thermal + kinetic + explosive;

  IncomingDamageVector operator +(IncomingDamageVector other) {
    return IncomingDamageVector(
      em: em + other.em,
      thermal: thermal + other.thermal,
      kinetic: kinetic + other.kinetic,
      explosive: explosive + other.explosive,
    );
  }

  DamagePattern? toPattern() {
    if (total.isZero) return null;
    return DamagePattern(
      em: (em / total).toFiniteDouble(),
      thermal: (thermal / total).toFiniteDouble(),
      kinetic: (kinetic / total).toFiniteDouble(),
      explosive: (explosive / total).toFiniteDouble(),
      label: 'SDE-derived incoming',
    );
  }

  Map<IncomingDamageType, int> projectLegacyInts() {
    final k = total.isZero ? 0 : (total.numerator ~/ total.denominator).toInt();
    final floors = <IncomingDamageType, int>{};
    final remainders = <IncomingDamageType, DamageQuantity>{};
    var floorSum = 0;
    for (final type in IncomingDamageType.values) {
      final q = this[type];
      final floor = (q.numerator ~/ q.denominator).toInt();
      floors[type] = floor;
      floorSum += floor;
      remainders[type] = DamageQuantity(
        q.numerator % q.denominator,
        q.denominator,
      );
    }
    var leftover = k - floorSum;
    final ranked = IncomingDamageType.values.toList()
      ..sort((a, b) {
        final byRemainder = remainders[b]!.compareTo(remainders[a]!);
        if (byRemainder != 0) return byRemainder;
        return a.index.compareTo(b.index);
      });
    for (final type in ranked) {
      if (leftover <= 0) break;
      if (remainders[type]!.isZero) continue;
      floors[type] = floors[type]! + 1;
      leftover--;
    }
    for (final type in IncomingDamageType.values) {
      if (leftover <= 0) break;
      floors[type] = floors[type]! + 1;
      leftover--;
    }
    return Map.unmodifiable(floors);
  }

  Map<String, dynamic> toJson() => {
    'em': em.toJson(),
    'thermal': thermal.toJson(),
    'kinetic': kinetic.toJson(),
    'explosive': explosive.toJson(),
  };

  @override
  bool operator ==(Object other) {
    return other is IncomingDamageVector &&
        other.em == em &&
        other.thermal == thermal &&
        other.kinetic == kinetic &&
        other.explosive == explosive;
  }

  @override
  int get hashCode => Object.hash(em, thermal, kinetic, explosive);
}

final class IncomingWeaponResolution {
  const IncomingWeaponResolution({
    required this.normalizedName,
    required this.status,
    this.typeId,
    this.typeName,
    this.attributes,
    this.reasonCode,
  });

  final String normalizedName;
  final int? typeId;
  final String? typeName;
  final WeaponResolutionStatus status;
  final IncomingDamageVector? attributes;
  final String? reasonCode;
}

final class IncomingWeaponContribution {
  IncomingWeaponContribution({
    required this.weaponKey,
    required List<String> rawWeaponNames,
    required List<String> eventIds,
    required this.firstSeen,
    required this.lastSeen,
    required this.loggedDamage,
    required this.resolvedDamage,
    required this.untypedDamage,
    required this.components,
    required this.resolution,
  }) : rawWeaponNames = List.unmodifiable(rawWeaponNames),
       eventIds = List.unmodifiable(eventIds);

  final String weaponKey;
  final List<String> rawWeaponNames;
  final List<String> eventIds;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int loggedDamage;
  final int resolvedDamage;
  final int untypedDamage;
  final IncomingDamageVector components;
  final IncomingWeaponResolution resolution;
}

final class IncomingSourceAllocation {
  IncomingSourceAllocation({
    required this.sourceId,
    required this.rawActorName,
    required this.normalizedActorName,
    required List<String?> observedActorNames,
    required this.loggedDamage,
    required this.resolvedDamage,
    required this.untypedDamage,
    required this.components,
    required List<IncomingWeaponContribution> weapons,
    required this.firstSeen,
    required this.lastSeen,
  }) : observedActorNames = List.unmodifiable(observedActorNames),
       weapons = List.unmodifiable(weapons);

  final String sourceId;
  final String rawActorName;
  final String normalizedActorName;
  final List<String?> observedActorNames;
  final int loggedDamage;
  final int resolvedDamage;
  final int untypedDamage;
  final IncomingDamageVector components;
  final List<IncomingWeaponContribution> weapons;
  final DateTime firstSeen;
  final DateTime lastSeen;
}

final class IncomingDamageAllocation {
  IncomingDamageAllocation({
    required this.encounterId,
    required this.allocationKey,
    required this.sdeContentKey,
    required this.pilotName,
    required this.pilotCharacterId,
    required this.encounterEnd,
    required this.totalIncomingDamage,
    required this.resolvedDamage,
    required this.untypedDamage,
    required this.components,
    required List<IncomingSourceAllocation> sources,
  }) : sources = List.unmodifiable(sources);

  final String encounterId;
  final String allocationKey;
  final String sdeContentKey;
  final String pilotName;
  final int? pilotCharacterId;
  final DateTime encounterEnd;
  final int totalIncomingDamage;
  final int resolvedDamage;
  final int untypedDamage;
  final IncomingDamageVector components;
  final List<IncomingSourceAllocation> sources;

  bool get accountsForAllDamage {
    var logged = 0;
    var resolved = 0;
    var untyped = 0;
    var summed = IncomingDamageVector.zero();
    for (final source in sources) {
      if (source.loggedDamage != source.resolvedDamage + source.untypedDamage) {
        return false;
      }
      if (source.components.total !=
          DamageQuantity.fromInt(source.resolvedDamage)) {
        return false;
      }
      logged += source.loggedDamage;
      resolved += source.resolvedDamage;
      untyped += source.untypedDamage;
      summed += source.components;
    }
    if (logged != totalIncomingDamage) return false;
    if (resolved != resolvedDamage) return false;
    if (untyped != untypedDamage) return false;
    if (summed != components) return false;
    if (components.total != DamageQuantity.fromInt(resolvedDamage)) {
      return false;
    }
    return DamageQuantity.fromInt(resolvedDamage) +
            DamageQuantity.fromInt(untypedDamage) ==
        DamageQuantity.fromInt(totalIncomingDamage);
  }

  CombatDamageProfile toLegacyProfile() {
    final projected = components.projectLegacyInts();
    const labels = {
      IncomingDamageType.em: 'EM',
      IncomingDamageType.thermal: 'Thermal',
      IncomingDamageType.kinetic: 'Kinetic',
      IncomingDamageType.explosive: 'Explosive',
    };
    final entries = <CombatDamageTypeEstimate>[
      for (final type in IncomingDamageType.values)
        if ((projected[type] ?? 0) > 0)
          CombatDamageTypeEstimate(
            type: labels[type]!,
            amount: projected[type]!,
            percent: resolvedDamage == 0
                ? 0
                : projected[type]! / resolvedDamage,
            confidence: CombatDamageConfidence.sdeExact,
            source: 'SDE-derived incoming',
            evidence: 'Exact incoming allocation',
          ),
    ];
    final unknown = <String>{
      for (final source in sources)
        for (final weapon in source.weapons)
          if (weapon.resolution.status != WeaponResolutionStatus.resolved)
            ...weapon.rawWeaponNames,
    };
    return CombatDamageProfile(
      entries: entries,
      unknownWeapons: unknown.toList(),
      totalProfiledDamage: resolvedDamage,
      resolvedWeapons: [
        for (final source in sources)
          for (final weapon in source.weapons)
            if (weapon.resolution.status == WeaponResolutionStatus.resolved)
              weapon.resolution.typeName ?? weapon.weaponKey,
      ],
    );
  }
}

sealed class IncomingAllocationResult {}

final class IncomingAllocationReady extends IncomingAllocationResult {
  IncomingAllocationReady(this.allocation);

  final IncomingDamageAllocation allocation;

  @override
  String toString() => 'IncomingAllocationReady(${allocation.encounterId})';
}

final class IncomingAllocationInvalid extends IncomingAllocationResult {
  IncomingAllocationInvalid({
    required this.encounterId,
    required this.reasonCode,
    this.affectedSourceIds = const [],
  });

  final String encounterId;
  final String reasonCode;
  final List<String> affectedSourceIds;

  @override
  String toString() =>
      'IncomingAllocationInvalid($reasonCode, $encounterId, $affectedSourceIds)';
}
