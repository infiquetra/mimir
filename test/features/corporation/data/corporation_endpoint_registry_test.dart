// C2 RED: endpoint registry must pin modern ESI root, 2026-08-18 compatibility,
// full §3.1 coverage, and wallet TTL 5m.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/data/corporation_endpoint_registry.dart';

void main() {
  const registry = CorporationEndpointRegistry();

  test('uses esi.evetech.net without /latest and pins 2026-08-18', () {
    expect(CorporationEndpointRegistry.root, 'https://esi.evetech.net');
    expect(CorporationEndpointRegistry.root.contains('/latest'), isFalse);
    expect(CorporationEndpointRegistry.compatibilityDate, '2026-08-18');
    expect(CorporationEndpointRegistry.tenant, 'tranquility');
  });

  test('registers every §3.1 path with scope, method, TTL, and rate group', () {
    const required =
        <
          String,
          ({
            String method,
            String path,
            String? scope,
            Duration ttl,
            String rateGroup,
          })
        >{
          'characterPublic': (
            method: 'GET',
            path: '/characters/{character_id}',
            scope: null,
            ttl: Duration(hours: 24),
            rateGroup: 'public',
          ),
          'corporationPublic': (
            method: 'GET',
            path: '/corporations/{corporation_id}',
            scope: null,
            ttl: Duration(hours: 1),
            rateGroup: 'public',
          ),
          'alliancePublic': (
            method: 'GET',
            path: '/alliances/{alliance_id}',
            scope: null,
            ttl: Duration(hours: 1),
            rateGroup: 'public',
          ),
          'corporationHistory': (
            method: 'GET',
            path: '/characters/{character_id}/corporationhistory',
            scope: null,
            ttl: Duration(hours: 24),
            rateGroup: 'public',
          ),
          'marketPrices': (
            method: 'GET',
            path: '/markets/prices',
            scope: null,
            ttl: Duration(hours: 1),
            rateGroup: 'public',
          ),
          'universeNames': (
            method: 'POST',
            path: '/universe/names',
            scope: null,
            ttl: Duration(hours: 24),
            rateGroup: 'public',
          ),
          'station': (
            method: 'GET',
            path: '/universe/stations/{station_id}',
            scope: null,
            ttl: Duration(hours: 1),
            rateGroup: 'public',
          ),
          'selfRoles': (
            method: 'GET',
            path: '/characters/{character_id}/roles',
            scope: 'esi-characters.read_corporation_roles.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-detail',
          ),
          'selfTitles': (
            method: 'GET',
            path: '/characters/{character_id}/titles',
            scope: 'esi-characters.read_titles.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-detail',
          ),
          'selfStandings': (
            method: 'GET',
            path: '/characters/{character_id}/standings',
            scope: 'esi-characters.read_standings.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-detail',
          ),
          'members': (
            method: 'GET',
            path: '/corporations/{corporation_id}/members',
            scope: 'esi-corporations.read_corporation_membership.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-member',
          ),
          'corporationRoles': (
            method: 'GET',
            path: '/corporations/{corporation_id}/roles',
            scope: 'esi-corporations.read_corporation_membership.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-member',
          ),
          'memberTracking': (
            method: 'GET',
            path: '/corporations/{corporation_id}/membertracking',
            scope: 'esi-corporations.track_members.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-member',
          ),
          'memberTitles': (
            method: 'GET',
            path: '/corporations/{corporation_id}/members/titles',
            scope: 'esi-corporations.read_titles.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-member',
          ),
          'titleDefinitions': (
            method: 'GET',
            path: '/corporations/{corporation_id}/titles',
            scope: 'esi-corporations.read_titles.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-member',
          ),
          'divisions': (
            method: 'GET',
            path: '/corporations/{corporation_id}/divisions',
            scope: 'esi-corporations.read_divisions.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-detail',
          ),
          'assets': (
            method: 'GET',
            path: '/corporations/{corporation_id}/assets',
            scope: 'esi-assets.read_corporation_assets.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-asset',
          ),
          'assetNames': (
            method: 'POST',
            path: '/corporations/{corporation_id}/assets/names',
            scope: 'esi-assets.read_corporation_assets.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-asset',
          ),
          'structures': (
            method: 'GET',
            path: '/corporations/{corporation_id}/structures',
            scope: 'esi-corporations.read_structures.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-structure',
          ),
          'structureName': (
            method: 'GET',
            path: '/universe/structures/{structure_id}',
            scope: 'esi-universe.read_structures.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-structure',
          ),
          'wallets': (
            method: 'GET',
            path: '/corporations/{corporation_id}/wallets',
            scope: 'esi-wallet.read_corporation_wallets.v1',
            ttl: Duration(minutes: 5),
            rateGroup: 'corp-wallet',
          ),
          'walletJournal': (
            method: 'GET',
            path: '/corporations/{corporation_id}/wallets/{division}/journal',
            scope: 'esi-wallet.read_corporation_wallets.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-wallet',
          ),
          'walletTransactions': (
            method: 'GET',
            path:
                '/corporations/{corporation_id}/wallets/{division}/transactions',
            scope: 'esi-wallet.read_corporation_wallets.v1',
            ttl: Duration(hours: 1),
            rateGroup: 'corp-wallet',
          ),
        };

    for (final entry in required.entries) {
      final endpoint = registry.lookup(entry.key);
      expect(endpoint, isNotNull, reason: entry.key);
      expect(endpoint!.method, entry.value.method, reason: entry.key);
      expect(endpoint.pathTemplate, entry.value.path, reason: entry.key);
      expect(
        endpoint.pathTemplate.contains('/latest'),
        isFalse,
        reason: entry.key,
      );
      expect(endpoint.scope, entry.value.scope, reason: entry.key);
      expect(endpoint.ttl, entry.value.ttl, reason: entry.key);
      expect(endpoint.rateGroup, entry.value.rateGroup, reason: entry.key);
    }
  });
}
