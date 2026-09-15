import 'exploration_reference.dart';

/// Raw SDE-shaped wormhole row. Attribute 1382 is minutes in the pinned archive.
class RawWormholeRecord {
  const RawWormholeRecord({
    required this.typeId,
    required this.code,
    required this.name,
    this.published = true,
    this.groupId = 988,
    this.rawTargetClass,
    this.rawTargetDistribution,
    this.rawMaxStableTimeMinutes,
    this.rawTotalMassKg,
    this.rawJumpMassKg,
    this.rawRegenKg,
  });

  final int typeId;
  final String code;
  final String name;
  final bool published;
  final int groupId;
  final int? rawTargetClass;
  final int? rawTargetDistribution;
  final int? rawMaxStableTimeMinutes;
  final double? rawTotalMassKg;
  final double? rawJumpMassKg;
  final double? rawRegenKg;
}

class TypeSearchQuery {
  const TypeSearchQuery({
    this.text = '',
    this.destinationLabel,
    this.rawTargetClass,
    this.capitalOnly = false,
    this.minJumpMassKg,
    this.requireStatic = false,
  });

  final String text;
  final String? destinationLabel;
  final int? rawTargetClass;
  final bool capitalOnly;
  final double? minJumpMassKg;
  final bool requireStatic;
}

/// Projects SDE wormhole rows, groups variants, and applies F1/F2 reference rules.
class ReferenceDeriver {
  const ReferenceDeriver();

  /// Keep unpublished types (K162). Never coerce missing dogma to zero.
  WormholeTypeReference? project(RawWormholeRecord row) {
    return WormholeTypeReference.fromRaw(
      typeId: row.typeId,
      code: row.code,
      name: row.name,
      rawTargetClass: row.rawTargetClass,
      rawTargetDistribution: row.rawTargetDistribution,
      rawMaxStableTimeMinutes: row.rawMaxStableTimeMinutes,
      rawTotalMassKg: row.rawTotalMassKg,
      rawJumpMassKg: row.rawJumpMassKg,
      rawRegenKg: row.rawRegenKg,
    );
  }

  List<WormholeTypeReference> projectCatalog(List<RawWormholeRecord> rows) {
    return [for (final row in rows) ?project(row)];
  }

  List<WormholeCodeGroup> groupByCode(List<WormholeTypeReference> types) {
    final byCode = <String, List<WormholeTypeReference>>{};
    for (final type in types) {
      byCode.putIfAbsent(type.code, () => []).add(type);
    }
    return [
      for (final variants in byCode.values)
        WormholeCodeGroup.fromVariants(variants),
    ];
  }

  List<WormholeCodeGroup> search(
    List<WormholeTypeReference> catalog,
    TypeSearchQuery query,
  ) {
    final hits = <WormholeCodeGroup>[];
    for (final group in groupByCode(catalog)) {
      final matching = [
        for (final type in group.variants)
          if (_typeMatches(type, query)) type,
      ];
      if (matching.isEmpty) continue;
      hits.add(WormholeCodeGroup.fromVariants(matching));
    }
    final needle = query.text.trim();
    if (needle.isEmpty) return hits;
    hits.sort((a, b) {
      final rank = _textRank(a, needle).compareTo(_textRank(b, needle));
      if (rank != 0) return rank;
      return a.code.compareTo(b.code);
    });
    return hits;
  }

  bool _typeMatches(WormholeTypeReference type, TypeSearchQuery query) {
    final needle = query.text.trim();
    if (needle.isNotEmpty) {
      final lower = needle.toLowerCase();
      final haystacks = [type.code, type.name, type.destinationLabel];
      final textOk = haystacks.any(
        (value) => value.toLowerCase().contains(lower),
      );
      if (!textOk) return false;
    }
    if (query.destinationLabel != null &&
        type.destinationLabel != query.destinationLabel) {
      return false;
    }
    if (query.rawTargetClass != null &&
        type.rawTargetClass != query.rawTargetClass) {
      return false;
    }
    if (query.minJumpMassKg != null) {
      final mass = type.maxJumpMassKg;
      if (mass == null || mass < query.minJumpMassKg!) return false;
    }
    if (query.capitalOnly && !type.isCapitalSize) return false;
    if (query.requireStatic) return false;
    return true;
  }

  int _textRank(WormholeCodeGroup group, String needle) {
    final lower = needle.toLowerCase();
    var best = 3;
    for (final type in group.variants) {
      for (final field in [type.code, type.name, type.destinationLabel]) {
        final value = field.toLowerCase();
        if (value == lower) {
          best = 0;
        } else if (value.startsWith(lower) && best > 1) {
          best = 1;
        } else if (value.contains(lower) && best > 2) {
          best = 2;
        }
      }
    }
    return best;
  }

  int? inheritClass({int? system, int? constellation, int? region}) {
    return system ?? constellation ?? region;
  }

  SystemEffect effectForSystem(SystemReference system) {
    final beacon = system.effectBeaconTypeId;
    final visual = system.visualSunTypeId;
    if (beacon == null && visual == null) {
      return SystemEffect.resolve(
        beaconTypeId: null,
        visualSunTypeId: visual,
        dataMissing: true,
      );
    }
    return SystemEffect.resolve(
      beaconTypeId: beacon ?? visual,
      visualSunTypeId: visual,
    );
  }

  SecurityCategory farSideCategory(int? rawTargetClass) {
    if (rawTargetClass == null) return SecurityCategory.unknown;
    return switch (rawTargetClass) {
      7 => SecurityCategory.highsec,
      8 => SecurityCategory.lowsec,
      9 => SecurityCategory.nullsec,
      12 || 13 || 25 => SecurityCategory.special,
      _ when rawTargetClass >= 1 && rawTargetClass <= 6 =>
        SecurityCategory.special,
      _ when rawTargetClass >= 14 && rawTargetClass <= 18 =>
        SecurityCategory.special,
      _ => SecurityCategory.unknown,
    };
  }

  static const staticsUnavailable = 'Static information unavailable';

  String staticsDisclosure({
    required bool datasetPresent,
    bool typicalClassOnly = false,
    List<StaticAssignment> assignments = const [],
  }) {
    if (!datasetPresent || typicalClassOnly || assignments.isEmpty) {
      return staticsUnavailable;
    }
    final codes = [
      for (final assignment in assignments)
        if (assignment.code != null && assignment.code!.isNotEmpty)
          assignment.code!,
    ];
    if (codes.isEmpty) return staticsUnavailable;
    return codes.join(', ');
  }

  bool staticsCreateRouteEdge({
    required bool datasetPresent,
    bool typicalClassOnly = false,
  }) {
    if (!datasetPresent) return false;
    if (typicalClassOnly) return false;
    return false;
  }
}

class EffectCatalog {
  const EffectCatalog();

  static const vortonEffectIds = {11946, 11947, 11948, 11953};

  static const plus30 = [30.0, 44.0, 58.0, 72.0, 86.0, 100.0];
  static const plus15 = [15.0, 22.0, 29.0, 36.0, 43.0, 50.0];
  static const minus15 = [-15.0, -22.0, -29.0, -36.0, -43.0, -50.0];
  static const wolfRayetSmall = [60.0, 88.0, 116.0, 144.0, 172.0, 200.0];

  static const beacons = <EffectFamily, List<int>>{
    EffectFamily.pulsar: [30844, 30865, 30866, 30867, 30868, 30869],
    EffectFamily.blackHole: [30845, 30850, 30851, 30852, 30853, 30854],
    EffectFamily.cataclysmicVariable: [
      30846,
      30880,
      30881,
      30884,
      30883,
      30882,
    ],
    EffectFamily.magnetar: [30847, 30860, 30861, 30862, 30863, 30864],
    EffectFamily.redGiant: [30848, 30870, 30871, 30872, 30873, 30874],
    EffectFamily.wolfRayet: [30849, 30875, 30876, 30877, 30878, 30879],
  };

  static const _vectors = <EffectFamily, Map<int, List<double>>>{
    EffectFamily.pulsar: {
      146: plus30,
      652: plus30,
      1465: plus15,
      1466: plus15,
      1467: plus15,
      1468: plus15,
      1500: minus15,
      1966: plus30,
    },
    EffectFamily.blackHole: {
      169: plus15,
      237: plus30,
      1469: plus15,
      1470: plus30,
      1483: plus30,
      1969: minus15,
    },
    EffectFamily.cataclysmicVariable: {
      1495: minus15,
      1496: minus15,
      1497: plus30,
      1498: plus30,
      1499: plus30,
      1500: plus15,
      1840: minus15,
    },
    EffectFamily.magnetar: {
      237: minus15,
      244: minus15,
      1482: plus30,
      1967: plus30,
      1968: minus15,
    },
    EffectFamily.redGiant: {
      1485: plus15,
      1486: plus30,
      1487: plus30,
      1488: plus30,
    },
    EffectFamily.wolfRayet: {
      148: plus30,
      652: minus15,
      1489: plus15,
      1490: plus15,
      1491: plus15,
      1492: plus15,
      1493: wolfRayetSmall,
    },
  };

  List<(EffectFamily family, int strength)> combinations() {
    return [
      for (final family in EffectFamily.values)
        for (var strength = 1; strength <= 6; strength++) (family, strength),
    ];
  }

  double percentChange({
    required EffectFamily family,
    required int strength,
    required int attributeId,
  }) {
    final table = _vectors[family]?[attributeId];
    if (table == null || strength < 1 || strength > table.length) return 0;
    return table[strength - 1];
  }

  Set<int> scopes({required EffectFamily family, required int strength}) {
    if (family == EffectFamily.wolfRayet) return vortonEffectIds;
    return const {};
  }
}
