import 'package:drift/drift.dart';

/// Wormhole type reference rows. Numeric type ID is the primary key;
/// the visible code is not unique (C729 variants share a code).
@TableIndex(name: 'sde_wormhole_types_code', columns: {#code})
class SdeWormholeTypes extends Table {
  IntColumn get typeId => integer()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  IntColumn get groupId => integer().withDefault(const Constant(988))();
  BoolColumn get published => boolean().withDefault(const Constant(true))();
  IntColumn get rawTargetClass => integer().nullable()();
  IntColumn get rawTargetDistribution => integer().nullable()();
  IntColumn get reliableLifetimeSeconds => integer().nullable()();
  RealColumn get maxJumpMassKg => real().nullable()();
  RealColumn get totalMassKg => real().nullable()();
  RealColumn get regenerationKgPerCycle => real().nullable()();

  @override
  Set<Column> get primaryKey => {typeId};
}

/// Universe systems used by exploration (wormhole space and named hubs).
@TableIndex(name: 'sde_wormhole_systems_name', columns: {#name})
class SdeWormholeSystems extends Table {
  IntColumn get systemId => integer()();
  TextColumn get name => text()();
  IntColumn get constellationId => integer().nullable()();
  IntColumn get regionId => integer().nullable()();
  TextColumn get constellationName => text().nullable()();
  TextColumn get regionName => text().nullable()();
  RealColumn get rawSecurity => real().nullable()();
  IntColumn get rawClass => integer().nullable()();
  IntColumn get inheritedClass => integer().nullable()();
  TextColumn get inheritanceSource => text().nullable()();
  IntColumn get effectBeaconTypeId => integer().nullable()();
  IntColumn get visualSunTypeId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {systemId};
}

/// Applied system-effect beacons (36 family × strength combinations).
class SdeSystemEffects extends Table {
  IntColumn get beaconTypeId => integer()();
  TextColumn get family => text()();
  IntColumn get strength => integer()();
  TextColumn get scopesJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {beaconTypeId};
}

/// Directed stargate topology edges.
@TableIndex(name: 'sde_stargates_from', columns: {#fromSystemId})
class SdeStargates extends Table {
  IntColumn get gateId => integer()();
  IntColumn get fromSystemId => integer()();
  IntColumn get toSystemId => integer()();
  IntColumn get topologyVersion => integer().withDefault(const Constant(0))();
  TextColumn get restrictionsJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {gateId};
}

/// Optional per-system static assignments. Absence means unavailable,
/// never a fabricated typical-class edge.
class SdeSystemStatics extends Table {
  IntColumn get systemId => integer()();
  IntColumn get assignmentIndex => integer()();
  TextColumn get code => text().nullable()();
  IntColumn get typeId => integer().nullable()();
  TextColumn get meaning => text().withDefault(const Constant(''))();
  TextColumn get source => text().withDefault(const Constant(''))();
  TextColumn get confidence => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {systemId, assignmentIndex};
}
