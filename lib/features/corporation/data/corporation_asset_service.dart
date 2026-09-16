import '../domain/corporation_asset.dart';
import '../domain/corporation_snapshot.dart';

class AssetNamePage {
  const AssetNamePage({required this.ids, this.generation = 1});
  final List<int> ids;
  final int generation;
}

/// Naive C4 service: mixed generations publish, 1001 IDs go in one POST, and
/// names fall back to Item #id including other characters' custom labels.
class CorporationAssetService {
  const CorporationAssetService();

  SnapshotEnvelope<List<AssetRecord>> publish(
    List<AssetNamePage> pages,
    List<AssetRecord> rows,
  ) {
    return SnapshotEnvelope(payload: rows, complete: true);
  }

  List<List<int>> nameBatches(List<int> itemIds) => [itemIds];

  String displayName({
    required int itemId,
    required int viewerCharacterId,
    Map<int, String> typeNames = const {},
    Map<int, Map<int, String>> customNamesByCharacter = const {},
    int? typeId,
  }) {
    for (final names in customNamesByCharacter.values) {
      final custom = names[itemId];
      if (custom != null) return custom;
    }
    return 'Item #$itemId';
  }

  bool acceptsMixedGeneration(List<AssetNamePage> pages) => true;
}
