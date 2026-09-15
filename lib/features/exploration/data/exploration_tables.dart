import 'package:drift/drift.dart';

/// Shared EVE-Scout feed metadata. Not character-owned.
class EveScoutFeedStates extends Table {
  @override
  String get tableName => 'eve_scout_feed_states';

  TextColumn get scopeKey => text()();
  BoolColumn get cacheValid => boolean().withDefault(const Constant(false))();
  IntColumn get snapshotRevision => integer().withDefault(const Constant(0))();
  IntColumn get validationRevision =>
      integer().withDefault(const Constant(0))();
  IntColumn get metadataRevision => integer().withDefault(const Constant(0))();
  IntColumn get payloadReceivedAtMs => integer().nullable()();
  IntColumn get lastValidatedAtMs => integer().nullable()();
  IntColumn get lastAttemptAtMs => integer().nullable()();
  TextColumn get etag => text().nullable()();
  TextColumn get lastModified => text().nullable()();
  IntColumn get cacheExpiresAtMs => integer().nullable()();
  IntColumn get nextAttemptAtMs => integer().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get failureCount => integer().withDefault(const Constant(0))();
  TextColumn get bodyDigest => text().nullable()();
  IntColumn get requestEpoch => integer().withDefault(const Constant(0))();
  TextColumn get requestToken => text().nullable()();
  TextColumn get requestOwner => text().nullable()();
  IntColumn get leaseUntilMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {scopeKey};
}

/// Independent public-signature observations for a feed snapshot.
class EveScoutSignatures extends Table {
  @override
  String get tableName => 'eve_scout_signatures';

  TextColumn get scopeKey => text()();
  TextColumn get providerRecordKey => text()();
  IntColumn get hubSystemId => integer()();
  TextColumn get hubSystemName => text().nullable()();
  TextColumn get hubRegionHint => text().nullable()();
  IntColumn get farSystemId => integer()();
  TextColumn get farSystemName => text().nullable()();
  TextColumn get farRegionHint => text().nullable()();
  TextColumn get hubSignature => text().nullable()();
  TextColumn get farSignature => text().nullable()();
  TextColumn get wormholeType => text().nullable()();
  TextColumn get orientation => text().nullable()();
  TextColumn get maxShipSize => text().nullable()();
  TextColumn get completionType => text().nullable()();
  IntColumn get sourceCreatedAtMs => integer().nullable()();
  IntColumn get sourceUpdatedAtMs => integer().nullable()();
  IntColumn get sourceCompletedAtMs => integer().nullable()();
  IntColumn get sourceExpiresAtMs => integer().nullable()();
  TextColumn get rawCategoryHintsJson => text().nullable()();
  TextColumn get diagnosticsJson => text().nullable()();
  IntColumn get listedSnapshotRevision => integer()();
  IntColumn get lastPayloadSeenAtMs => integer().nullable()();
  IntColumn get unavailableAtMs => integer().nullable()();
  IntColumn get retiredAtMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {scopeKey, providerRecordKey};
}

/// Private notebook signature episodes. Times are UTC milliseconds.
class TrackedSignatures extends Table {
  @override
  String get tableName => 'tracked_signatures';

  TextColumn get id => text()();
  IntColumn get characterId => integer()();
  IntColumn get systemId => integer()();
  TextColumn get code => text()();
  TextColumn get scanGroup =>
      text().withDefault(const Constant('Cosmic Signature'))();
  TextColumn get type => text().withDefault(const Constant('unknown'))();
  TextColumn get rawTypeLabel => text().withDefault(const Constant(''))();
  TextColumn get name => text().nullable()();
  TextColumn get bookmark => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get firstSeenAtMs => integer()();
  IntColumn get lastSeenAtMs => integer()();
  IntColumn get editedAtMs => integer().nullable()();
  TextColumn get lifecycle => text().withDefault(const Constant('active'))();
  IntColumn get retiredAtMs => integer().nullable()();
  TextColumn get retiredReason => text().nullable()();
  IntColumn get rowRevision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Private verified wormhole links owned by a signature episode.
class TrackedConnections extends Table {
  @override
  String get tableName => 'tracked_connections';

  TextColumn get id => text()();
  TextColumn get ownerSignatureId => text()();
  IntColumn get characterId => integer()();
  IntColumn get fromSystemId => integer()();
  IntColumn get toSystemId => integer()();
  TextColumn get fromSignature => text().nullable()();
  TextColumn get toSignature => text().nullable()();
  TextColumn get observedFromCode => text().nullable()();
  TextColumn get observedToCode => text().nullable()();
  IntColumn get originatingTypeId => integer().nullable()();
  TextColumn get originatingType => text().nullable()();
  TextColumn get originatingSide => text().nullable()();
  TextColumn get massValue => text().nullable()();
  IntColumn get massObservedAtMs => integer().nullable()();
  TextColumn get massSource => text().nullable()();
  TextColumn get timeValue => text().nullable()();
  IntColumn get timeObservedAtMs => integer().nullable()();
  TextColumn get timeSource => text().nullable()();
  IntColumn get estimatedExpiryAtMs => integer().nullable()();
  IntColumn get verifiedAtMs => integer().nullable()();
  TextColumn get lifecycle => text().withDefault(const Constant('active'))();
  TextColumn get retiredReason => text().nullable()();
  IntColumn get rowRevision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {ownerSignatureId},
  ];
}

/// Per-character, per-system notebook write generation.
class ExplorationNotebookScopes extends Table {
  @override
  String get tableName => 'exploration_notebook_scopes';

  IntColumn get characterId => integer()();
  IntColumn get systemId => integer()();
  IntColumn get revision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {characterId, systemId};
}

/// Durable import receipts. No raw clipboard text.
class ExplorationImportOperations extends Table {
  @override
  String get tableName => 'exploration_import_operations';

  TextColumn get id => text()();
  IntColumn get characterId => integer()();
  IntColumn get systemId => integer()();
  TextColumn get inputDigest => text()();
  IntColumn get committedAtMs => integer()();
  TextColumn get selectedRowDigest => text().nullable()();
  IntColumn get addedCount => integer().withDefault(const Constant(0))();
  IntColumn get updatedCount => integer().withDefault(const Constant(0))();
  IntColumn get skippedCount => integer().withDefault(const Constant(0))();
  IntColumn get conflictCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-character prune policy. Null [pruneHours] is Off; default 24.
class ExplorationNotebookPreferences extends Table {
  @override
  String get tableName => 'exploration_notebook_preferences';

  IntColumn get characterId => integer()();
  IntColumn get pruneHours =>
      integer().nullable().withDefault(const Constant(24))();
  IntColumn get revision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {characterId};
}

/// Singleton window chrome. Not character-owned notebook state.
class ExplorationWindowPreferences extends Table {
  @override
  String get tableName => 'exploration_window_preferences';

  TextColumn get windowKey => text()();
  TextColumn get lastSelectedDestination => text().nullable()();
  IntColumn get manualOriginSystemId => integer().nullable()();
  IntColumn get manualDestinationSystemId => integer().nullable()();
  TextColumn get viewFiltersJson => text().nullable()();
  TextColumn get selectedStableKeysJson => text().nullable()();
  IntColumn get schemaVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {windowKey};
}

/// Last-known local location observation. Never a token or auth claim.
class ExplorationLocationObservations extends Table {
  @override
  String get tableName => 'exploration_location_observations';

  IntColumn get characterId => integer()();
  IntColumn get systemId => integer()();
  IntColumn get observedAtMs => integer()();
  IntColumn get receivedAtMs => integer()();
  TextColumn get sourceFreshnessJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {characterId};
}
