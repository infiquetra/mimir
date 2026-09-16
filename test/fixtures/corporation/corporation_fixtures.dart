import 'dart:convert';
import 'dart:io';

import 'package:mimir/features/corporation/domain/corporation_access.dart';
import 'package:mimir/features/corporation/domain/corporation_context.dart';
import 'package:mimir/features/corporation/domain/corporation_decimal.dart';
import 'package:mimir/features/corporation/domain/corporation_oracles.dart';

final kCorporationT0 = DateTime.utc(2026, 9, 15, 12);

const kHeliosId = 7001;
const kSeleneId = 7002;
const kAdaId = 1;
const kBeaId = 2;
const kCyraId = 3;
const kDaraId = 4;
const kErenId = 5;
const kFinnId = 6;
const kGaleId = 7;
const kHanaId = 8;
const kIonaId = 9;
const kAlphaWorksId = 8001;
const kAlphaStationId = 6001;

String corporationFixture(String name) =>
    File('test/fixtures/corporation/$name').readAsStringSync();

Map<String, dynamic> corporationJson(String name) =>
    jsonDecode(corporationFixture(name)) as Map<String, dynamic>;

List<dynamic> corporationJsonList(String name) =>
    jsonDecode(corporationFixture(name)) as List<dynamic>;

class F1Character {
  const F1Character({
    required this.id,
    required this.name,
    this.general = const [],
    this.hq = const [],
    this.base = const [],
    this.other = const [],
    this.assigned = const [],
    this.grantedScopes = const {},
    this.grantableUnknown = false,
  });

  final int id;
  final String name;
  final List<String> general;
  final List<String> hq;
  final List<String> base;
  final List<String> other;
  final List<String> assigned;
  final Set<String> grantedScopes;
  final bool grantableUnknown;

  CorporationContext context({int corporationId = kHeliosId}) {
    return CorporationContext(
      characterId: id,
      corporationId: corporationId,
      incarnation: OwnerIncarnation(characterId: id, uuid: 'inc-$id'),
      grant: CharacterGrant(characterId: id, scopes: grantedScopes.toList()),
    );
  }

  RoleEvidence evidence() =>
      RoleEvidence(general: general, hq: hq, base: base, other: other);
}

class F1Fixtures {
  static const featureScopes = {
    'esi-corporations.read_corporation_membership.v1',
    'esi-corporations.read_divisions.v1',
    'esi-corporations.track_members.v1',
    'esi-corporations.read_titles.v1',
    'esi-assets.read_corporation_assets.v1',
    'esi-corporations.read_structures.v1',
    'esi-wallet.read_corporation_wallets.v1',
  };

  static F1Character ada() => const F1Character(
    id: kAdaId,
    name: 'Ada',
    hq: ['Hangar_Query_1'],
    base: ['Hangar_Take_2'],
    other: ['Container_Take_3'],
    grantedScopes: featureScopes,
  );

  static F1Character adaMalformedHqDirector() => const F1Character(
    id: kAdaId,
    name: 'Ada',
    hq: ['Director'],
    grantedScopes: featureScopes,
  );

  static F1Character bea() => const F1Character(
    id: kBeaId,
    name: 'Bea',
    general: ['Personnel_Manager'],
    grantedScopes: featureScopes,
  );

  static F1Character cyra() => const F1Character(
    id: kCyraId,
    name: 'Cyra',
    general: ['Director'],
    grantedScopes: featureScopes,
  );

  static F1Character dara() => const F1Character(
    id: kDaraId,
    name: 'Dara',
    general: ['Station_Manager'],
    grantedScopes: featureScopes,
  );

  static F1Character eren() => const F1Character(
    id: kErenId,
    name: 'Eren',
    general: ['Accountant'],
    grantedScopes: featureScopes,
  );

  static F1Character finn() => const F1Character(
    id: kFinnId,
    name: 'Finn',
    general: ['Junior_Accountant'],
    grantedScopes: featureScopes,
  );

  static F1Character gale() => const F1Character(
    id: kGaleId,
    name: 'Gale',
    general: ['Director'],
    grantedScopes: {'esi-wallet.read_corporation_wallets.v1'},
  );

  static F1Character hana() => const F1Character(
    id: kHanaId,
    name: 'Hana',
    assigned: ['Account_Take_2', 'Hangar_Query_2'],
    grantedScopes: featureScopes,
  );

  static F1Character iona() => const F1Character(
    id: kIonaId,
    name: 'Iona',
    grantableUnknown: true,
    grantedScopes: featureScopes,
  );

  static List<F1Character> allNine() => [
    ada(),
    bea(),
    cyra(),
    dara(),
    eren(),
    finn(),
    gale(),
    hana(),
    iona(),
  ];
}

class F2Fixtures {
  static Map<String, dynamic> currentProfile() =>
      corporationJson('f2_profile.json');

  static Map<String, dynamic> legacyProfile() =>
      corporationJson('f2_legacy_tax.json');

  static Map<String, dynamic> roster() => corporationJson('f2_roster.json');
}

class F3Fixtures {
  static const prices = <int, String>{
    100: '100',
    101: '2.50',
    4051: '10',
    102: '500',
    103: '50',
    104: '999',
  };

  static const names = <int, String>{
    100: 'Small Container',
    101: 'Test Ammunition',
    4051: 'Nitrogen Fuel Block',
    102: 'Test Ship',
    103: 'Test Module',
    104: 'Test Blueprint',
    9999: 'unresolved',
    6001: 'Alpha Station',
  };

  static List<CorporateAssetRow> rows() {
    return [
      for (final raw in corporationJsonList('f3_assets.json'))
        CorporateAssetRow(
          itemId: raw['item_id'] as int,
          typeId: raw['type_id'] as int,
          quantity: raw['quantity'] as num,
          locationId: raw['location_id'] as int,
          locationType: raw['location_type'] as String,
          flag: raw['location_flag'] as String? ?? '',
          isBlueprintCopy: raw['is_blueprint_copy'] as bool? ?? false,
          administrative: (raw['location_flag'] as String?) == 'OfficeFolder',
        ),
    ];
  }

  static Map<int, ExactDecimal> priceMap() => {
    for (final entry in prices.entries)
      entry.key: ExactDecimal.parse(entry.value),
  };
}

class F4Fixtures {
  static DateTime get expiresAt => DateTime.utc(2026, 9, 18);

  static List<FuelBayRow> bay() {
    final raw = corporationJson('f4_fuel.json');
    return [
      for (final row in raw['bay'] as List)
        FuelBayRow(
          typeId: row['type_id'] as int,
          quantity: row['quantity'] as int,
          flag: row['location_flag'] as String,
          nested: row['nested'] as bool? ?? false,
          inShip: row['inShip'] as bool? ?? false,
        ),
    ];
  }
}

class F5Fixtures {
  static Map<String, dynamic> wallets() => corporationJson('f5_wallets.json');

  static List<ExactDecimal> balances() {
    final rows = wallets()['balances'] as List;
    return [
      for (final row in rows) ExactDecimal.parse(row['balance'] as String),
    ];
  }
}

class F8Fixtures {
  static const widths = [320.0, 600.0, 900.0, 1200.0];
  static const textScales = [1.0, 2.0];
  static const extremeIsk = '-1234567890123456.78';
  static String longName() => 'A' * 80;
}
