enum AarAssetEligibility {
  eligibleLoose,
  otherCharacter,
  fittedOrContained,
  unknownLocation,
  missingCache,
  baselineOverlap,
}

class AarCachedAsset {
  const AarCachedAsset({
    required this.itemId,
    required this.characterId,
    required this.typeId,
    required this.locationId,
    required this.locationFlag,
    required this.quantity,
    this.containedInId,
    this.parentItemId,
  });

  final int itemId;
  final int characterId;
  final int typeId;
  final int locationId;
  final String locationFlag;
  final int quantity;
  final int? containedInId;
  final int? parentItemId;
}

/// Compile stub for W5. GREEN applies the five eligibility conditions and
/// never treats cache absence as a verified shortage.
class AarCachedAssetMatch {
  const AarCachedAssetMatch({
    required this.typeId,
    this.observedCount = 0,
    this.eligibleLooseCount,
    this.eligibility = AarAssetEligibility.eligibleLoose,
    this.locationIds = const [],
    this.estimatedShortfall,
    this.disclosure,
  });

  final int typeId;
  final int observedCount;
  final int? eligibleLooseCount;
  final AarAssetEligibility eligibility;
  final List<int> locationIds;
  final int? estimatedShortfall;
  final String? disclosure;
}

class AarSpareMatcher {
  const AarSpareMatcher();

  static const hangarFlags = {'Hangar'};

  /// Naive: credits every positive-quantity asset at the selected location,
  /// including other characters, fitted modules, cargo, and nested stacks.
  /// Changes-mode baseline types still subtract. Empty cache is a shortage.
  AarCachedAssetMatch match({
    required int typeId,
    required int requiredCount,
    required int encounterCharacterId,
    required int selectedLocationId,
    required List<AarCachedAsset> assets,
    Set<int> baselineTypeIds = const {},
    bool changesMode = true,
  }) {
    if (assets.isEmpty) {
      return AarCachedAssetMatch(
        typeId: typeId,
        observedCount: 0,
        eligibleLooseCount: 0,
        eligibility: AarAssetEligibility.missingCache,
        estimatedShortfall: requiredCount,
        disclosure: 'Not found in cached assets',
      );
    }

    var observed = 0;
    var eligible = 0;
    final locations = <int>{};
    for (final asset in assets) {
      if (asset.typeId != typeId || asset.quantity <= 0) continue;
      observed += asset.quantity;
      locations.add(asset.locationId);
      if (asset.locationId == selectedLocationId) {
        eligible += asset.quantity;
      }
    }

    final overlap = changesMode && baselineTypeIds.contains(typeId);
    return AarCachedAssetMatch(
      typeId: typeId,
      observedCount: observed,
      eligibleLooseCount: eligible,
      eligibility: overlap
          ? AarAssetEligibility.baselineOverlap
          : AarAssetEligibility.eligibleLoose,
      locationIds: locations.toList(),
      estimatedShortfall: overlap ? 0 : _max0(requiredCount - eligible),
      disclosure: assets.isEmpty ? 'Not found in cached assets' : null,
    );
  }

  static int _max0(int value) => value < 0 ? 0 : value;
}
