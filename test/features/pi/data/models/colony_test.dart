import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/pi/data/models/colony.dart';

void main() {
  group('Colony toString()', () {
    test('returns formatted string with all key properties', () {
      final colony = Colony(
        characterId: 123456,
        planetId: 789012,
        planetType: 'Temperate',
        solarSystemName: 'Jita',
        solarSystemId: 30000142,
        lastUpdated: DateTime(2026, 4, 18, 12, 0, 0),
        upgradeLevel: 5,
        numPins: 3,
        pins: [],
      );

      final result = colony.toString();

      expect(result, contains('Colony('));
      expect(result, contains('characterId: 123456'));
      expect(result, contains('planetId: 789012'));
      expect(result, contains('planetType: Temperate'));
      expect(result, contains('solarSystem: Jita'));
      expect(result, contains('upgradeLevel: 5'));
      expect(result, contains('numPins: 3'));
      expect(result, contains('status: ColonyStatus.unknown'));
    });

    test('includes running status when extractors are active', () {
      final extractor = Extractor(
        pinId: 1,
        typeId: 2,
        typeName: 'Extractor Control Unit',
        latitude: 10.5,
        longitude: 20.3,
        productTypeId: 1234,
        lastCycleStart: DateTime.now().subtract(const Duration(hours: 2)),
        lastCycleDuration: const Duration(hours: 4),
        expiryTime: DateTime.now().add(const Duration(hours: 2)),
        qtyPerCycle: 100,
      );

      final colony = Colony(
        characterId: 111111,
        planetId: 222222,
        planetType: 'Gas',
        solarSystemName: 'Amarr',
        solarSystemId: 30000277,
        lastUpdated: DateTime.now(),
        upgradeLevel: 3,
        numPins: 1,
        pins: [extractor],
      );

      final result = colony.toString();

      expect(result, contains('status: ColonyStatus.running'));
    });

    test('includes notRunning status when extractor is idle', () {
      final idleExtractor = Extractor(
        pinId: 1,
        typeId: 2,
        typeName: 'Extractor Control Unit',
        latitude: 10.5,
        longitude: 20.3,
        productTypeId: 1234,
        // No lastCycleStart means idle
        lastCycleStart: null,
        lastCycleDuration: null,
        expiryTime: null,
        qtyPerCycle: null,
      );

      final colony = Colony(
        characterId: 333333,
        planetId: 444444,
        planetType: 'Ice',
        solarSystemName: 'Dodixie',
        solarSystemId: 30000379,
        lastUpdated: DateTime.now(),
        upgradeLevel: 2,
        numPins: 1,
        pins: [idleExtractor],
      );

      final result = colony.toString();

      expect(result, contains('status: ColonyStatus.notRunning'));
    });

    test('includes expiring status when extractor expires soon', () {
      final expiringExtractor = Extractor(
        pinId: 1,
        typeId: 2,
        typeName: 'Extractor Control Unit',
        latitude: 10.5,
        longitude: 20.3,
        productTypeId: 1234,
        lastCycleStart: DateTime.now().subtract(const Duration(hours: 3)),
        lastCycleDuration: const Duration(hours: 4),
        expiryTime: DateTime.now().add(const Duration(minutes: 30)),
        qtyPerCycle: 100,
      );

      final colony = Colony(
        characterId: 555555,
        planetId: 666666,
        planetType: 'Lava',
        solarSystemName: 'Hek',
        solarSystemId: 30000242,
        lastUpdated: DateTime.now(),
        upgradeLevel: 4,
        numPins: 1,
        pins: [expiringExtractor],
      );

      final result = colony.toString();

      expect(result, contains('status: ColonyStatus.expiring'));
    });
  });
}
