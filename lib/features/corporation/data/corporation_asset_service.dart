import '../domain/corporation_asset.dart';
import '../domain/corporation_snapshot.dart';

class AssetNamePage {
  const AssetNamePage({required this.ids, this.generation = 1});
  final List<int> ids;
  final int generation;
}

/// Complete-page publication, 1000-ID name batches, scoped custom names.
class CorporationAssetService {
  const CorporationAssetService();

  static const nameBatchSize = 1000;

  SnapshotEnvelope<List<AssetRecord>> publish(
    List<AssetNamePage> pages,
    List<AssetRecord> rows,
  ) {
    final complete = acceptsMixedGeneration(pages);
    return SnapshotEnvelope(
      payload: complete ? rows : const [],
      complete: complete,
    );
  }

  List<List<int>> nameBatches(List<int> itemIds) {
    if (itemIds.isEmpty) return const [];
    final batches = <List<int>>[];
    for (var i = 0; i < itemIds.length; i += nameBatchSize) {
      final end = i + nameBatchSize > itemIds.length
          ? itemIds.length
          : i + nameBatchSize;
      batches.add(itemIds.sublist(i, end));
    }
    return batches;
  }

  String displayName({
    required int itemId,
    required int viewerCharacterId,
    Map<int, String> typeNames = const {},
    Map<int, Map<int, String>> customNamesByCharacter = const {},
    int? typeId,
  }) {
    final custom = customNamesByCharacter[viewerCharacterId]?[itemId];
    if (custom != null && custom.trim().isNotEmpty) return custom;
    if (typeId != null) {
      final typeName = typeNames[typeId];
      if (typeName != null && typeName.trim().isNotEmpty) return typeName;
    }
    return 'Unknown';
  }

  bool acceptsMixedGeneration(List<AssetNamePage> pages) {
    if (pages.isEmpty) return true;
    final generation = pages.first.generation;
    return pages.every((page) => page.generation == generation);
  }
}
