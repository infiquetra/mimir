import 'package:mimir/core/network/esi_client.dart';

/// Test fixtures for Industry data (Blueprints and Jobs).
class IndustryFixtures {
  static final _baseDate = DateTime(2024, 1, 1, 12, 0);

  /// Test blueprints data
  static List<BlueprintItem> testBlueprints() {
    return [
      BlueprintItem(
        itemId: 10001,
        typeId: 689, // Slasher Blueprint
        locationId: 60003760, // Jita IV - Moon 4 - Caldari Navy Assembly Plant
        locationFlag: 'Hangar',
        quantity: 1,
        timeEfficiency: 20,
        materialEfficiency: 10,
        runs: -1, // Original
      ),
      BlueprintItem(
        itemId: 10002,
        typeId: 11135, // Procurer Blueprint
        locationId: 60003760,
        locationFlag: 'Hangar',
        quantity: 1,
        timeEfficiency: 10,
        materialEfficiency: 5,
        runs: 10, // Copy
        runsRemaining: 10,
      ),
    ];
  }

  /// Test industry jobs data
  static List<IndustryJobData> testIndustryJobs() {
    return [
      IndustryJobData(
        jobId: 20001,
        installerId: 12345678,
        facilityId: 60003760,
        locationId: 60003760,
        activityId: 1, // Manufacturing
        blueprintId: 10002,
        blueprintTypeId: 11135,
        outputLocationId: 60003760,
        runs: 2,
        cost: 1500000.0,
        productTypeId: 17476, // Procurer
        status: 'active',
        duration: 3600,
        startDate: _baseDate.subtract(const Duration(minutes: 30)),
        endDate: _baseDate.add(const Duration(minutes: 30)),
      ),
      IndustryJobData(
        jobId: 20002,
        installerId: 12345678,
        facilityId: 60003760,
        locationId: 60003760,
        activityId: 1, // Manufacturing
        blueprintId: 10001,
        blueprintTypeId: 689,
        outputLocationId: 60003760,
        runs: 5,
        cost: 500000.0,
        productTypeId: 582, // Slasher
        status: 'delivered',
        duration: 7200,
        startDate: _baseDate.subtract(const Duration(hours: 3)),
        endDate: _baseDate.subtract(const Duration(hours: 1)),
        completedDate: _baseDate.subtract(const Duration(hours: 1)),
        completedCharacterId: 12345678,
        successfulRuns: 5,
      ),
    ];
  }
}
