import 'package:drift/drift.dart' show Value;
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';

const kAarSupportedEft = '''
[Rifter, Fight Fit]
Damage Control II

1MN Afterburner II

125mm Gatling AutoCannon II

Small Projectile Burst Aerator I

Hobgoblin II x5
''';

const kAarColonHeaderEft = '''
[Rifter, PvP: Armor]
Damage Control II
''';

const kAarSupportedDna = '587:2048;1::';

const kAarHeaderOnlyEft = '[Rifter, Test]\n';

const kAarPlaceholderEft = '''
[Rifter, Placeholders]
[Empty Low slot]
Damage Control II
[Empty Med slot]
[Empty High slot]
[Empty Rig slot]
[Empty Subsystem slot]
''';

const kAarWhitespaceCrlfEft =
    '\r\n  [Rifter, Spaced]  \r\n\r\nDamage Control II\r\n';

const kAarMixedUnknownEft = '''
[Rifter, Mixed]
Damage Control II
Unknown Module XYZ
''';

const kAarAllUnknownEft = '''
[Rifter, Unknowns]
Totally Unknown Module
Another Fake Module
''';

const kAarInvalidStackEft = '''
[Rifter, BadStack]
Hobgoblin II x0
''';

const kAarAmmoSuffixEft = '''
[Rifter, Ammo]
125mm Gatling AutoCannon II, EMP S
''';

const kAarNonShipHeaderEft = '[Damage Control II, Not A Ship]\n';

const kAarUnknownHullEft = '[No Such Hull, Test]\n';

const kAarBrokenHeaderEft = '[Rifter\nDamage Control II\n';

const kAarUniqueBeyond20Eft = '[UniqueShip, Test]\n';

const kAarImportSuccessMessage =
    'Pilot fit imported. Re-analyze to include it.';

const kAarMalformedUiMessage =
    'Unable to import fit: Check the EFT header and item names, then try again.';

const kAarUnresolvedUiMessage =
    'Unable to import fit: Some fit entries could not be resolved. Check the item names.';

const kAarAmmoUiMessage =
    'Unable to import fit: Loaded ammunition in EFT is not supported by this import.';

const kAarLocalDataUiMessage =
    'Unable to import fit: Local fitting data is unavailable. Try again after it loads.';

const kAarDirectHullMessage =
    'Unable to resolve the pasted fit. Paste an EFT fit with a known ship and modules.';

const kAarCaptureSuccessMessage =
    'Current fit confirmed for this AAR. Re-analyze to include it.';

const kAarCaptureEmptySuccessMessage =
    'Current fit confirmed for this AAR. No fitted modules were returned. Re-analyze to include it.';

const kAarCaptureReferenceMessage =
    'Current fit snapshot saved as reference evidence.';

const kAarCaptureNoCharacterUi =
    'Unable to capture fit: This log is not linked to an authenticated character.';

const kAarCaptureAuthUi =
    'Unable to capture fit: Reauthorize this character and try again.';

const kAarCaptureNoShipUi =
    'Unable to capture fit: ESI did not return a current ship. Try again or import a fit.';

const kAarCaptureAssetsUi =
    'Unable to capture fit: Character assets could not be loaded. Try again or import a fit.';

const kAarCaptureSaveUi =
    'Unable to capture fit: The snapshot could not be saved. Try again.';

const kAarImportSaveUi =
    'Unable to import fit: The fit could not be saved. Try again.';

const kAarKillmailId = 777001;
const kAarKillmailHash = 'aar-km-hash';
const kAarVictimCharacterId = 7001;
const kAarVictimName = 'Enemy';

Map<String, dynamic> aarMatchedKillmailJson({
  int killmailId = kAarKillmailId,
  int attackerCharacterId = 42,
  int victimCharacterId = kAarVictimCharacterId,
  String killmailTime = '2026-05-20T20:00:00Z',
}) {
  return {
    'killmail_id': killmailId,
    'killmail_hash': kAarKillmailHash,
    'killmail_time': killmailTime,
    'solar_system_id': 30000142,
    'victim': {
      'character_id': victimCharacterId,
      'character_name': kAarVictimName,
      'ship_type_id': 587,
      'damage_taken': 1200,
      'items': const <Map<String, dynamic>>[],
    },
    'attackers': [
      {
        'character_id': attackerCharacterId,
        'character_name': 'Pilot',
        'ship_type_id': 587,
        'damage_done': 1200,
        'final_blow': true,
      },
    ],
  };
}

const kAarEmptyModulesLimitation =
    'No fitted modules were returned for the current ship.';

const kAarShipItemId = 100001;
const kAarModuleItemId = 200001;
const kAarChargeItemId = 200002;
const kAarDroneItemId = 200003;
const kAarOtherShipItemId = 999999;
const kAarOtherModuleItemId = 300001;
const kAarShipBTypeId = 9020;
const kAarShipBItemId = 100002;

Map<String, dynamic> aarAssetJson({
  required int itemId,
  required int typeId,
  required int locationId,
  required String flag,
  int quantity = 1,
  bool singleton = true,
}) {
  return {
    'item_id': itemId,
    'type_id': typeId,
    'quantity': quantity,
    'location_id': locationId,
    'location_flag': flag,
    'is_singleton': singleton,
  };
}

List<Map<String, dynamic>> aarFittedPage1({int shipItemId = kAarShipItemId}) {
  return [
    aarAssetJson(
      itemId: kAarModuleItemId,
      typeId: 2048,
      locationId: shipItemId,
      flag: 'LoSlot0',
    ),
  ];
}

List<Map<String, dynamic>> aarFittedPage2({
  int shipItemId = kAarShipItemId,
  bool unrelated = true,
}) {
  return [
    aarAssetJson(
      itemId: kAarChargeItemId,
      typeId: 185,
      locationId: kAarModuleItemId,
      flag: 'HiSlot0',
      quantity: 250,
      singleton: false,
    ),
    aarAssetJson(
      itemId: kAarDroneItemId,
      typeId: 2456,
      locationId: shipItemId,
      flag: 'DroneBay',
      quantity: 5,
      singleton: false,
    ),
    if (unrelated)
      aarAssetJson(
        itemId: kAarOtherModuleItemId,
        typeId: 5973,
        locationId: kAarOtherShipItemId,
        flag: 'MedSlot0',
      ),
  ];
}

/// Structurally faithful local SDE for AAR import tests.
Future<void> seedAarImportSde(SdeDatabase sdeDb) async {
  await sdeDb.upsertCategories([
    SdeCategoriesCompanion.insert(
      categoryId: const Value(6),
      categoryName: 'Ship',
    ),
    SdeCategoriesCompanion.insert(
      categoryId: const Value(7),
      categoryName: 'Module',
    ),
    SdeCategoriesCompanion.insert(
      categoryId: const Value(8),
      categoryName: 'Charge',
    ),
    SdeCategoriesCompanion.insert(
      categoryId: const Value(16),
      categoryName: 'Skill',
    ),
    SdeCategoriesCompanion.insert(
      categoryId: const Value(18),
      categoryName: 'Drone',
    ),
  ]);
  await sdeDb.upsertGroups([
    SdeGroupsCompanion.insert(
      groupId: const Value(25),
      groupName: 'Frigate',
      categoryId: 6,
    ),
    SdeGroupsCompanion.insert(
      groupId: const Value(60),
      groupName: 'Damage Control',
      categoryId: 7,
    ),
    SdeGroupsCompanion.insert(
      groupId: const Value(83),
      groupName: 'Projectile Ammo',
      categoryId: 8,
    ),
    SdeGroupsCompanion.insert(
      groupId: const Value(100),
      groupName: 'Combat Drone',
      categoryId: 18,
    ),
    SdeGroupsCompanion.insert(
      groupId: const Value(255),
      groupName: 'Gunnery',
      categoryId: 16,
    ),
  ]);
  await sdeDb.upsertTypes([
    SdeTypesCompanion.insert(
      typeId: const Value(587),
      typeName: 'Rifter',
      groupId: 25,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(2048),
      typeName: 'Damage Control II',
      groupId: 60,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(5973),
      typeName: '1MN Afterburner II',
      groupId: 60,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(484),
      typeName: '125mm Gatling AutoCannon II',
      groupId: 60,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(3117),
      typeName: 'Small Projectile Burst Aerator I',
      groupId: 60,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(2456),
      typeName: 'Hobgoblin II',
      groupId: 100,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(185),
      typeName: 'EMP S',
      groupId: 83,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(3300),
      typeName: 'Gunnery',
      groupId: 255,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(9020),
      typeName: 'UniqueShip',
      groupId: 25,
    ),
    for (var i = 0; i < 20; i++)
      SdeTypesCompanion.insert(
        typeId: Value(9000 + i),
        typeName: 'A${i.toString().padLeft(2, '0')} UniqueShip',
        groupId: 25,
      ),
  ]);
  await sdeDb.upsertTypeEffects([
    SdeTypeEffectsCompanion.insert(typeId: 2048, effectId: 11),
    SdeTypeEffectsCompanion.insert(typeId: 5973, effectId: 13),
    SdeTypeEffectsCompanion.insert(typeId: 484, effectId: 12),
    SdeTypeEffectsCompanion.insert(typeId: 3117, effectId: 2663),
  ]);
  await sdeDb.upsertTypeAttributes([
    SdeTypeAttributesCompanion.insert(typeId: 587, attributeId: 9, value: 350),
    SdeTypeAttributesCompanion.insert(
      typeId: 587,
      attributeId: 263,
      value: 450,
    ),
  ]);
  await sdeDb.setMetadata('dogma_version', '${SdeService.bundledDogmaVersion}');
}
