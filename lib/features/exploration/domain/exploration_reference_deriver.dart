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

/// Naive X1 deriver: published-only, no minute conversion, last-code wins,
/// visual-sun effect, region-first inheritance, invented typical statics.
class ReferenceDeriver {
  const ReferenceDeriver();

  static const publishedTypeIdCeiling = 91000;

  WormholeTypeReference? project(RawWormholeRecord row) {
    if (!row.published || row.typeId >= publishedTypeIdCeiling) {
      return null;
    }
    return WormholeTypeReference(
      typeId: row.typeId,
      code: row.code,
      name: row.name,
      rawTargetClass: row.rawTargetClass,
      rawTargetDistribution: row.rawTargetDistribution,
      reliableLifetimeSeconds: row.rawMaxStableTimeMinutes ?? 0,
      maxJumpMassKg: row.rawJumpMassKg ?? 0,
      totalMassKg: row.rawTotalMassKg ?? 0,
      regenerationKgPerCycle: row.rawRegenKg ?? 0,
    );
  }

  List<WormholeTypeReference> projectCatalog(List<RawWormholeRecord> rows) {
    return [for (final row in rows) ?project(row)];
  }

  List<WormholeCodeGroup> groupByCode(List<WormholeTypeReference> types) {
    final lastByCode = <String, WormholeTypeReference>{};
    for (final type in types) {
      lastByCode[type.code] = type;
    }
    return [
      for (final type in lastByCode.values)
        WormholeCodeGroup.fromVariants([type]),
    ];
  }

  List<WormholeCodeGroup> search(
    List<WormholeTypeReference> catalog,
    TypeSearchQuery query,
  ) {
    final groups = groupByCode(catalog);
    return [
      for (final group in groups)
        if (_groupMatches(group, query)) group,
    ];
  }

  bool _groupMatches(WormholeCodeGroup group, TypeSearchQuery query) {
    final text = query.text;
    final textOk =
        text.isEmpty ||
        group.variants.any(
          (type) => type.code.contains(text) || type.name.contains(text),
        );
    final destOk =
        query.destinationLabel == null ||
        group.variants.any(
          (type) => type.destinationLabel == query.destinationLabel,
        );
    final classOk =
        query.rawTargetClass == null ||
        group.variants.any(
          (type) => type.rawTargetClass == query.rawTargetClass,
        );
    final massOk =
        query.minJumpMassKg == null ||
        group.variants.any(
          (type) => (type.maxJumpMassKg ?? 0) > query.minJumpMassKg!,
        );
    final capitalOk =
        !query.capitalOnly ||
        group.variants.any((type) => (type.maxJumpMassKg ?? 0) > 1000000000);
    return textOk && destOk && classOk && massOk && capitalOk;
  }

  int? inheritClass({int? system, int? constellation, int? region}) {
    return region ?? constellation ?? system;
  }

  SystemEffect effectForSystem(SystemReference system) {
    return SystemEffect.resolve(
      beaconTypeId: system.visualSunTypeId ?? system.effectBeaconTypeId,
      visualSunTypeId: system.visualSunTypeId,
    );
  }

  SecurityCategory farSideCategory(int? rawTargetClass) {
    if (rawTargetClass == null) return SecurityCategory.unknown;
    return SecurityCategory.nullsec;
  }

  String staticsDisclosure({
    required bool datasetPresent,
    bool typicalClassOnly = false,
    List<StaticAssignment> assignments = const [],
  }) {
    if (typicalClassOnly || !datasetPresent) {
      return 'C2 typical statics';
    }
    if (assignments.isEmpty) return 'C2 typical statics';
    return assignments.first.code ?? 'static';
  }

  bool staticsCreateRouteEdge({
    required bool datasetPresent,
    bool typicalClassOnly = false,
  }) {
    return !datasetPresent || typicalClassOnly;
  }
}

class EffectCatalog {
  const EffectCatalog();

  static const vortonEffectIds = {11946, 11947, 11948, 11953};

  List<(EffectFamily family, int strength)> combinations() {
    return [
      for (final family in [EffectFamily.pulsar, EffectFamily.wolfRayet])
        for (var strength = 1; strength <= 6; strength++) (family, strength),
    ];
  }

  double percentChange({
    required EffectFamily family,
    required int strength,
    required int attributeId,
  }) {
    return 10.0 * strength;
  }

  Set<int> scopes({required EffectFamily family, required int strength}) {
    return const {};
  }
}
