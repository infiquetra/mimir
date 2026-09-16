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
