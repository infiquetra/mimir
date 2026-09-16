/// Naive C2 registry: `/latest` root, review-date compatibility, wallets TTL 1h,
/// and an incomplete endpoint list.
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
  static const compatibilityDate = '2026-09-15';
  static const tenant = 'tranquility';
  static const root = 'https://esi.evetech.net/latest';

  const CorporationEndpointRegistry();

  List<CorporationEndpoint> get all => const [
    CorporationEndpoint(
      id: 'characterPublic',
      pathTemplate: '/latest/characters/{character_id}',
      ttl: Duration(hours: 24),
      rateGroup: 'public',
    ),
    CorporationEndpoint(
      id: 'corporationPublic',
      pathTemplate: '/latest/corporations/{corporation_id}',
      rateGroup: 'public',
    ),
    CorporationEndpoint(
      id: 'selfRoles',
      pathTemplate: '/latest/characters/{character_id}/roles',
      scope: 'esi-characters.read_corporation_roles.v1',
    ),
    CorporationEndpoint(
      id: 'members',
      pathTemplate: '/latest/corporations/{corporation_id}/members',
      scope: 'esi-corporations.read_corporation_membership.v1',
    ),
    CorporationEndpoint(
      id: 'assets',
      pathTemplate: '/latest/corporations/{corporation_id}/assets',
      scope: 'esi-assets.read_corporation_assets.v1',
      preflight: 'Director',
      paginated: true,
    ),
    CorporationEndpoint(
      id: 'wallets',
      pathTemplate: '/latest/corporations/{corporation_id}/wallets',
      scope: 'esi-wallet.read_corporation_wallets.v1',
      preflight: 'Accountant',
      ttl: Duration(hours: 1),
      rateGroup: 'corp-wallet',
    ),
  ];

  CorporationEndpoint? lookup(String id) {
    for (final endpoint in all) {
      if (endpoint.id == id) return endpoint;
    }
    return null;
  }
}
