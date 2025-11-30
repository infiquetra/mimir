/// EVE Online API configuration.
///
/// Contains ESI endpoints, OAuth configuration, and other EVE-related constants.
abstract class EveConfig {
  // ==========================================================================
  // ESI Configuration
  // ==========================================================================

  /// ESI base URL for API requests.
  static const String esiBaseUrl = 'https://esi.evetech.net/latest';

  /// ESI image server URL.
  static const String imageServerUrl = 'https://images.evetech.net';

  /// Default ESI datasource (tranquility = live server).
  static const String datasource = 'tranquility';

  // ==========================================================================
  // OAuth Configuration
  // ==========================================================================

  /// EVE SSO OAuth authorize endpoint.
  static const String oauthAuthorizeUrl =
      'https://login.eveonline.com/v2/oauth/authorize';

  /// EVE SSO OAuth token endpoint.
  static const String oauthTokenUrl =
      'https://login.eveonline.com/v2/oauth/token';

  /// EVE SSO OAuth revoke endpoint.
  static const String oauthRevokeUrl =
      'https://login.eveonline.com/v2/oauth/revoke';

  /// OAuth redirect URI (same for all platforms).
  /// EVE requires custom schemes to start with "eveauth".
  static const String redirectUri = 'eveauth-mimir://callback';

  /// URL scheme for deep linking.
  static const String urlScheme = 'eveauth-mimir';

  /// EVE Developer Application Client ID.
  /// Registered at developers.eveonline.com for Mimir app.
  /// Public per OAuth PKCE spec - no client secret needed.
  static const String clientId = '43d0fef53e004c3e856ca3a716769125';

  // ==========================================================================
  // OAuth Scopes (Phase 1)
  // ==========================================================================

  /// OAuth scopes required for Phase 1 features.
  static const List<String> phase1Scopes = [
    'esi-skills.read_skills.v1',
    'esi-skills.read_skillqueue.v1',
    'esi-wallet.read_character_wallet.v1',
  ];

  // ==========================================================================
  // OAuth Scopes (Phase 2 - Fleet Status)
  // ==========================================================================

  /// OAuth scopes required for fleet status features.
  ///
  /// WARNING: Adding these scopes requires users to re-authenticate.
  /// Existing tokens will not have these permissions.
  static const List<String> phase2FleetScopes = [
    'esi-location.read_location.v1', // Character location
    'esi-location.read_ship_type.v1', // Current ship
    'esi-location.read_online.v1', // Online status
  ];

  /// All OAuth scopes as a space-separated string.
  static String get scopesString =>
      [...phase1Scopes, ...phase2FleetScopes].join(' ');

  // ==========================================================================
  // Token Configuration
  // ==========================================================================

  /// Access token lifetime in seconds (ESI default is 1199 seconds ~20 min).
  static const int accessTokenLifetime = 1199;

  /// Buffer time before token expiry to trigger refresh (in seconds).
  static const int tokenRefreshBuffer = 60;

  // ==========================================================================
  // Rate Limiting
  // ==========================================================================

  /// Maximum errors per minute before backing off.
  static const int maxErrorsPerMinute = 100;

  /// Default timeout for API requests in milliseconds.
  static const int defaultTimeout = 30000;

  // ==========================================================================
  // Data Refresh Intervals (in seconds)
  // ==========================================================================

  /// How often to refresh skill queue data.
  static const int skillQueueRefreshInterval = 300; // 5 minutes

  /// How often to refresh wallet balance.
  static const int walletRefreshInterval = 600; // 10 minutes

  /// How often to refresh character info.
  static const int characterRefreshInterval = 21600; // 6 hours

  // ==========================================================================
  // SDE Configuration
  // ==========================================================================

  /// URL to check for SDE updates.
  static const String sdeManifestUrl =
      'https://github.com/infiquetra/mimir-sde/releases/latest/download/manifest.json';

  /// Local SDE database filename.
  static const String sdeDbFilename = 'sde.sqlite';
}
