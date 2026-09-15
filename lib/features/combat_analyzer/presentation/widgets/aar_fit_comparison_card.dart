import 'package:flutter/material.dart';

import '../../../fitting/domain/models.dart';
import '../../domain/aar_fit_comparison.dart';
import '../../domain/aar_fit_inventory_diff.dart';
import '../../domain/aar_fit_snapshot.dart';
import '../../domain/combat_evidence_ledger.dart';
import 'aar_fit_comparison_labels.dart';

class AarFitComparisonCard extends StatelessWidget {
  const AarFitComparisonCard({
    super.key,
    required this.entry,
    this.diff,
    this.changesOnly = false,
    this.ownLossDeduplicated = false,
  });

  final AarComparisonSourceEntry entry;
  final FitInventoryDiff? diff;
  final bool changesOnly;
  final bool ownLossDeduplicated;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('aar-comparison-column-${entry.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AarFitSourceHeader(
          entry: entry,
          ownLossDeduplicated: ownLossDeduplicated,
        ),
        AarFitInventoryView(
          snapshot: entry.snapshot,
          diff: diff,
          changesOnly: changesOnly,
        ),
      ],
    );
  }
}

class AarFitSourceHeader extends StatelessWidget {
  const AarFitSourceHeader({
    super.key,
    required this.entry,
    this.ownLossDeduplicated = false,
  });

  final AarComparisonSourceEntry entry;
  final bool ownLossDeduplicated;

  @override
  Widget build(BuildContext context) {
    final snapshot = entry.snapshot;
    final hull = aarComparisonDisplayName(
      typeId: snapshot.fitting.shipTypeId,
      storedName: snapshot.fitting.shipName,
      hull: true,
    );
    final subject = switch (snapshot.subject.relation) {
      AarFitSubjectRelation.pilot => 'Pilot',
      AarFitSubjectRelation.victim => 'Victim',
      AarFitSubjectRelation.reference => 'Reference',
    };
    final provenance = switch (snapshot.source) {
      AarFitSource.evidenceAttachment => 'Evidence attachment',
      AarFitSource.comparisonCapture => 'Comparison capture',
      AarFitSource.killmailVictim => 'Killmail victim',
      AarFitSource.savedReference => 'Saved reference',
      AarFitSource.importedProposal => 'Imported proposal',
      AarFitSource.aiProposal => 'AI proposal',
    };
    final confidence =
        snapshot.confidence?.name ??
        (snapshot.source == AarFitSource.evidenceAttachment
            ? EvidenceConfidence.confirmed.name
            : null);
    final recorded = snapshot.recordedAt ?? snapshot.evidenceAt;
    return Column(
      key: Key('aar-comparison-source-header-${entry.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.label, style: Theme.of(context).textTheme.titleSmall),
        Text(subject),
        Text(hull),
        Text(provenance),
        if (recorded != null) Text(recorded.toUtc().toIso8601String()),
        if (confidence != null) Text(confidence),
        if (ownLossDeduplicated && entry.role == AarComparisonRole.fightFit)
          const Chip(label: Text('Own loss')),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in FitInventoryGroup.values)
          AarFitGroupSection(
            group: group,
            rows: _rowsFor(group),
            snapshot: snapshot,
          ),
      ],
    );
  }

  List<FitChangeRow> _rowsFor(FitInventoryGroup group) {
    if (diff == null) return const [];
    final rows = diff!.group(group).rows;
    if (!changesOnly) return rows;
    return [
      for (final row in rows)
        if (row.kind != FitChangeKind.unchanged) row,
    ];
  }
}

class AarFitGroupSection extends StatelessWidget {
  const AarFitGroupSection({
    super.key,
    required this.group,
    this.rows = const [],
    this.snapshot,
  });

  final FitInventoryGroup group;
  final List<FitChangeRow> rows;
  final AarFitSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final items = snapshot == null
        ? const <Widget>[]
        : _snapshotItems(snapshot!, group);
    return Column(
      key: Key('aar-fit-group-${group.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_groupTitle(group)),
        for (final row in rows) AarFitDiffRow(row: row, snapshot: snapshot),
        ...items,
      ],
    );
  }
}

class AarFitDiffRow extends StatelessWidget {
  const AarFitDiffRow({super.key, required this.row, this.snapshot});

  final FitChangeRow row;
  final AarFitSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final label = switch (row.kind) {
      FitChangeKind.added => 'Added',
      FitChangeKind.removed => 'Removed',
      FitChangeKind.modified => 'Modified',
      FitChangeKind.replaced => 'Replaced',
      FitChangeKind.unchanged => 'Unchanged',
      FitChangeKind.unresolved => 'Unresolved',
    };
    final typeId = row.afterTypeId ?? row.beforeTypeId;
    final name = _nameForType(snapshot, typeId);
    return Semantics(
      key: Key('aar-fit-diff-${row.id}'),
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(_iconFor(row.kind), size: 16),
            const SizedBox(width: 4),
            Flexible(child: Text('$label ${name ?? ''}'.trim())),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(FitChangeKind kind) {
    return switch (kind) {
      FitChangeKind.added => Icons.add_circle_outline,
      FitChangeKind.removed => Icons.remove_circle_outline,
      FitChangeKind.modified => Icons.edit_outlined,
      FitChangeKind.replaced => Icons.swap_horiz,
      FitChangeKind.unchanged => Icons.check_circle_outline,
      FitChangeKind.unresolved => Icons.help_outline,
    };
  }
}

List<Widget> _snapshotItems(AarFitSnapshot snapshot, FitInventoryGroup group) {
  final widgets = <Widget>[];
  switch (group) {
    case FitInventoryGroup.high:
    case FitInventoryGroup.mid:
    case FitInventoryGroup.low:
    case FitInventoryGroup.rigs:
    case FitInventoryGroup.subsystems:
      for (final module in _modules(snapshot.fitting, group)) {
        widgets.add(_moduleTile(module));
      }
    case FitInventoryGroup.drones:
      for (final drone in snapshot.fitting.drones) {
        widgets.add(
          Text(
            aarComparisonDisplayName(
              typeId: drone.typeId,
              storedName: drone.typeName,
            ),
          ),
        );
      }
    case FitInventoryGroup.fighters:
      for (final fighter in snapshot.fitting.fighters) {
        widgets.add(
          Text(
            aarComparisonDisplayName(
              typeId: fighter.typeId,
              storedName: fighter.typeName,
            ),
          ),
        );
      }
    case FitInventoryGroup.cargo:
      for (final cargo in snapshot.fitting.cargo) {
        widgets.add(
          Text(
            aarComparisonDisplayName(
              typeId: cargo.typeId,
              storedName: cargo.typeName,
            ),
          ),
        );
      }
  }
  final knowledge = snapshot.knowledge.group(group);
  for (final occupant in knowledge.unresolvedOccupied) {
    widgets.add(_unresolvedTile(occupant));
  }
  for (final occupant in snapshot.knowledge.unplacedEntries) {
    if (occupant.group == group) widgets.add(_unresolvedTile(occupant));
  }
  return widgets;
}

Widget _moduleTile(FittedModule module) {
  final name = aarComparisonDisplayName(
    typeId: module.typeId,
    storedName: module.typeName,
  );
  final charge = module.chargeName == null
      ? null
      : aarComparisonDisplayName(
          typeId: module.chargeTypeId,
          storedName: module.chargeName,
        );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: Icon(Icons.extension, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: [
              Text(name),
              if (module.state == ModuleState.offline) const Text('Offline'),
              if (charge != null) Text(charge),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _unresolvedTile(UnresolvedOccupant occupant) {
  final name = aarComparisonDisplayName(
    typeId: occupant.typeId,
    storedName: occupant.label,
  );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        const Icon(Icons.help_outline, size: 20),
        const SizedBox(width: 8),
        Flexible(child: Text(name)),
      ],
    ),
  );
}

List<FittedModule> _modules(Fitting fitting, FitInventoryGroup group) {
  return switch (group) {
    FitInventoryGroup.high => fitting.highSlots,
    FitInventoryGroup.mid => fitting.medSlots,
    FitInventoryGroup.low => fitting.lowSlots,
    FitInventoryGroup.rigs => fitting.rigSlots,
    FitInventoryGroup.subsystems => fitting.subsystems,
    _ => const [],
  };
}

String _groupTitle(FitInventoryGroup group) {
  return switch (group) {
    FitInventoryGroup.high => 'High',
    FitInventoryGroup.mid => 'Mid',
    FitInventoryGroup.low => 'Low',
    FitInventoryGroup.rigs => 'Rigs',
    FitInventoryGroup.subsystems => 'Subsystems',
    FitInventoryGroup.drones => 'Drones',
    FitInventoryGroup.fighters => 'Fighters',
    FitInventoryGroup.cargo => 'Cargo',
  };
}

String? _nameForType(AarFitSnapshot? snapshot, int? typeId) {
  if (snapshot == null || typeId == null) return null;
  final fitting = snapshot.fitting;
  if (fitting.shipTypeId == typeId) {
    return aarComparisonDisplayName(
      typeId: typeId,
      storedName: fitting.shipName,
      hull: true,
    );
  }
  for (final module in fitting.allModules) {
    if (module.typeId == typeId) {
      return aarComparisonDisplayName(
        typeId: typeId,
        storedName: module.typeName,
      );
    }
  }
  return aarComparisonDisplayName(typeId: typeId);
}
