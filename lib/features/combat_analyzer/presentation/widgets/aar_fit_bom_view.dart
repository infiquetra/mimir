import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/aar_fit_bom.dart';
import '../../domain/aar_fit_comparison.dart';
import '../../domain/aar_fit_pricing.dart';
import '../../domain/aar_fit_spares.dart';
import 'aar_fit_comparison_labels.dart';

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
    final current = bom;
    return Card(
      key: const Key('aar-fit-bom-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => onModeChanged?.call(AarBomMode.changes),
                  child: const Text('Changes'),
                ),
                TextButton(
                  onPressed: () =>
                      onModeChanged?.call(AarBomMode.fullReplacement),
                  child: const Text('Full replacement'),
                ),
              ],
            ),
            if (targetLabel != null) Text('Target: $targetLabel'),
            if (baselineLabel != null) Text('Baseline: $baselineLabel'),
            if (current != null) ...[
              for (final line in current.requirements) _lineText(line),
              const Text('Removals'),
              for (final line in current.removals) _lineText(line),
              if (current.removals.isEmpty) const Text('Cmp B'),
              if (current.unquantifiedCharges.isNotEmpty)
                const Text('Charge quantity not recorded'),
            ],
            if (priced != null) ...[
              Text(priced!.heading),
              Text(formatIsk(priced!.amount.asDouble)),
              Text(priced!.coverage),
            ],
            const Text('Asset freshness unknown'),
            for (final match in matches) ...[
              if (match.estimatedShortfall != null)
                Text('Shortfall ${match.estimatedShortfall}'),
              if (match.eligibleLooseCount != null)
                Text('Eligible loose ${match.eligibleLooseCount}'),
              if (match.disclosure != null) Text(match.disclosure!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lineText(FitBomLine line) {
    final name = aarComparisonDisplayName(
      typeId: line.typeId,
      storedName: line.typeName,
    );
    final qty = line.requiredCount;
    return Text(qty == null ? name : '$name ×$qty');
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
