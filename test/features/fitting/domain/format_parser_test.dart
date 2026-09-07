import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/fitting/domain/format_parser.dart';
import 'package:mimir/features/fitting/domain/models.dart';

class MockSdeService extends Mock implements SdeService {}

void main() {
  group('FittingFormatParser', () {
    late MockSdeService mockSdeService;
    late FittingFormatParser parser;

    setUp(() {
      mockSdeService = MockSdeService();
      parser = FittingFormatParser(mockSdeService);
    });

    test('parseEft parses valid EFT string', () async {
      const eftString = '''
[Rifter, PvP]
Damage Control II
Small Armor Repairer II

1MN Afterburner II
Warp Scrambler II
Stasis Webifier II

200mm AutoCannon II
200mm AutoCannon II
200mm AutoCannon II
Rocket Launcher II

Small Projectile Burst Aerator I
Small Projectile Collision Accelerator I
''';
      final fitting = await parser.parseEft(eftString);

      expect(fitting, isNotNull);
      expect(fitting!.shipName, 'Rifter');
      expect(fitting.name, 'PvP');
    });

    test('parseEft resolves ship and modules into slot groups', () async {
      final database = SdeDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await _insertType(database, 587, 'Rifter');
      await _insertType(database, 2048, 'Damage Control II', effectId: 11);
      await _insertType(database, 5973, '1MN Afterburner II', effectId: 13);
      await _insertType(
        database,
        484,
        '125mm Gatling AutoCannon II',
        effectId: 12,
      );
      await _insertType(
        database,
        3117,
        'Small Projectile Burst Aerator I',
        effectId: 2663,
      );

      final parser = FittingFormatParser(SdeService(database: database));
      final fitting = await parser.parseEft('''
[Rifter, PvP]
Damage Control II

1MN Afterburner II

125mm Gatling AutoCannon II

Small Projectile Burst Aerator I
''');

      expect(fitting, isNotNull);
      expect(fitting!.shipTypeId, 587);
      expect(fitting.lowSlots.single.typeId, 2048);
      expect(fitting.medSlots.single.typeId, 5973);
      expect(fitting.highSlots.single.typeId, 484);
      expect(fitting.rigSlots.single.typeId, 3117);
    });

    test('generateEft creates valid EFT string', () {
      final fitting = Fitting(
        id: '1',
        name: 'PvP',
        shipTypeId: 587,
        shipName: 'Rifter',
        highSlots: [
          FittedModule(
            typeId: 1,
            typeName: '200mm AutoCannon II',
            state: ModuleState.online,
            slotType: SlotType.high,
            slotIndex: 0,
          ),
          FittedModule(
            typeId: 2,
            typeName: 'Rocket Launcher II',
            state: ModuleState.online,
            slotType: SlotType.high,
            slotIndex: 1,
          ),
        ],
        medSlots: [
          FittedModule(
            typeId: 3,
            typeName: '1MN Afterburner II',
            state: ModuleState.online,
            slotType: SlotType.med,
            slotIndex: 0,
          ),
        ],
        lowSlots: [
          FittedModule(
            typeId: 4,
            typeName: 'Damage Control II',
            state: ModuleState.online,
            slotType: SlotType.low,
            slotIndex: 0,
          ),
        ],
        rigSlots: [],
      );

      final eft = parser.generateEft(fitting);

      expect(eft, contains('[Rifter, PvP]'));
      expect(eft, contains('Damage Control II'));
      expect(eft, contains('1MN Afterburner II'));
      expect(eft, contains('200mm AutoCannon II'));
    });

    test('parseDna and generateDna work together', () async {
      // Mocking SDE lookups
      when(
        () => mockSdeService.getShipTypeName(587),
      ).thenAnswer((_) async => 'Rifter');
      when(() => mockSdeService.getModuleType(2048)).thenAnswer(
        (_) async => ModuleType(
          typeId: 2048,
          name: 'Damage Control II',
          groupId: 0,
          groupName: '',
          slotType: SlotType.low,
          metaLevel: 5,
          techLevel: 2,
          cpu: 30,
          powergrid: 1,
          calibration: 0,
          baseAttributes: {},
          effects: [],
          skillRequirements: [],
          acceptedChargeGroups: [],
        ),
      );

      final fitting = Fitting(
        id: '1',
        name: 'Imported Rifter',
        shipTypeId: 587,
        shipName: 'Rifter',
        highSlots: [],
        medSlots: [],
        lowSlots: [
          FittedModule(
            typeId: 2048,
            typeName: 'Damage Control II',
            state: ModuleState.online,
            slotType: SlotType.low,
            slotIndex: 0,
          ),
          FittedModule(
            typeId: 2048,
            typeName: 'Damage Control II',
            state: ModuleState.online,
            slotType: SlotType.low,
            slotIndex: 1,
          ),
        ],
        rigSlots: [],
      );

      final dna = parser.generateDna(fitting);
      expect(dna, '587:2048;2::');

      final parsed = await parser.parseDna(dna);
      expect(parsed, isNotNull);
      expect(parsed!.shipTypeId, 587);

      // The modules must survive the import: an earlier implementation parsed
      // the hull and silently dropped every module segment.
      expect(parsed.lowSlots, hasLength(2));
      expect(parsed.lowSlots.map((m) => m.typeId), [2048, 2048]);
      expect(parsed.lowSlots.map((m) => m.slotIndex), [0, 1]);
      expect(parsed.allModules, hasLength(2));

      // And the round trip must be lossless.
      expect(parser.generateDna(parsed), dna);
    });

    test(
      'parseDna expands quantities into the module\'s real slot type',
      () async {
        when(
          () => mockSdeService.getShipTypeName(587),
        ).thenAnswer((_) async => 'Rifter');
        when(() => mockSdeService.getModuleType(2048)).thenAnswer(
          (_) async => _moduleType(2048, 'Damage Control II', SlotType.low),
        );
        when(() => mockSdeService.getModuleType(5973)).thenAnswer(
          (_) async => _moduleType(5973, '1MN Afterburner II', SlotType.med),
        );
        when(() => mockSdeService.getModuleType(484)).thenAnswer(
          (_) async =>
              _moduleType(484, '125mm Gatling AutoCannon II', SlotType.high),
        );

        final parsed = await parser.parseDna('587:2048;2:5973;1:484;3::');

        expect(parsed, isNotNull);
        expect(parsed!.lowSlots, hasLength(2));
        expect(parsed.medSlots, hasLength(1));
        expect(parsed.highSlots, hasLength(3));
        expect(parsed.highSlots.every((m) => m.typeId == 484), isTrue);
      },
    );

    test('parseDna skips module IDs the SDE does not know', () async {
      when(
        () => mockSdeService.getShipTypeName(587),
      ).thenAnswer((_) async => 'Rifter');
      when(
        () => mockSdeService.getModuleType(999999),
      ).thenAnswer((_) async => null);

      final parsed = await parser.parseDna('587:999999;1::');

      expect(parsed, isNotNull);
      expect(parsed!.allModules, isEmpty);
    });
  });
}

ModuleType _moduleType(int typeId, String name, SlotType slotType) =>
    ModuleType(
      typeId: typeId,
      name: name,
      groupId: 0,
      groupName: '',
      slotType: slotType,
      metaLevel: 5,
      techLevel: 2,
      cpu: 30,
      powergrid: 1,
      calibration: 0,
      baseAttributes: {},
      effects: [],
      skillRequirements: [],
      acceptedChargeGroups: [],
    );

Future<void> _insertType(
  SdeDatabase database,
  int typeId,
  String typeName, {
  int? effectId,
}) async {
  await database
      .into(database.sdeTypes)
      .insert(
        SdeTypesCompanion.insert(
          typeId: Value(typeId),
          typeName: typeName,
          groupId: 1,
        ),
      );
  if (effectId != null) {
    await database
        .into(database.sdeTypeEffects)
        .insert(
          SdeTypeEffectsCompanion.insert(typeId: typeId, effectId: effectId),
        );
  }
}
