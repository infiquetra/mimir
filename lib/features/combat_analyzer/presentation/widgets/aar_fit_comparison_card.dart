import 'package:flutter/material.dart';

import '../../domain/aar_fit_comparison.dart';
import '../../domain/aar_fit_inventory_diff.dart';
import '../../domain/aar_fit_snapshot.dart';

/// Naive source card: raw type IDs, high slots only, color-only change dots.
class AarFitComparisonCard extends StatelessWidget {
  const AarFitComparisonCard({
    super.key,
    required this.entry,
    this.diff,
    this.changesOnly = false,
  });

  final AarComparisonSourceEntry entry;
  final FitInventoryDiff? diff;
  final bool changesOnly;

  @override
  Widget build(BuildContext context) {
    final fitting = entry.snapshot.fitting;
    return Column(
      key: Key('aar-comparison-column-${entry.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AarFitSourceHeader(entry: entry),
        AarFitInventoryView(
          snapshot: entry.snapshot,
          diff: diff,
          changesOnly: changesOnly,
        ),
        for (final module in fitting.highSlots) Text('Type #${module.typeId}'),
      ],
    );
  }
}

class AarFitSourceHeader extends StatelessWidget {
  const AarFitSourceHeader({super.key, required this.entry});

  final AarComparisonSourceEntry entry;

  @override
  Widget build(BuildContext context) {
    final snapshot = entry.snapshot;
    return Column(
      key: Key('aar-comparison-source-header-${entry.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Type #${snapshot.fitting.shipTypeId}'),
        Text('character ${snapshot.subject.characterId}'),
        Text(snapshot.source.name),
        if (snapshot.recordedAt != null)
          Text('${snapshot.recordedAt!.millisecondsSinceEpoch}'),
      ],
    );
  }
}

class AarFitInventoryView extends StatelessWidget {
  const AarFitInventoryView({
    super.key,
    required this.snapshot,
    this.diff,
    this.changesOnly = false,
  });

  final AarFitSnapshot snapshot;
  final FitInventoryDiff? diff;
  final bool changesOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('aar-fit-inventory-view'),
      children: [
        if (diff != null)
          for (final row in diff!.allRows) AarFitDiffRow(row: row),
        for (final module in snapshot.fitting.highSlots)
          Text('Type #${module.typeId}'),
      ],
    );
  }
}

class AarFitGroupSection extends StatelessWidget {
  const AarFitGroupSection({
    super.key,
    required this.group,
    this.rows = const [],
  });

  final FitInventoryGroup group;
  final List<FitChangeRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('aar-fit-group-${group.name}'),
      children: [for (final row in rows) AarFitDiffRow(row: row)],
    );
  }
}

class AarFitDiffRow extends StatelessWidget {
  const AarFitDiffRow({super.key, required this.row});

  final FitChangeRow row;

  @override
  Widget build(BuildContext context) {
    final color = switch (row.kind) {
      FitChangeKind.added => Colors.green,
      FitChangeKind.removed => Colors.red,
      FitChangeKind.modified || FitChangeKind.replaced => Colors.orange,
      FitChangeKind.unchanged => Colors.grey,
      FitChangeKind.unresolved => Colors.purple,
    };
    return Container(
      key: Key('aar-fit-diff-${row.id}'),
      width: 12,
      height: 12,
      color: color,
    );
  }
}
