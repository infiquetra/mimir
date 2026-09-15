import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/sde/sde_database.dart';
import '../../../core/sde/sde_service.dart';
import '../../../core/sde/sde_update_service.dart';
import '../domain/exploration_reference.dart';
import '../domain/exploration_reference_deriver.dart';

class ExplorationReferenceBundle {
  const ExplorationReferenceBundle({
    required this.manifest,
    this.types = const [],
    this.systems = const [],
    this.checksum = '',
    this.corrupt = false,
  });

  final ReferenceManifest manifest;
  final List<RawWormholeRecord> types;
  final List<SystemReference> systems;
  final String checksum;
  final bool corrupt;
}

class ExplorationImportResult {
  const ExplorationImportResult({
    required this.success,
    this.stampedVersion,
    this.retainedPrevious = false,
    this.error,
  });

  final bool success;
  final int? stampedVersion;
  final bool retainedPrevious;
  final String? error;
}

/// SDE-backed exploration reference. Import replaces only the exploration
/// slice; skills/dogma/industry rows survive. Failed or older imports retain
/// the previous usable catalog.
class ExplorationReferenceRepository {
  ExplorationReferenceRepository({
    required this.database,
    required this.service,
    SdeUpdateService? updateService,
  }) : updateService = updateService ?? SdeUpdateService(database: database);

  final SdeDatabase database;
  final SdeService service;
  final SdeUpdateService updateService;
  final _deriver = const ReferenceDeriver();

  Future<ReferenceManifest?> readExplorationManifest() async {
    final json = await database.getMetadata(SdeDatabase.explorationManifestKey);
    if (json == null || json.isEmpty) return null;
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) return null;
    return ReferenceManifest.fromJson(decoded);
  }

  Future<List<WormholeTypeReference>> loadWormholeTypes() async {
    final rows = await service.getAllWormholeTypes();
    return [for (final row in rows) _typeFromRow(row)];
  }

  Future<String> getSolarSystemName(int solarSystemId) {
    return service.getSolarSystemName(solarSystemId);
  }

  Future<List<SystemReference>> getSystemReferences(List<int> ids) async {
    final rows = await service.getSystemReferences(ids);
    return [for (final row in rows) _systemFromRow(row)];
  }

  Future<List<WormholeCodeGroup>> searchExplorationTypes(
    TypeSearchQuery query,
  ) async {
    final types = await loadWormholeTypes();
    return _deriver.search(types, query);
  }

  Future<List<SdeStargate>> loadGateTopology() {
    return service.loadGateTopology();
  }

  Future<ReferenceManifest?> ensureExplorationReference() async {
    return readExplorationManifest();
  }

  Future<ExplorationImportResult> importBundle(
    ExplorationReferenceBundle bundle,
  ) async {
    final previous = await readExplorationManifest();
    final previousBuild = previous?.sdeBuild;

    if (!updateService.validateExplorationChecksum(
      checksum: bundle.checksum,
      manifestChecksums: bundle.manifest.checksums,
      corrupt: bundle.corrupt,
      validation: bundle.manifest.validation,
    )) {
      return ExplorationImportResult(
        success: false,
        stampedVersion: previousBuild,
        retainedPrevious: previous != null,
        error: 'invalid',
      );
    }

    if (!updateService.canInstallExplorationBuild(
      bundle.manifest.sdeBuild,
      previousBuild,
    )) {
      return ExplorationImportResult(
        success: false,
        stampedVersion: previousBuild,
        retainedPrevious: true,
        error: 'older-build',
      );
    }

    final typeRows = <SdeWormholeTypesCompanion>[];
    for (final raw in bundle.types) {
      final projected = _deriver.project(raw);
      if (projected == null) continue;
      typeRows.add(_typeCompanion(raw, projected));
    }

    final systemRows = [
      for (final system in bundle.systems) _systemCompanion(system),
    ];

    try {
      await updateService.replaceExplorationSlice(
        manifestJson: jsonEncode(bundle.manifest.toJson()),
        sdeBuild: bundle.manifest.sdeBuild,
        types: typeRows,
        systems: systemRows,
        effects: _effectCompanions(),
      );
    } catch (error) {
      return ExplorationImportResult(
        success: false,
        stampedVersion: previousBuild,
        retainedPrevious: previous != null,
        error: error.toString(),
      );
    }

    return ExplorationImportResult(
      success: true,
      stampedVersion: bundle.manifest.sdeBuild,
    );
  }

  SdeWormholeTypesCompanion _typeCompanion(
    RawWormholeRecord raw,
    WormholeTypeReference projected,
  ) {
    return SdeWormholeTypesCompanion(
      typeId: Value(projected.typeId),
      code: Value(projected.code),
      name: Value(projected.name),
      groupId: Value(raw.groupId),
      published: Value(raw.published),
      rawTargetClass: Value(raw.rawTargetClass),
      rawTargetDistribution: Value(raw.rawTargetDistribution),
      reliableLifetimeSeconds: Value(projected.reliableLifetimeSeconds),
      maxJumpMassKg: Value(projected.maxJumpMassKg),
      totalMassKg: Value(projected.totalMassKg),
      regenerationKgPerCycle: Value(projected.regenerationKgPerCycle),
    );
  }

  SdeWormholeSystemsCompanion _systemCompanion(SystemReference system) {
    return SdeWormholeSystemsCompanion(
      systemId: Value(system.systemId),
      name: Value(system.name),
      constellationId: Value(system.constellationId),
      regionId: Value(system.regionId),
      constellationName: Value(system.constellationName),
      regionName: Value(system.regionName),
      rawSecurity: Value(system.rawSecurity),
      rawClass: Value(system.rawClass),
      inheritedClass: Value(system.inheritedClass),
      inheritanceSource: Value(system.inheritanceSource),
      effectBeaconTypeId: Value(system.effectBeaconTypeId),
      visualSunTypeId: Value(system.visualSunTypeId),
    );
  }

  List<SdeSystemEffectsCompanion> _effectCompanions() {
    const catalog = EffectCatalog();
    return [
      for (final family in EffectFamily.values)
        for (var strength = 1; strength <= 6; strength++)
          SdeSystemEffectsCompanion(
            beaconTypeId: Value(EffectCatalog.beacons[family]![strength - 1]),
            family: Value(family.name),
            strength: Value(strength),
            scopesJson: Value(
              jsonEncode(
                catalog.scopes(family: family, strength: strength).toList(),
              ),
            ),
          ),
    ];
  }

  WormholeTypeReference _typeFromRow(SdeWormholeType row) {
    return WormholeTypeReference(
      typeId: row.typeId,
      code: row.code,
      name: row.name,
      rawTargetClass: row.rawTargetClass,
      rawTargetDistribution: row.rawTargetDistribution,
      reliableLifetimeSeconds: row.reliableLifetimeSeconds,
      maxJumpMassKg: row.maxJumpMassKg,
      totalMassKg: row.totalMassKg,
      regenerationKgPerCycle: row.regenerationKgPerCycle,
    );
  }

  SystemReference _systemFromRow(SdeWormholeSystem row) {
    return SystemReference(
      systemId: row.systemId,
      name: row.name,
      constellationId: row.constellationId,
      regionId: row.regionId,
      constellationName: row.constellationName,
      regionName: row.regionName,
      rawSecurity: row.rawSecurity,
      rawClass: row.rawClass,
      inheritedClass: row.inheritedClass,
      inheritanceSource: row.inheritanceSource,
      effectBeaconTypeId: row.effectBeaconTypeId,
      visualSunTypeId: row.visualSunTypeId,
    );
  }
}
