import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/esi_client.dart';
import '../../../core/logging/logger.dart';
import 'industry_repository.dart';

/// Service for synchronizing Industry data from ESI.
class IndustrySyncService {
  final EsiClient _esiClient;
  final IndustryRepository _repository;

  IndustrySyncService(this._esiClient, this._repository);

  /// Fetch and store all blueprints for a character.
  Future<void> syncBlueprints(int characterId) async {
    Log.d('INDUSTRY.SYNC', 'syncBlueprints($characterId) - START');
    try {
      final List<BlueprintItem> allItems = [];
      int page = 1;
      int? totalPages;

      do {
        final response = await _esiClient.getCharacterBlueprints(characterId, page: page);
        allItems.addAll(response.data);

        if (totalPages == null) {
          final pagesHeader = response.headers['x-pages']?.firstOrNull;
          if (pagesHeader != null) {
            totalPages = int.tryParse(pagesHeader);
          }
        }
        
        Log.d('INDUSTRY.SYNC', 'Fetched blueprints page $page of ${totalPages ?? 1}');
        page++;
      } while (totalPages != null && page <= totalPages);

      Log.i('INDUSTRY.SYNC', 'Total blueprints fetched from ESI: ${allItems.length}');

      // Convert to Drift companions
      final companions = allItems.map((item) => BlueprintsCompanion(
        itemId: Value(item.itemId),
        characterId: Value(characterId),
        typeId: Value(item.typeId),
        locationId: Value(item.locationId),
        quantity: Value(item.quantity),
        timeEfficiency: Value(item.timeEfficiency),
        materialEfficiency: Value(item.materialEfficiency),
        runs: Value(item.runs),
        // If runs is -1, it's an original (BPO), otherwise a copy (BPC)
        isOriginal: Value(item.runs == -1),
      )).toList();

      await _repository.replaceAllBlueprints(characterId, companions);
      Log.d('INDUSTRY.SYNC', 'syncBlueprints($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('INDUSTRY.SYNC', 'syncBlueprints($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Fetch and store all industry jobs for a character.
  Future<void> syncIndustryJobs(int characterId, {bool includeCompleted = false}) async {
    Log.d('INDUSTRY.SYNC', 'syncIndustryJobs($characterId) - START');
    try {
      final response = await _esiClient.getCharacterIndustryJobs(
        characterId, 
        includeCompleted: includeCompleted,
      );
      
      final jobs = response.data;
      Log.i('INDUSTRY.SYNC', 'Total industry jobs fetched from ESI: ${jobs.length}');

      // Convert to Drift companions
      final companions = jobs.map((job) => IndustryJobsCompanion(
        jobId: Value(job.jobId),
        characterId: Value(characterId),
        installerId: Value(job.installerId),
        facilityId: Value(job.facilityId),
        locationId: Value(job.locationId),
        activityId: Value(job.activityId),
        blueprintId: Value(job.blueprintId),
        blueprintTypeId: Value(job.blueprintTypeId),
        outputLocationId: Value(job.outputLocationId),
        runs: Value(job.runs),
        cost: Value(job.cost ?? 0.0),
        licensedProductionRuns: Value(job.licensedProductionRuns),
        probability: Value(job.probability),
        productTypeId: Value(job.productTypeId),
        status: Value(job.status),
        timeInSeconds: Value(job.duration),
        startDate: Value(job.startDate),
        endDate: Value(job.endDate),
        pauseDate: Value(job.pauseDate),
        completedDate: Value(job.completedDate),
        completedCharacterId: Value(job.completedCharacterId),
        successfulRuns: Value(job.successfulRuns),
      )).toList();

      await _repository.replaceAllIndustryJobs(characterId, companions);
      Log.d('INDUSTRY.SYNC', 'syncIndustryJobs($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('INDUSTRY.SYNC', 'syncIndustryJobs($characterId) - FAILED', e, stack);
      rethrow;
    }
  }
}

/// Provider for the [IndustrySyncService].
final industrySyncServiceProvider = Provider<IndustrySyncService>((ref) {
  return IndustrySyncService(
    ref.watch(esiClientProvider),
    ref.watch(industryRepositoryProvider),
  );
});
