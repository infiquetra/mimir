/// Modern ESI endpoint registry. Root is `https://esi.evetech.net` (never
/// `/latest`). Compatibility date is the effective 2026-08-18 pin.
class CorporationEndpoint {
  const CorporationEndpoint({
    required this.id,
    required this.pathTemplate,
    this.method = 'GET',
    this.scope,
    this.ttl = const Duration(hours: 1),
    this.rateGroup = 'corp-detail',
    this.preflight = '',
    this.paginated = false,
  });

  final String id;
  final String pathTemplate;
  final String method;
  final String? scope;
  final Duration ttl;
  final String rateGroup;
  final String preflight;
  final bool paginated;
}

class CorporationEndpointRegistry {
  static const compatibilityDate = '2026-08-18';
  static const tenant = 'tranquility';
  static const root = 'https://esi.evetech.net';

  const CorporationEndpointRegistry();

  List<CorporationEndpoint> get all => const [
    CorporationEndpoint(
      id: 'characterPublic',
      pathTemplate: '/characters/{character_id}',
      ttl: Duration(hours: 24),
      rateGroup: 'public',
      preflight: 'Membership/name reference',
    ),
    CorporationEndpoint(
      id: 'corporationPublic',
      pathTemplate: '/corporations/{corporation_id}',
      ttl: Duration(hours: 1),
      rateGroup: 'public',
      preflight: 'Profile and public CEO reference',
    ),
    CorporationEndpoint(
      id: 'alliancePublic',
      pathTemplate: '/alliances/{alliance_id}',
      ttl: Duration(hours: 1),
      rateGroup: 'public',
      preflight: 'Optional alliance reference',
    ),
    CorporationEndpoint(
      id: 'corporationHistory',
      pathTemplate: '/characters/{character_id}/corporationhistory',
      ttl: Duration(hours: 24),
      rateGroup: 'public',
      preflight: 'Join-date fallback only',
    ),
    CorporationEndpoint(
      id: 'marketPrices',
      pathTemplate: '/markets/prices',
      ttl: Duration(hours: 1),
      rateGroup: 'public',
      preflight: 'Exact average-price cache',
    ),
    CorporationEndpoint(
      id: 'universeNames',
      method: 'POST',
      pathTemplate: '/universe/names',
      ttl: Duration(hours: 24),
      rateGroup: 'public',
      preflight: 'Validated batched public entity IDs',
    ),
    CorporationEndpoint(
      id: 'station',
      pathTemplate: '/universe/stations/{station_id}',
      ttl: Duration(hours: 1),
      rateGroup: 'public',
      preflight: 'Proven station reference',
    ),
    CorporationEndpoint(
      id: 'selfRoles',
      pathTemplate: '/characters/{character_id}/roles',
      scope: 'esi-characters.read_corporation_roles.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-detail',
      preflight: 'Self',
    ),
    CorporationEndpoint(
      id: 'selfTitles',
      pathTemplate: '/characters/{character_id}/titles',
      scope: 'esi-characters.read_titles.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-detail',
      preflight: 'Self',
    ),
    CorporationEndpoint(
      id: 'selfStandings',
      pathTemplate: '/characters/{character_id}/standings',
      scope: 'esi-characters.read_standings.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-detail',
      preflight: 'Self',
    ),
    CorporationEndpoint(
      id: 'members',
      pathTemplate: '/corporations/{corporation_id}/members',
      scope: 'esi-corporations.read_corporation_membership.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-member',
      preflight: 'Corporation member',
    ),
    CorporationEndpoint(
      id: 'corporationRoles',
      pathTemplate: '/corporations/{corporation_id}/roles',
      scope: 'esi-corporations.read_corporation_membership.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-member',
      preflight: 'Personnel_Manager/Director',
    ),
    CorporationEndpoint(
      id: 'memberTracking',
      pathTemplate: '/corporations/{corporation_id}/membertracking',
      scope: 'esi-corporations.track_members.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-member',
      preflight: 'Director',
    ),
    CorporationEndpoint(
      id: 'memberTitles',
      pathTemplate: '/corporations/{corporation_id}/members/titles',
      scope: 'esi-corporations.read_titles.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-member',
      preflight: 'Director',
    ),
    CorporationEndpoint(
      id: 'titleDefinitions',
      pathTemplate: '/corporations/{corporation_id}/titles',
      scope: 'esi-corporations.read_titles.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-member',
      preflight: 'Director',
    ),
    CorporationEndpoint(
      id: 'divisions',
      pathTemplate: '/corporations/{corporation_id}/divisions',
      scope: 'esi-corporations.read_divisions.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-detail',
      preflight: 'Director',
    ),
    CorporationEndpoint(
      id: 'assets',
      pathTemplate: '/corporations/{corporation_id}/assets',
      scope: 'esi-assets.read_corporation_assets.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-asset',
      preflight: 'Director',
      paginated: true,
    ),
    CorporationEndpoint(
      id: 'assetNames',
      method: 'POST',
      pathTemplate: '/corporations/{corporation_id}/assets/names',
      scope: 'esi-assets.read_corporation_assets.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-asset',
      preflight: 'Director',
    ),
    CorporationEndpoint(
      id: 'structures',
      pathTemplate: '/corporations/{corporation_id}/structures',
      scope: 'esi-corporations.read_structures.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-structure',
      preflight: 'Station_Manager/Director',
      paginated: true,
    ),
    CorporationEndpoint(
      id: 'structureName',
      pathTemplate: '/universe/structures/{structure_id}',
      scope: 'esi-universe.read_structures.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-structure',
      preflight: 'Character-specific structure ACL',
    ),
    CorporationEndpoint(
      id: 'wallets',
      pathTemplate: '/corporations/{corporation_id}/wallets',
      scope: 'esi-wallet.read_corporation_wallets.v1',
      ttl: Duration(minutes: 5),
      rateGroup: 'corp-wallet',
      preflight: 'Accountant/Junior_Accountant/Director',
    ),
    CorporationEndpoint(
      id: 'walletJournal',
      pathTemplate: '/corporations/{corporation_id}/wallets/{division}/journal',
      scope: 'esi-wallet.read_corporation_wallets.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-wallet',
      preflight: 'Accountant/Junior_Accountant/Director',
      paginated: true,
    ),
    CorporationEndpoint(
      id: 'walletTransactions',
      pathTemplate:
          '/corporations/{corporation_id}/wallets/{division}/transactions',
      scope: 'esi-wallet.read_corporation_wallets.v1',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-wallet',
      preflight: 'Accountant/Junior_Accountant/Director',
    ),
  ];

  CorporationEndpoint? lookup(String id) {
    for (final endpoint in all) {
      if (endpoint.id == id) return endpoint;
    }
    return null;
  }
}
