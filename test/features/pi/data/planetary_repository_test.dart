import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/pi/data/planetary_repository.dart';

void main() {
  late AppDatabase database;
  late PlanetaryRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PlanetaryRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('PlanetaryRepository', () {
    const characterId = 12345678;
    const planetId = 40000001;

    test('saveColonies and watchColonies', () async {
      final now = DateTime.now();
      
      // 1. Insert character
      await database.into(database.characters).insert(
            CharactersCompanion.insert(
              characterId: Value(characterId),
              name: 'Test Character',
              accessToken: const Value('token'),
              refreshToken: const Value('refresh'),
              tokenExpiry: now.add(const Duration(hours: 1)),
              corporationId: 10001,
              corporationName: 'Test Corp',
              portraitUrl: 'url',
              lastUpdated: now,
            ),
          );

      final colonies = [
        PlanetaryColoniesCompanion.insert(
          planetId: planetId,
          characterId: characterId,
          planetName: 'Jita IV',
          planetType: 'Temperate',
          upgradeLevel: 5,
          numPins: 10,
          lastUpdate: now,
        ),
      ];

      final pins = [
        PlanetaryPinsCompanion.insert(
          pinId: 101,
          characterId: characterId,
          planetId: planetId,
          typeId: 2500,
          latitude: 1.0,
          longitude: 2.0,
          installTime: now,
        ),
      ];

      // Save
      await repository.saveColonies(characterId, colonies, pins);

      // Verify Colonies
      final savedColonies = await repository.getColonies(characterId);
      expect(savedColonies, hasLength(1));
      expect(savedColonies[0].planetName, 'Jita IV');

      // Verify Streams
      final colonyStream = repository.watchColonies(characterId);
      expect(colonyStream, emits(contains(isA<PlanetaryColony>())));

      final pinStream = repository.watchPins(characterId, planetId);
      expect(pinStream, emits(contains(isA<PlanetaryPin>())));
    });

    test('watchAllColonies', () async {
      final now = DateTime.now();
      
      // Insert multiple characters and colonies
      await database.into(database.characters).insert(
            CharactersCompanion.insert(
              characterId: const Value(1),
              name: 'Char 1',
              accessToken: const Value('t1'),
              refreshToken: const Value('r1'),
              tokenExpiry: now,
              corporationId: 10001,
              corporationName: 'Test Corp',
              portraitUrl: 'url',
              lastUpdated: now,
            ),
          );
      await database.into(database.characters).insert(
            CharactersCompanion.insert(
              characterId: const Value(2),
              name: 'Char 2',
              accessToken: const Value('t2'),
              refreshToken: const Value('r2'),
              tokenExpiry: now,
              corporationId: 10001,
              corporationName: 'Test Corp',
              portraitUrl: 'url',
              lastUpdated: now,
            ),
          );

      await repository.saveColonies(1, [
        PlanetaryColoniesCompanion.insert(
          planetId: 101,
          characterId: 1,
          planetName: 'Planet A',
          planetType: 'Barren',
          upgradeLevel: 1,
          numPins: 1,
          lastUpdate: now,
        ),
      ], []);

      await repository.saveColonies(2, [
        PlanetaryColoniesCompanion.insert(
          planetId: 201,
          characterId: 2,
          planetName: 'Planet B',
          planetType: 'Gas',
          upgradeLevel: 1,
          numPins: 1,
          lastUpdate: now,
        ),
      ], []);

      final allColonies = await repository.watchAllColonies().first;
      expect(allColonies, hasLength(2));
      expect(allColonies.any((c) => c.planetName == 'Planet A'), isTrue);
      expect(allColonies.any((c) => c.planetName == 'Planet B'), isTrue);
    });
  });
}
