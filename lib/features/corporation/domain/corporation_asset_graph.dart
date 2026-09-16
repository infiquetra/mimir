import 'corporation_asset.dart';

class AssetGraphNode {
  AssetGraphNode({required this.record, this.children = const []});

  final AssetRecord record;
  final List<AssetGraphNode> children;
}

class AssetSearchResult {
  const AssetSearchResult({
    this.matchedItemKeys = const [],
    this.contextAncestorKeys = const [],
    this.matchedValue,
  });

  final List<int> matchedItemKeys;
  final List<int> contextAncestorKeys;
  final Object? matchedValue;
}

/// Naive C4 graph: no cycle/visited set, no 64-edge bound, search includes
/// ancestor keys as matches.
class CorporationAssetGraph {
  const CorporationAssetGraph();

  List<AssetGraphNode> forest(List<AssetRecord> rows) {
    return [
      for (final row in rows)
        AssetGraphNode(
          record: row,
          children: [
            for (final child in rows)
              if (child.locationType == 'item' &&
                  child.locationId == row.itemId)
                AssetGraphNode(record: child),
          ],
        ),
    ];
  }

  int pathLength(List<AssetRecord> chain) => chain.length;

  bool exceedsDepthBound(List<AssetRecord> chain) => false;

  AssetSearchResult search(
    List<AssetRecord> rows,
    String query,
    Map<int, String> names,
  ) {
    final needle = query.toLowerCase();
    final matched = <int>[];
    final ancestors = <int>[];
    for (final row in rows) {
      final name = (names[row.typeId] ?? '').toLowerCase();
      if (name == needle) {
        matched.add(row.itemId);
        matched.add(row.locationId);
        ancestors.add(row.locationId);
      }
    }
    return AssetSearchResult(
      matchedItemKeys: matched,
      contextAncestorKeys: ancestors,
      matchedValue: matched.length,
    );
  }
}
