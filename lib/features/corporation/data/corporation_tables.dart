import 'package:drift/drift.dart';

/// Concrete SQLite names for design §2.2. GREEN registers Drift tables
/// and schema 22; RED tests assert these names in sqlite_master.
abstract final class CorporationTableNames {
  static const characterAuthorizationStates = 'character_authorization_states';
  static const corporationContextStates = 'corporation_context_states';
  static const oauthAuthorizationAttempts = 'oauth_authorization_attempts';
  static const corporationCapabilities = 'corporation_capabilities';
  static const corporationSnapshotHeads = 'corporation_snapshot_heads';
  static const corporationSnapshotPages = 'corporation_snapshot_pages';
  static const esiRequestLeases = 'esi_request_leases';
  static const esiRateBuckets = 'esi_rate_buckets';
  static const corporationProfiles = 'corporation_profiles';
  static const corporationMembers = 'corporation_members';
  static const corporationMemberTracking = 'corporation_member_tracking';
  static const corporationRoleAssignments = 'corporation_role_assignments';
  static const corporationTitles = 'corporation_titles';
  static const corporationMemberTitles = 'corporation_member_titles';
  static const corporationOwnStandings = 'corporation_own_standings';
  static const corporationDivisionNames = 'corporation_division_names';
  static const corporationAssets = 'corporation_assets';
  static const corporationPrivateNames = 'corporation_private_names';
  static const corporationStructures = 'corporation_structures';
  static const corporationStructureServices = 'corporation_structure_services';
  static const corporationFuelScenarios = 'corporation_fuel_scenarios';
  static const corporationFuelAlertStates = 'corporation_fuel_alert_states';
  static const corporationFuelAlertEpisodes = 'corporation_fuel_alert_episodes';
  static const corporationWalletBalances = 'corporation_wallet_balances';
  static const corporationWalletJournal = 'corporation_wallet_journal';
  static const corporationWalletTransactions =
      'corporation_wallet_transactions';
  static const corporationHistoryCoverage = 'corporation_history_coverage';
  static const corporationMonitoringPreferences =
      'corporation_monitoring_preferences';
  static const exactMarketPrices = 'exact_market_prices';

  static const all = [
    characterAuthorizationStates,
    corporationContextStates,
    oauthAuthorizationAttempts,
    corporationCapabilities,
    corporationSnapshotHeads,
    corporationSnapshotPages,
    esiRequestLeases,
    esiRateBuckets,
    corporationProfiles,
    corporationMembers,
    corporationMemberTracking,
    corporationRoleAssignments,
    corporationTitles,
    corporationMemberTitles,
    corporationOwnStandings,
    corporationDivisionNames,
    corporationAssets,
    corporationPrivateNames,
    corporationStructures,
    corporationStructureServices,
    corporationFuelScenarios,
    corporationFuelAlertStates,
    corporationFuelAlertEpisodes,
    corporationWalletBalances,
    corporationWalletJournal,
    corporationWalletTransactions,
    corporationHistoryCoverage,
    corporationMonitoringPreferences,
    exactMarketPrices,
  ];

  static const indices = [
    'corporation_assets_snapshot_item',
    'corporation_assets_snapshot_location',
    'corporation_wallet_journal_owner_date',
    'corporation_capabilities_endpoint_until',
    'esi_request_leases_deadline',
    'corporation_fuel_alert_states_owner',
  ];
}

class CharacterAuthorizationStates extends Table {
  @override
  String get tableName => 'character_authorization_states';

  TextColumn get tenant => text()();
  IntColumn get characterId => integer()();
  TextColumn get incarnation => text().nullable()();
  IntColumn get grantEpoch => integer().nullable()();
  IntColumn get tokenRevision => integer().nullable()();
  TextColumn get grantedScopesJson => text().nullable()();
  TextColumn get credentialState => text().nullable()();
  IntColumn get invalidationRevision => integer().nullable()();
  IntColumn get lastConfirmedCorporationId => integer().nullable()();
  TextColumn get membershipState => text().nullable()();
  IntColumn get membershipSourceAtMs => integer().nullable()();
  IntColumn get revision => integer().nullable()();

  @override
  Set<Column> get primaryKey => {tenant, characterId};
}

class CorporationContextStates extends Table {
  @override
  String get tableName => 'corporation_context_states';

  TextColumn get tenant => text()();
  IntColumn get selectedCharacterId => integer().nullable()();
  TextColumn get selectedIncarnation => text().nullable()();
  IntColumn get resolvedCorporationId => integer().nullable()();
  TextColumn get membershipState => text().nullable()();
  IntColumn get contextGeneration => integer().withDefault(const Constant(0))();
  IntColumn get selectionRevision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {tenant};
}

class OAuthAuthorizationAttempts extends Table {
  @override
  String get tableName => 'oauth_authorization_attempts';

  TextColumn get operationUuid => text()();
  IntColumn get intendedCharacterId => integer().nullable()();
  TextColumn get intendedIncarnation => text().nullable()();
  IntColumn get priorGrantEpoch => integer().nullable()();
  IntColumn get priorTokenRevision => integer().nullable()();
  TextColumn get requestedScopesJson => text().nullable()();
  TextColumn get mode => text().nullable()();
  TextColumn get stateDigest => text().nullable()();
  IntColumn get createdAtMs => integer().nullable()();
  IntColumn get expiresAtMs => integer().nullable()();
  TextColumn get status => text().nullable()();

  @override
  Set<Column> get primaryKey => {operationUuid};
}

class CorporationCapabilities extends Table {
  @override
  String get tableName => 'corporation_capabilities';

  TextColumn get ownerKey => text()();
  IntColumn get ownerCharacterId => integer()();
  TextColumn get capability => text().nullable()();
  IntColumn get endpointUntilMs => integer().nullable()();
  IntColumn get endpointSuccessAtMs => integer().nullable()();
  TextColumn get roleEvidenceJson => text().nullable()();
  IntColumn get denialRevision => integer().nullable()();
  IntColumn get nextProbeAtMs => integer().nullable()();
  TextColumn get priorSuccessHint => text().nullable()();
  IntColumn get revision => integer().nullable()();
  TextColumn get tenant => text().nullable()();
  IntColumn get corporationId => integer().nullable()();
  IntColumn get grantEpoch => integer().nullable()();

  @override
  Set<Column> get primaryKey => {ownerKey};
}

class CorporationSnapshotHeads extends Table {
  @override
  String get tableName => 'corporation_snapshot_heads';

  TextColumn get ownerKey => text()();
  TextColumn get requestVariant => text()();
  TextColumn get compatibilityDate => text()();
  IntColumn get ownerCharacterId => integer().nullable()();
  TextColumn get acceptedSnapshotId => text().nullable()();
  IntColumn get acceptedRevision => integer().nullable()();
  TextColumn get coverage => text().nullable()();
  IntColumn get payloadReceivedAtMs => integer().nullable()();
  IntColumn get validatedAtMs => integer().nullable()();
  IntColumn get httpDeadlineAtMs => integer().nullable()();
  TextColumn get etag => text().nullable()();
  TextColumn get lastError => text().nullable()();
  TextColumn get refreshRoundId => text().nullable()();

  @override
  Set<Column> get primaryKey => {ownerKey, requestVariant, compatibilityDate};
}

class CorporationSnapshotPages extends Table {
  @override
  String get tableName => 'corporation_snapshot_pages';

  TextColumn get snapshotId => text()();
  TextColumn get pageKey => text()();
  IntColumn get ownerCharacterId => integer().nullable()();
  TextColumn get status => text().nullable()();
  TextColumn get etag => text().nullable()();
  TextColumn get lastModified => text().nullable()();
  IntColumn get dateAtMs => integer().nullable()();
  IntColumn get ageSeconds => integer().nullable()();
  IntColumn get xPages => integer().nullable()();
  TextColumn get contentDigest => text().nullable()();
  IntColumn get validatedAtMs => integer().nullable()();
  TextColumn get nextCursor => text().nullable()();
  BoolColumn get complete => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {snapshotId, pageKey};
}

class EsiRequestLeases extends Table {
  @override
  String get tableName => 'esi_request_leases';

  TextColumn get resourceKey => text()();
  TextColumn get tenant => text().nullable()();
  TextColumn get application => text().nullable()();
  IntColumn get characterId => integer().nullable()();
  TextColumn get rateGroup => text().nullable()();
  TextColumn get callerClass => text().nullable()();
  TextColumn get jobToken => text().nullable()();
  IntColumn get jobEpoch => integer().nullable()();
  TextColumn get ownerProcess => text().nullable()();
  IntColumn get leaseUntilMs => integer().nullable()();
  IntColumn get heartbeatAtMs => integer().nullable()();
  IntColumn get nextAttemptAtMs => integer().nullable()();
  IntColumn get backoffSeconds => integer().nullable()();
  TextColumn get expectedAuthority => text().nullable()();
  IntColumn get acceptedRevision => integer().nullable()();

  @override
  Set<Column> get primaryKey => {resourceKey};
}

class EsiRateBuckets extends Table {
  @override
  String get tableName => 'esi_rate_buckets';

  TextColumn get tenant => text()();
  TextColumn get application => text()();
  IntColumn get characterId => integer()();
  TextColumn get rateGroup => text()();
  IntColumn get limit => integer().nullable()();
  IntColumn get remaining => integer().nullable()();
  IntColumn get used => integer().nullable()();
  IntColumn get observedAtMs => integer().nullable()();
  IntColumn get retryAfterAtMs => integer().nullable()();
  IntColumn get errorUntilMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {tenant, application, characterId, rateGroup};
}

class CorporationProfiles extends Table {
  @override
  String get tableName => 'corporation_profiles';

  TextColumn get tenant => text()();
  IntColumn get corporationId => integer()();
  TextColumn get adapter => text().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get ticker => text().nullable()();
  TextColumn get state => text().nullable()();
  TextColumn get type => text().nullable()();
  TextColumn get friendlyFire => text().nullable()();
  IntColumn get ceoId => integer().nullable()();
  IntColumn get allianceId => integer().nullable()();
  IntColumn get memberCount => integer().nullable()();
  TextColumn get taxIsk => text().nullable()();
  TextColumn get taxLp => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get url => text().nullable()();
  IntColumn get payloadReceivedAtMs => integer().nullable()();
  IntColumn get validatedAtMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {tenant, corporationId};
}

class CorporationMembers extends Table {
  @override
  String get tableName => 'corporation_members';

  TextColumn get snapshotId => text()();
  IntColumn get memberId => integer()();
  IntColumn get ownerCharacterId => integer().nullable()();
  TextColumn get joinEvidence => text().nullable()();

  @override
  Set<Column> get primaryKey => {snapshotId, memberId};
}

class CorporationMemberTracking extends Table {
  @override
  String get tableName => 'corporation_member_tracking';

  TextColumn get snapshotId => text()();
  IntColumn get memberId => integer()();
  IntColumn get ownerCharacterId => integer().nullable()();
  IntColumn get startAtMs => integer().nullable()();
  IntColumn get lastLoginAtMs => integer().nullable()();
  IntColumn get lastLogoutAtMs => integer().nullable()();
  IntColumn get locationId => integer().nullable()();
  IntColumn get shipTypeId => integer().nullable()();
  TextColumn get diagnosticsJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {snapshotId, memberId};
}

class CorporationRoleAssignments extends Table {
  @override
  String get tableName => 'corporation_role_assignments';

  TextColumn get snapshotId => text()();
  IntColumn get subjectId => integer()();
  IntColumn get ownerCharacterId => integer().nullable()();
  TextColumn get generalJson => text().nullable()();
  TextColumn get hqJson => text().nullable()();
  TextColumn get baseJson => text().nullable()();
  TextColumn get otherJson => text().nullable()();
  TextColumn get grantableJson => text().nullable()();
  BoolColumn get generalKnown => boolean().nullable()();
  BoolColumn get grantableKnown => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {snapshotId, subjectId};
}

class CorporationTitles extends Table {
  @override
  String get tableName => 'corporation_titles';

  TextColumn get snapshotId => text()();
  IntColumn get titleId => integer()();
  IntColumn get ownerCharacterId => integer().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get rolesJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {snapshotId, titleId};
}

class CorporationMemberTitles extends Table {
  @override
  String get tableName => 'corporation_member_titles';

  TextColumn get snapshotId => text()();
  IntColumn get memberId => integer()();
  IntColumn get titleId => integer()();
  IntColumn get ownerCharacterId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {snapshotId, memberId, titleId};
}

class CorporationOwnStandings extends Table {
  @override
  String get tableName => 'corporation_own_standings';

  TextColumn get snapshotId => text()();
  TextColumn get sourceKind => text()();
  IntColumn get entityId => integer()();
  IntColumn get ownerCharacterId => integer().nullable()();
  TextColumn get standing => text().nullable()();

  @override
  Set<Column> get primaryKey => {snapshotId, sourceKind, entityId};
}

class CorporationDivisionNames extends Table {
  @override
  String get tableName => 'corporation_division_names';

  TextColumn get snapshotId => text()();
  TextColumn get kind => text()();
  IntColumn get division => integer()();
  IntColumn get ownerCharacterId => integer().nullable()();
  TextColumn get name => text().nullable()();

  @override
  Set<Column> get primaryKey => {snapshotId, kind, division};
}

class CorporationAssets extends Table {
  @override
  String get tableName => 'corporation_assets';

  TextColumn get snapshotId => text()();
  TextColumn get itemKey => text()();
  IntColumn get ownerCharacterId => integer().nullable()();
  IntColumn get typeId => integer().nullable()();
  TextColumn get quantity => text().nullable()();
  BoolColumn get quantityUnknown => boolean().nullable()();
  BoolColumn get isSingleton => boolean().nullable()();
  BoolColumn get isBlueprintCopy => boolean().nullable()();
  TextColumn get locationKey => text().nullable()();
  TextColumn get locationType => text().nullable()();
  TextColumn get parentKey => text().nullable()();
  TextColumn get locationFlag => text().nullable()();

  @override
  Set<Column> get primaryKey => {snapshotId, itemKey};
}

class CorporationPrivateNames extends Table {
  @override
  String get tableName => 'corporation_private_names';

  TextColumn get ownerKey => text()();
  TextColumn get nameSource => text()();
  TextColumn get entityKey => text()();
  IntColumn get ownerCharacterId => integer().nullable()();
  TextColumn get name => text().nullable()();
  IntColumn get observedAtMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {ownerKey, nameSource, entityKey};
}

class CorporationStructures extends Table {
  @override
  String get tableName => 'corporation_structures';

  TextColumn get snapshotId => text()();
  TextColumn get structureKey => text()();
  IntColumn get ownerCharacterId => integer().nullable()();
  TextColumn get name => text().nullable()();
  IntColumn get typeId => integer().nullable()();
  IntColumn get systemId => integer().nullable()();
  TextColumn get state => text().nullable()();
  IntColumn get stateStartAtMs => integer().nullable()();
  IntColumn get stateEndAtMs => integer().nullable()();
  IntColumn get unanchorAtMs => integer().nullable()();
  IntColumn get fuelExpiresAtMs => integer().nullable()();
  BoolColumn get servicesPresent => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {snapshotId, structureKey};
}

class CorporationStructureServices extends Table {
  @override
  String get tableName => 'corporation_structure_services';

  TextColumn get snapshotId => text()();
  TextColumn get structureKey => text()();
  IntColumn get ordinal => integer()();
  IntColumn get ownerCharacterId => integer().nullable()();
  TextColumn get label => text().nullable()();
  TextColumn get state => text().nullable()();

  @override
  Set<Column> get primaryKey => {snapshotId, structureKey, ordinal};
}

class CorporationFuelScenarios extends Table {
  @override
  String get tableName => 'corporation_fuel_scenarios';

  IntColumn get characterId => integer()();
  TextColumn get incarnation => text()();
  IntColumn get corporationId => integer()();
  TextColumn get structureKey => text()();
  IntColumn get grantEpoch => integer().nullable()();
  TextColumn get quantity => text().nullable()();
  TextColumn get rate => text().nullable()();
  IntColumn get savedAtMs => integer().nullable()();
  IntColumn get revision => integer().nullable()();
  TextColumn get quarantineState => text().nullable()();

  @override
  Set<Column> get primaryKey => {
    characterId,
    incarnation,
    corporationId,
    structureKey,
  };
}

class CorporationFuelAlertStates extends Table {
  @override
  String get tableName => 'corporation_fuel_alert_states';

  IntColumn get characterId => integer()();
  TextColumn get incarnation => text()();
  IntColumn get corporationId => integer()();
  TextColumn get structureKey => text()();
  IntColumn get grantEpoch => integer().nullable()();
  TextColumn get rearmState => text().nullable()();
  IntColumn get episodeOrdinal => integer().nullable()();
  IntColumn get lastSourceRevision => integer().nullable()();
  TextColumn get lastSeverity => text().nullable()();
  IntColumn get accessInvalidation => integer().nullable()();

  @override
  Set<Column> get primaryKey => {
    characterId,
    incarnation,
    corporationId,
    structureKey,
  };
}

class CorporationFuelAlertEpisodes extends Table {
  @override
  String get tableName => 'corporation_fuel_alert_episodes';

  TextColumn get ownerKey => text()();
  TextColumn get episodeUuid => text()();
  IntColumn get ownerCharacterId => integer().nullable()();
  IntColumn get sourceRevision => integer().nullable()();
  IntColumn get createdAtMs => integer().nullable()();
  TextColumn get severity => text().nullable()();
  IntColumn get acknowledgedAtMs => integer().nullable()();
  IntColumn get closedAtMs => integer().nullable()();
  TextColumn get deliveryClaim => text().nullable()();
  TextColumn get handoffState => text().nullable()();

  @override
  Set<Column> get primaryKey => {ownerKey, episodeUuid};
}

class CorporationWalletBalances extends Table {
  @override
  String get tableName => 'corporation_wallet_balances';

  TextColumn get snapshotId => text()();
  IntColumn get division => integer()();
  IntColumn get ownerCharacterId => integer()();
  TextColumn get balance => text()();

  @override
  Set<Column> get primaryKey => {snapshotId, division};
}

class CorporationWalletJournal extends Table {
  @override
  String get tableName => 'corporation_wallet_journal';

  TextColumn get ownerKey => text()();
  TextColumn get journalKey => text()();
  IntColumn get ownerCharacterId => integer()();
  TextColumn get amount => text().nullable()();
  TextColumn get balance => text().nullable()();
  IntColumn get occurredAtMs => integer().nullable()();
  TextColumn get refType => text().nullable()();
  TextColumn get reason => text().nullable()();
  IntColumn get lastObservedRevision => integer().nullable()();

  @override
  Set<Column> get primaryKey => {ownerKey, journalKey};
}

class CorporationWalletTransactions extends Table {
  @override
  String get tableName => 'corporation_wallet_transactions';

  TextColumn get ownerKey => text()();
  TextColumn get transactionKey => text()();
  IntColumn get ownerCharacterId => integer().nullable()();
  IntColumn get occurredAtMs => integer().nullable()();
  IntColumn get typeId => integer().nullable()();
  IntColumn get quantity => integer().nullable()();
  TextColumn get unitPrice => text().nullable()();
  TextColumn get buySell => text().nullable()();
  TextColumn get journalKey => text().nullable()();
  IntColumn get lastObservedRevision => integer().nullable()();

  @override
  Set<Column> get primaryKey => {ownerKey, transactionKey};
}

class CorporationHistoryCoverage extends Table {
  @override
  String get tableName => 'corporation_history_coverage';

  TextColumn get ownerKey => text()();
  TextColumn get coverageKey => text()();
  IntColumn get ownerCharacterId => integer().nullable()();
  IntColumn get intervalStartAtMs => integer().nullable()();
  IntColumn get intervalEndAtMs => integer().nullable()();
  TextColumn get pageChainJson => text().nullable()();
  TextColumn get termination => text().nullable()();
  IntColumn get earliestRowAtMs => integer().nullable()();
  IntColumn get latestRowAtMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {ownerKey, coverageKey};
}

class CorporationMonitoringPreferences extends Table {
  @override
  String get tableName => 'corporation_monitoring_preferences';

  TextColumn get tenant => text()();
  IntColumn get characterId => integer()();
  TextColumn get incarnation => text().nullable()();
  BoolColumn get optIn => boolean().withDefault(const Constant(false))();
  IntColumn get preferenceRevision => integer().nullable()();
  TextColumn get osPermission => text().nullable()();

  @override
  Set<Column> get primaryKey => {tenant, characterId};
}

class ExactMarketPrices extends Table {
  @override
  String get tableName => 'exact_market_prices';

  TextColumn get tenant => text()();
  IntColumn get typeId => integer()();
  TextColumn get averagePrice => text().nullable()();
  TextColumn get adjustedPrice => text().nullable()();
  IntColumn get payloadReceivedAtMs => integer().nullable()();
  IntColumn get validatedAtMs => integer().nullable()();
  IntColumn get snapshotRevision => integer().nullable()();

  @override
  Set<Column> get primaryKey => {tenant, typeId};
}
