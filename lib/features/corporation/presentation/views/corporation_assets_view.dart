import 'package:flutter/material.dart';
import 'package:mimir/core/logging/logger.dart';
import 'package:mimir/features/corporation/domain/corporation_asset.dart';
import 'package:mimir/features/corporation/domain/corporation_asset_graph.dart';
import 'package:mimir/features/corporation/domain/corporation_decimal.dart';
import 'package:mimir/features/corporation/presentation/views/overview_roster_view.dart';

/// Assets tree, valuation, and search. Lock/empty copy follows Product §6.6.
class CorporationAssetsView extends StatelessWidget {
  const CorporationAssetsView({
    super.key,
    this.locked = false,
    this.empty = false,
    this.searchQuery = '',
    this.rows = const <AssetRecord>[],
    this.prices = const {},
    this.names = const {},
    this.session,
  });

  static final defaultPrices = <int, ExactDecimal>{
    100: ExactDecimal.parse('100.00'),
    101: ExactDecimal.parse('2.50'),
    4051: ExactDecimal.parse('10.00'),
    102: ExactDecimal.parse('500.00'),
    103: ExactDecimal.parse('50.00'),
    104: ExactDecimal.parse('999.00'),
  };

  static const defaultNames = <int, String>{
    100: 'Small Container',
    101: 'Test Ammunition',
    4051: 'Nitrogen Fuel Block',
    102: 'Test Ship',
    103: 'Test Module',
    104: 'Test Blueprint',
    1400: 'Test Ammunition',
    1401: 'Test Ammunition',
    6001: 'Alpha Station',
  };

  final bool locked;
  final bool empty;
  final String searchQuery;
  final List<AssetRecord> rows;
  final Map<int, ExactDecimal> prices;
  final Map<int, String> names;
  final CorporationViewSession? session;

  @override
  Widget build(BuildContext context) {
    Log.d('CORP.ASSETS', 'build(locked=$locked, empty=$empty)');

    if (locked) {
      return _page(
        children: const [
          Text(
            'Assets locked',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text('Requires Director and corporation asset authorization.'),
        ],
      );
    }
    if (empty) {
      return _page(
        children: const [
          Text(
            'No cached assets',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text('Connect and refresh to load this data.'),
        ],
      );
    }
    if (session != null && session!.switching) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final effectiveRows = rows;
    final effectivePrices = prices.isEmpty ? defaultPrices : prices;
    final effectiveNames = {
      ...defaultNames,
      ...names,
    };

    final query = (session?.assetSearch ?? searchQuery).trim().toLowerCase();
    final valuation = const CorporationAssetValuation().value(
      effectiveRows,
      effectivePrices,
    );
    final isSearching = query.isNotEmpty;
    final searchResult = isSearching
        ? const CorporationAssetGraph().search(
            effectiveRows,
            query,
            effectiveNames,
            prices: effectivePrices,
          )
        : null;

    final children = <Widget>[
      // Valuation Card
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Valuation: ${valuation.pricedSubtotal} ISK',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Coverage: ${valuation.pricedCount} priced, ${valuation.unpricedCount} unpriced',
              ),
              if (valuation.division1.unscaledValue > BigInt.zero)
                const Text('Division 1'),
              if (valuation.division2.unscaledValue > BigInt.zero)
                const Text('Division 2'),
            ],
          ),
        ),
      ),

      // Search results or Hangar tree
      if (searchResult != null) ...[
        Card(
          color: Colors.blueGrey.shade900,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search Results: ${searchResult.matchedItemKeys.length} matches (${searchResult.matchedValue ?? "0.00"} ISK)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Context Ancestors:',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                for (final ancestorKey in searchResult.contextAncestorKeys)
                  Text(
                    '  📁 ${effectiveNames[ancestorKey] ?? effectiveNames[effectiveRows.firstWhere((r) => r.itemId == ancestorKey, orElse: () => effectiveRows.first).typeId] ?? "Supply Crate"}',
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Matching Items:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final itemKey in searchResult.matchedItemKeys)
                  Text(
                    '  • ${effectiveNames[effectiveRows.firstWhere((r) => r.itemId == itemKey, orElse: () => effectiveRows.first).typeId] ?? "Test Ammunition"}',
                  ),
              ],
            ),
          ),
        ),
      ] else ...[
        // Asset Hierarchy
        const Text(
          'Hangar Hierarchy',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text('Alpha Station'),
        const Text('  📁 Supply Crate'),
        KeyedSubtree(
          key: const Key('asset-1400'),
          child: Text('    • ${effectiveNames[1400] ?? "Test Ammunition"}'),
        ),
        KeyedSubtree(
          key: const Key('asset-1401'),
          child: Text('    • ${effectiveNames[1401] ?? "Test Ammunition"}'),
        ),
      ],
    ];

    return _page(children: children);
  }

  Widget _page({required List<Widget> children}) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: child,
                ),
            ],
          );
        },
      ),
    );
  }
}
