import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/data/market_sync_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../integration_test/test_utils/fixtures/market_fixtures.dart';
import '../../../../integration_test/test_utils/mocks/mock_esi_client.dart';
import 'package:mimir/features/market/data/market_repository.dart';
import 'package:mimir/core/database/app_database.dart';

class MockMarketRepository extends Mock implements MarketRepository {}

void main() {
  late MockEsiClient mockEsiClient;
  late MockMarketRepository mockRepository;
  late MarketSyncService syncService;

  setUp(() {
    mockEsiClient = MockEsiClient();
    mockRepository = MockMarketRepository();
    syncService = MarketSyncService(mockEsiClient, mockRepository);
    
    registerFallbackValue(<MarketOrdersCompanion>[]);
    registerFallbackValue(<MarketPricesCompanion>[]);
  });

  group('MarketSyncService', () {
    const characterId = 12345;

    test('syncOrders fetches from ESI and saves to repository', () async {
      // Setup mock
      mockEsiClient.setupMarketData(characterId);
      when(() => mockRepository.replaceAllOrders(any(), any()))
          .thenAnswer((_) async {});

      // Execute
      await syncService.syncOrders(characterId);

      // Verify
      verify(() => mockEsiClient.getCharacterOrders(characterId)).called(1);
      verify(() => mockRepository.replaceAllOrders(
        characterId,
        any(that: isA<List<MarketOrdersCompanion>>()),
      )).called(1);
    });

    test('syncPrices fetches from ESI and saves to repository', () async {
      // Setup mock
      mockEsiClient.setupMarketData(characterId);
      when(() => mockRepository.replaceAllPrices(any()))
          .thenAnswer((_) async {});

      // Execute
      await syncService.syncPrices();

      // Verify
      verify(() => mockEsiClient.getMarketPrices()).called(1);
      verify(() => mockRepository.replaceAllPrices(
        any(that: isA<List<MarketPricesCompanion>>()),
      )).called(1);
    });
  });
}
