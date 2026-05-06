import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/pi/data/planetary_repository.dart';
import 'package:mimir/features/pi/data/planetary_sync_service.dart';
import 'package:mocktail/mocktail.dart';

class MockEsiClient extends Mock implements EsiClient {}
class MockPlanetaryRepository extends Mock implements PlanetaryRepository {}

void main() {
  late MockEsiClient mockEsiClient;
  late MockPlanetaryRepository mockRepository;
  late PlanetarySyncService syncService;

  setUp(() {
    mockEsiClient = MockEsiClient();
    mockRepository = MockPlanetaryRepository();
    syncService = PlanetarySyncService(
      esiClient: mockEsiClient,
      repository: mockRepository,
    );

    registerFallbackValue([]);
  });

  group('PlanetarySyncService', () {
    const characterId = 12345678;

    test('syncColonies fetches and saves data', () async {
      final now = DateTime.now();
      
      final esiColonies = [
        EsiPlanetaryColony(
          planetId: 40000001,
          planetType: 'Temperate',
          solarSystemId: 30000142,
          lastUpdate: now,
          upgradeLevel: 5,
          numPins: 2,
        ),
      ];

      final esiPins = [
        EsiPlanetaryPin(
          pinId: 101,
          typeId: 2500,
          latitude: 1.0,
          longitude: 2.0,
          installTime: now,
        ),
      ];

      when(() => mockEsiClient.getCharacterPlanets(characterId))
          .thenAnswer((_) async => esiColonies);
      when(() => mockEsiClient.getCharacterPlanetPins(characterId, any()))
          .thenAnswer((_) async => esiPins);
      when(() => mockRepository.saveColonies(characterId, any(), any()))
          .thenAnswer((_) async => {});

      await syncService.syncColonies(characterId);

      verify(() => mockEsiClient.getCharacterPlanets(characterId)).called(1);
      verify(() => mockEsiClient.getCharacterPlanetPins(characterId, 40000001)).called(1);
      verify(() => mockRepository.saveColonies(characterId, any(), any())).called(1);
    });

    test('syncColonies handles errors gracefully', () async {
      when(() => mockEsiClient.getCharacterPlanets(characterId))
          .thenThrow(Exception('ESI Error'));

      expect(
        () => syncService.syncColonies(characterId),
        throwsA(isA<Exception>()),
      );
    });
  });
}
