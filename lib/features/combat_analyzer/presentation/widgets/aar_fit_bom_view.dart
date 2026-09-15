import 'package:flutter/material.dart';

import '../../domain/aar_fit_bom.dart';
import '../../domain/aar_fit_comparison.dart';
import '../../domain/aar_fit_pricing.dart';
import '../../domain/aar_fit_spares.dart';

/// Naive BOM: one "Total cost" figure, no mode toggle, no freshness.
class AarFitBomView extends StatelessWidget {
  const AarFitBomView({
    super.key,
    this.bom,
    this.priced,
    this.matches = const [],
    this.targetLabel,
    this.baselineLabel,
    this.onModeChanged,
  });

  final FitBillOfMaterials? bom;
  final AarPricedSubtotal? priced;
  final List<AarCachedAssetMatch> matches;
  final String? targetLabel;
  final String? baselineLabel;
  final ValueChanged<AarBomMode>? onModeChanged;

  @override
  Widget build(BuildContext context) {
    final amount = priced?.amount.asDouble ?? 0;
    return Card(
      key: const Key('aar-fit-bom-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total cost'),
          Text(amount.toString()),
          if (bom != null)
            for (final line in bom!.requirements) Text('${line.typeId}'),
        ],
      ),
    );
  }
}

class AarFitBomCard extends AarFitBomView {
  const AarFitBomCard({
    super.key,
    super.bom,
    super.priced,
    super.matches,
    super.targetLabel,
    super.baselineLabel,
    super.onModeChanged,
  });
}
