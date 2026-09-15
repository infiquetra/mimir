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
  static const _freshnessUnknown = 'Asset freshness unknown';
  static const _availabilityUnknown = 'Availability unknown';

  /// Five-condition eligibility. Cache absence is not a verified shortage;
  /// Changes-mode types also present in the baseline stay unknown without a
  /// disjointness proof.
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
        eligibility: AarAssetEligibility.missingCache,
        disclosure: _availabilityUnknown,
      );
    }

    final ofType = [
      for (final asset in assets)
        if (asset.typeId == typeId && asset.quantity > 0) asset,
    ];
    var observed = 0;
    final locations = <int>{};
    for (final asset in ofType) {
      observed += asset.quantity;
      locations.add(asset.locationId);
    }

    if (changesMode && baselineTypeIds.contains(typeId)) {
      return AarCachedAssetMatch(
        typeId: typeId,
        observedCount: observed,
        eligibility: AarAssetEligibility.baselineOverlap,
        locationIds: locations.toList(),
        disclosure: _freshnessUnknown,
      );
    }

    var eligible = 0;
    var otherCharacter = false;
    var fittedOrContained = false;
    var unknownLocation = false;
    for (final asset in ofType) {
      if (asset.characterId != encounterCharacterId) {
        otherCharacter = true;
        continue;
      }
      if (asset.locationId != selectedLocationId) {
        unknownLocation = true;
        continue;
      }
      if (!_isEligibleLoose(asset)) {
        fittedOrContained = true;
        continue;
      }
      eligible += asset.quantity;
    }

    if (eligible > 0) {
      return AarCachedAssetMatch(
        typeId: typeId,
        observedCount: observed,
        eligibleLooseCount: eligible,
        eligibility: AarAssetEligibility.eligibleLoose,
        locationIds: locations.toList(),
        estimatedShortfall: _max0(requiredCount - eligible),
        disclosure: _freshnessUnknown,
      );
    }

    final eligibility = otherCharacter && !_hasOwn(ofType, encounterCharacterId)
        ? AarAssetEligibility.otherCharacter
        : fittedOrContained
        ? AarAssetEligibility.fittedOrContained
        : unknownLocation
        ? AarAssetEligibility.unknownLocation
        : AarAssetEligibility.missingCache;

    final typeMissingFromCache = ofType.isEmpty;
    return AarCachedAssetMatch(
      typeId: typeId,
      observedCount: observed,
      eligibleLooseCount: typeMissingFromCache ? null : 0,
      eligibility: eligibility,
      locationIds: locations.toList(),
      estimatedShortfall: typeMissingFromCache ? null : _max0(requiredCount),
      disclosure: typeMissingFromCache
          ? 'Not found in cached assets'
          : _freshnessUnknown,
    );
  }

  static bool _hasOwn(List<AarCachedAsset> ofType, int characterId) {
    for (final asset in ofType) {
      if (asset.characterId == characterId) return true;
    }
    return false;
  }

  /// Loose hangar at the selected location, with no parent/container signal.
  /// `containedInId == null` is not itself proof of being uncontained.
  static bool _isEligibleLoose(AarCachedAsset asset) {
    if (asset.quantity <= 0) return false;
    if (!hangarFlags.contains(asset.locationFlag)) return false;
    if (asset.parentItemId != null) return false;
    if (asset.containedInId != null) return false;
    return true;
  }

  static int _max0(int value) => value < 0 ? 0 : value;
}
