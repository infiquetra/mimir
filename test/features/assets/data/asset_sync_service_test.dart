import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/assets/data/asset_repository.dart';
import 'package:mimir/features/assets/data/asset_sync_service.dart';
import 'package:mimir/features/characters/data/character_status_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockEsiClient extends Mock implements EsiClient {}
class MockAssetRepository extends Mock implements AssetRepository {}
class MockCharacterStatusRepository extends Mock implements CharacterStatusRepository {}

void main() {
  late MockEsiClient mockEsiClient;
  late MockAssetRepository mockRepository;
  late MockCharacterStatusRepository mockStatusRepo;
  late AssetSyncService syncService;

  setUp(() {
    mockEsiClient = MockEsiClient();
    mockRepository = MockAssetRepository();
    mockStatusRepo = MockCharacterStatusRepository();
    syncService = AssetSyncService(
      esiClient: mockEsiClient,
      repository: mockRepository,
      statusRepo: mockStatusRepo,
    );

    registerFallbackValue([]);
  });

  group('AssetSyncService', () {
    const characterId = 12345678;

    test('syncAssets fetches paginated data and resolves names', () async {
      final esiAssets = [
        const AssetItem(
          itemId: 1001,
          typeId: 587,
          locationId: 60003760,
          locationFlag: 'Hangar',
          quantity: 1,
          isSingleton: true,
        ),
      ];

      when(() => mockEsiClient.getCharacterAssets(characterId, page: 1))
          .thenAnswer((_) async => EsiResponse(
                data: esiAssets,
                headers: {'x-pages': ['1']},
                statusCode: 200,
              ));

      when(() => mockRepository.getLocation(any())).thenAnswer((_) async => null);
      when(() => mockStatusRepo.resolveNames(any())).thenAnswer((_) async => []);
      when(() => mockStatusRepo.resolveStructureNames(any(), any())).thenAnswer((_) async => {});
      when(() => mockEsiClient.getCharacterAssetNames(characterId, any())).thenAnswer((_) async => []);
      when(() => mockRepository.upsertLocations(any())).thenAnswer((_) async => {});
      when(() => mockRepository.replaceAllAssets(characterId, any())).thenAnswer((_) async => {});

      await syncService.syncAssets(characterId);

      verify(() => mockEsiClient.getCharacterAssets(characterId, page: 1)).called(1);
      verify(() => mockRepository.replaceAllAssets(characterId, any())).called(1);
    });
  });
}
