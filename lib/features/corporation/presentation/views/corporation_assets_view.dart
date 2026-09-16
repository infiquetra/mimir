import 'package:flutter/material.dart';
import 'package:mimir/features/corporation/domain/corporation_asset.dart';
import 'package:mimir/features/corporation/presentation/views/overview_roster_view.dart';

/// Naive C8 assets: float 725.0, BPC 999, raw Item # IDs, no §6.6 lock/empty copy.
class CorporationAssetsView extends StatelessWidget {
  const CorporationAssetsView({
    super.key,
    this.locked = false,
    this.empty = false,
    this.searchQuery = '',
    this.rows = const <AssetRecord>[],
    this.session,
  });

  final bool locked;
  final bool empty;
  final String searchQuery;
  final List<AssetRecord> rows;
  final CorporationViewSession? session;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      const Text('725.0 ISK'),
      const Text('999'),
      const Text('0.00'),
      const Text('Item #1000 Item #1100 Item #1400 Item #1400'),
      const Text('Location 6001'),
      const Text('No assets'),
      Text('query=${session?.assetSearch ?? searchQuery}'),
    ];
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 400) {
            return Row(children: [...children, Text('x' * 80)]);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
        },
      ),
    );
  }
}
