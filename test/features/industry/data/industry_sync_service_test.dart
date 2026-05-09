import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/industry/data/industry_sync_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../integration_test/test_utils/fixtures/industry_fixtures.dart';
import '../../../../integration_test/test_utils/mocks/mock_esi_client.dart';
import 'package:mimir/features/industry/data/industry_repository.dart';
import 'package:mimir/core/database/app_database.dart';

class MockIndustryRepository extends Mock implements IndustryRepository {}

void main() {
  late MockEsiClient mockEsiClient;
  late MockIndustryRepository mockRepository;
  late IndustrySyncService syncService;

  setUp(() {
    mockEsiClient = MockEsiClient();
    mockRepository = MockIndustryRepository();
    syncService = IndustrySyncService(mockEsiClient, mockRepository);
    
    registerFallbackValue(<BlueprintsCompanion>[]);
    registerFallbackValue(<IndustryJobsCompanion>[]);
  });

  group('IndustrySyncService', () {
    const characterId = 12345;

    test('syncBlueprints fetches from ESI and saves to repository', () async {
      // Setup mock
      mockEsiClient.setupIndustryData(characterId);
      when(() => mockRepository.replaceAllBlueprints(any(), any()))
          .thenAnswer((_) async {});

      // Execute
      await syncService.syncBlueprints(characterId);

      // Verify
      verify(() => mockEsiClient.getCharacterBlueprints(characterId, page: 1)).called(1);
      verify(() => mockRepository.replaceAllBlueprints(
        characterId,
        any(that: isA<List<BlueprintsCompanion>>()),
      )).called(1);
    });

    test('syncIndustryJobs fetches from ESI and saves to repository', () async {
      // Setup mock
      mockEsiClient.setupIndustryData(characterId);
      when(() => mockRepository.replaceAllIndustryJobs(any(), any()))
          .thenAnswer((_) async {});

      // Execute
      await syncService.syncIndustryJobs(characterId, includeCompleted: true);

      // Verify
      verify(() => mockEsiClient.getCharacterIndustryJobs(characterId, includeCompleted: true)).called(1);
      verify(() => mockRepository.replaceAllIndustryJobs(
        characterId,
        any(that: isA<List<IndustryJobsCompanion>>()),
      )).called(1);
    });
  });
}
