import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/industry/data/industry_repository.dart';

void main() {
  late AppDatabase database;
  late IndustryRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = IndustryRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('IndustryRepository', () {
    const characterId = 12345;

    test('watchBlueprints returns blueprints for character', () async {
      // Insert test data
      final companions = [
        BlueprintsCompanion.insert(
          itemId: 1000,
          characterId: characterId,
          typeId: 689,
          locationId: 60003760,
          quantity: 1,
          timeEfficiency: 20,
          materialEfficiency: 10,
          runs: -1,
          isOriginal: true,
        ),
      ];

      await repository.replaceAllBlueprints(characterId, companions);

      // Watch and verify
      final stream = repository.watchBlueprints(characterId);
      final blueprints = await stream.first;

      expect(blueprints.length, 1);
      expect(blueprints.first.itemId, 1000);
      expect(blueprints.first.isOriginal, isTrue);
    });

    test('watchIndustryJobs filters correctly', () async {
      // Insert test data with different statuses
      final companions = [
        IndustryJobsCompanion.insert(
          jobId: 1,
          characterId: characterId,
          installerId: characterId,
          facilityId: 60003760,
          locationId: 60003760,
          activityId: 1,
          blueprintId: 1000,
          blueprintTypeId: 689,
          outputLocationId: 60003760,
          runs: 1,
          cost: 1000,
          status: 'active',
          timeInSeconds: 3600,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(hours: 1)),
        ),
        IndustryJobsCompanion.insert(
          jobId: 2,
          characterId: characterId,
          installerId: characterId,
          facilityId: 60003760,
          locationId: 60003760,
          activityId: 1,
          blueprintId: 1001,
          blueprintTypeId: 689,
          outputLocationId: 60003760,
          runs: 1,
          cost: 1000,
          status: 'delivered',
          timeInSeconds: 3600,
          startDate: DateTime.now().subtract(const Duration(hours: 2)),
          endDate: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];

      await repository.replaceAllIndustryJobs(characterId, companions);

      // Watch without completed jobs
      final activeStream = repository.watchIndustryJobs(characterId, includeCompleted: false);
      final activeJobs = await activeStream.first;
      expect(activeJobs.length, 1);
      expect(activeJobs.first.status, 'active');

      // Watch with completed jobs
      final allStream = repository.watchIndustryJobs(characterId, includeCompleted: true);
      final allJobs = await allStream.first;
      expect(allJobs.length, 2);
    });
  });
}
