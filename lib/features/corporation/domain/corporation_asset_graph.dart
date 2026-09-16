import 'corporation_asset.dart';
import 'corporation_decimal.dart';

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

/// Safe hangar forest: item parents only, cycles/orphans visible once,
/// 64-edge bound, search matches distinct from ancestor context.
class CorporationAssetGraph {
  const CorporationAssetGraph();

  static const maxEdges = 64;

  List<AssetGraphNode> forest(List<AssetRecord> rows) {
    if (rows.isEmpty) return const [];
    final byId = {for (final row in rows) row.itemId: row};
    final childrenOf = <int, List<AssetRecord>>{};
    for (final row in rows) {
      if (row.locationType == 'item' && byId.containsKey(row.locationId)) {
        childrenOf.putIfAbsent(row.locationId, () => []).add(row);
      }
    }

    final inCycle = _cycleMembers(rows, byId);
    final hangarRoots = [
      for (final row in rows)
        if (row.locationType != 'item' || !byId.containsKey(row.locationId))
          row,
    ];
    final hangarRoot =
        hangarRoots.where((row) => row.administrative).firstOrNull ??
        hangarRoots.firstOrNull;
    if (hangarRoot == null) return const [];

    final placed = <int>{};
    AssetGraphNode build(AssetRecord row, Set<int> path, int depth) {
      placed.add(row.itemId);
      if (depth >= maxEdges ||
          path.contains(row.itemId) ||
          inCycle.contains(row.itemId)) {
        return AssetGraphNode(record: row, children: const []);
      }
      final nextPath = {...path, row.itemId};
      final kids = [
        for (final child in childrenOf[row.itemId] ?? const <AssetRecord>[])
          if (!path.contains(child.itemId) && !inCycle.contains(child.itemId))
            build(child, nextPath, depth + 1),
      ];
      return AssetGraphNode(record: row, children: kids);
    }

    final hangar = build(hangarRoot, {}, 0);
    final extras = [
      for (final row in rows)
        if (!placed.contains(row.itemId))
          AssetGraphNode(record: row, children: const []),
    ];
    return [
      AssetGraphNode(
        record: hangar.record,
        children: [...hangar.children, ...extras],
      ),
    ];
  }

  int pathLength(List<AssetRecord> chain) {
    final edges = chain.isEmpty ? 0 : chain.length - 1;
    return edges > maxEdges ? maxEdges : edges;
  }

  bool exceedsDepthBound(List<AssetRecord> chain) {
    final edges = chain.isEmpty ? 0 : chain.length - 1;
    return edges > maxEdges;
  }

  AssetSearchResult search(
    List<AssetRecord> rows,
    String query,
    Map<int, String> names, {
    Map<int, ExactDecimal> prices = const {},
  }) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return const AssetSearchResult();
    }
    final byId = {for (final row in rows) row.itemId: row};
    final matched = <AssetRecord>[];
    for (final row in rows) {
      final typeName = (names[row.typeId] ?? names[row.itemId] ?? '')
          .toLowerCase();
      final custom = (names[row.itemId] ?? '').toLowerCase();
      if (_nameMatches(typeName, needle) || _nameMatches(custom, needle)) {
        matched.add(row);
      }
    }
    final matchIds = [for (final row in matched) row.itemId];
    final matchSet = matchIds.toSet();
    final ancestors = <int>{};
    for (final row in matched) {
      AssetRecord? current = row;
      final seen = <int>{};
      while (current != null && seen.add(current.itemId)) {
        if (current.locationType != 'item') break;
        final parent = byId[current.locationId];
        if (parent == null) break;
        if (!matchSet.contains(parent.itemId)) ancestors.add(parent.itemId);
        current = parent;
      }
    }
    final valued = const CorporationAssetValuation().value(matched, prices);
    return AssetSearchResult(
      matchedItemKeys: matchIds,
      contextAncestorKeys: ancestors.toList(),
      matchedValue: valued.pricedSubtotal,
    );
  }

  bool _nameMatches(String name, String needle) {
    if (name.contains(needle)) return true;
    final words = name
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty);
    for (final word in words) {
      if (word.startsWith(needle) || needle.startsWith(word)) return true;
      var shared = 0;
      while (shared < word.length &&
          shared < needle.length &&
          word[shared] == needle[shared]) {
        shared += 1;
      }
      if (shared >= 3) return true;
    }
    return false;
  }

  Set<int> _cycleMembers(List<AssetRecord> rows, Map<int, AssetRecord> byId) {
    final cyclic = <int>{};
    for (final start in rows) {
      if (start.locationType != 'item') continue;
      final seen = <int>{};
      var current = start;
      while (current.locationType == 'item' &&
          byId.containsKey(current.locationId)) {
        if (!seen.add(current.itemId)) {
          cyclic.addAll(seen);
          break;
        }
        current = byId[current.locationId]!;
      }
    }
    return cyclic;
  }
}
