import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/assets/data/asset_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;

void main() {
  late AppDatabase database;
  late AssetRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = AssetRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('AssetRepository', () {
    const characterId = 12345678;

    test('replaceAllAssets and watchAssets', () async {
      final assets = [
        AssetsCompanion.insert(
          itemId: 1001,
          characterId: characterId,
          typeId: 587, // Rifter
          locationId: 60003760,
          locationFlag: 'Hangar',
          quantity: 1,
          isSingleton: true,
          typeName: 'Rifter',
        ),
      ];

      await repository.replaceAllAssets(characterId, assets);

      final savedAssets = await repository.watchAssets(characterId).first;
      expect(savedAssets, hasLength(1));
      expect(savedAssets[0].itemId, 1001);
      expect(savedAssets[0].typeName, 'Rifter');
    });

    test('upsertLocations and getLocation', () async {
      final now = DateTime.now();
      final locations = [
        AssetLocationsCompanion.insert(
          locationId: const Value(60003760),
          locationType: 'station',
          locationName: 'Jita IV - Moon 4',
          lastResolved: now,
        ),
      ];

      await repository.upsertLocations(locations);

      final loc = await repository.getLocation(60003760);
      expect(loc, isNotNull);
      expect(loc!.locationName, 'Jita IV - Moon 4');
    });

    test('watchAssetsByLocation', () async {
      final assets = [
        AssetsCompanion.insert(
          itemId: 1001,
          characterId: characterId,
          typeId: 587,
          locationId: 1,
          locationFlag: 'Hangar',
          quantity: 1,
          isSingleton: true,
          typeName: 'Rifter',
        ),
        AssetsCompanion.insert(
          itemId: 1002,
          characterId: characterId,
          typeId: 603,
          locationId: 1,
          locationFlag: 'Hangar',
          quantity: 1,
          isSingleton: true,
          typeName: 'Megathron',
        ),
        AssetsCompanion.insert(
          itemId: 1003,
          characterId: characterId,
          typeId: 34,
          locationId: 2,
          locationFlag: 'Hangar',
          quantity: 1000,
          isSingleton: false,
          typeName: 'Tritanium',
        ),
      ];

      await repository.replaceAllAssets(characterId, assets);

      final grouped = await repository.watchAssetsByLocation(characterId).first;
      expect(grouped, hasLength(2));
      expect(grouped[1], hasLength(2));
      expect(grouped[2], hasLength(1));
    });
  });
}
