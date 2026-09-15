import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/aar_fit_comparison_service.dart';
import '../../domain/aar_fit_bom.dart';
import '../../domain/aar_fit_calculation.dart';
import '../../domain/aar_fit_comparison.dart';
import '../../domain/aar_fit_inventory_diff.dart';
import '../../domain/aar_fit_pricing.dart';
import '../../domain/aar_fit_proposal.dart';
import '../../domain/aar_fit_spares.dart';
import '../../presentation/aar_capture_feedback.dart';
import 'aar_fit_bom_view.dart';
import 'aar_fit_comparison_card.dart';
import 'aar_fit_comparison_table.dart';

enum AarComparisonLayoutMode {
  stacked,
  baselinePlusOne,
  baselinePlusTwo,
  fourColumn,
}

/// Naive: window-width breakpoints, inverted against §8.3 usable-width table.
AarComparisonLayoutMode aarComparisonLayoutModeForWidth(
  double width, {
  double textScale = 1.0,
}) {
  return AarComparisonLayoutMode.fourColumn;
}

/// Naive: always emits a Type # placeholder, never Unknown ship / Unresolved module.
String aarComparisonDisplayName({
  int? typeId,
  String? storedName,
  bool hull = false,
}) {
  return 'Type #${typeId ?? 0}';
}

class AarCompareFitsEntry extends StatelessWidget {
  const AarCompareFitsEntry({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: const Key('aar-compare-fits-entry'),
      onPressed: onPressed,
      child: const Text('Compare fits'),
    );
  }
}

class AarFitComparisonWorkspace extends StatefulWidget {
  const AarFitComparisonWorkspace({
    super.key,
    required this.encounterId,
    required this.sources,
    this.diff,
    this.baseline,
    this.candidate,
    this.bom,
    this.priced,
    this.matches = const [],
    this.proposal,
    this.currentBaselineSnapshotId,
    this.selectedProfileId = 'em',
    this.onProfileChanged,
    this.onCaptureCurrent,
    this.onRefreshPrices,
    this.onWatchCorrelation,
    this.savedReferences = const [],
    this.priceRefreshHasCache = true,
  });

  final String encounterId;
  final AarComparisonSources sources;
  final FitInventoryDiff? diff;
  final CombatFitComputation? baseline;
  final CombatFitComputation? candidate;
  final FitBillOfMaterials? bom;
  final AarPricedSubtotal? priced;
  final List<AarCachedAssetMatch> matches;
  final AarFitProposal? proposal;
  final String? currentBaselineSnapshotId;
  final String selectedProfileId;
  final ValueChanged<String>? onProfileChanged;
  final Future<AarComparisonSaveResult> Function()? onCaptureCurrent;
  final Future<AarComparisonSaveResult> Function()? onRefreshPrices;
  final VoidCallback? onWatchCorrelation;
  final List<SavedFittingReference> savedReferences;
  final bool priceRefreshHasCache;

  @override
  State<AarFitComparisonWorkspace> createState() =>
      _AarFitComparisonWorkspaceState();
}

class _AarFitComparisonWorkspaceState extends State<AarFitComparisonWorkspace> {
  late String _profileId;

  @override
  void initState() {
    super.initState();
    _profileId = widget.selectedProfileId;
    widget.onWatchCorrelation?.call();
  }

  Future<void> _capture() async {
    final result = await widget.onCaptureCurrent?.call();
    final message = switch (result?.code) {
      AarComparisonFailureCode.authUnavailable => kAarCaptureAuthUi,
      AarComparisonFailureCode.noShip => kAarCaptureNoShipUi,
      AarComparisonFailureCode.captureFailure => kAarCaptureSaveUi,
      _ => kAarCaptureSuccessMessage,
    };
    Timer(const Duration(milliseconds: 20), () {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  Future<void> _refreshPrices() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await widget.onRefreshPrices?.call();
    final message = result != null && result.isSuccess
        ? 'Prices updated'
        : widget.priceRefreshHasCache
        ? 'Price refresh failed'
        : 'No prices';
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final windowWidth = MediaQuery.sizeOf(context).width;
    final mode = aarComparisonLayoutModeForWidth(windowWidth);
    final entries = widget.sources.entries;
    return Column(
      key: const Key('aar-fit-comparison-workspace'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarComparisonSourceSelector(sources: widget.sources),
        AarComparisonAssumptionsBar(
          selectedProfileId: _profileId,
          onProfileChanged: (id) {
            setState(() => _profileId = id);
            widget.onProfileChanged?.call(id);
          },
        ),
        AarComparisonColumns(mode: mode, entries: entries, diff: widget.diff),
        AarFitStatDeltaCards(
          baseline: widget.baseline,
          candidate: widget.candidate,
        ),
        AarFitBomCard(
          bom: widget.bom,
          priced: widget.priced,
          matches: widget.matches,
          targetLabel: widget.proposal?.target?.fitting.name,
          baselineLabel: widget.currentBaselineSnapshotId,
        ),
        if (widget.proposal != null) Text(widget.proposal!.rationale),
        Wrap(
          children: [
            FilledButton(
              key: const Key('aar-comparison-capture-current'),
              onPressed: _capture,
              child: const Text('Capture current fit'),
            ),
            OutlinedButton(
              key: const Key('aar-comparison-price-refresh'),
              onPressed: _refreshPrices,
              child: const Text('Refresh prices'),
            ),
            Text('${widget.savedReferences.length}'),
          ],
        ),
      ],
    );
  }
}

class AarComparisonSourceSelector extends StatelessWidget {
  const AarComparisonSourceSelector({super.key, required this.sources});

  final AarComparisonSources sources;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('aar-comparison-source-selector'),
      children: [
        for (final entry in sources.entries)
          Text(entry.role.name, key: Key('aar-comparison-select-${entry.id}')),
      ],
    );
  }
}

class AarComparisonAssumptionsBar extends StatelessWidget {
  const AarComparisonAssumptionsBar({
    super.key,
    required this.selectedProfileId,
    this.onProfileChanged,
  });

  final String selectedProfileId;
  final ValueChanged<String>? onProfileChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      key: const Key('aar-comparison-profile-selector'),
      value: selectedProfileId,
      items: const [
        DropdownMenuItem(value: 'omni', child: Text('Omni')),
        DropdownMenuItem(value: 'incoming', child: Text('Incoming allocation')),
        DropdownMenuItem(value: 'aggregate', child: Text('Aggregate blend')),
        DropdownMenuItem(value: 'em', child: Text('EM')),
      ],
      onChanged: (value) {
        if (value != null) onProfileChanged?.call(value);
      },
    );
  }
}

class AarComparisonColumns extends StatelessWidget {
  const AarComparisonColumns({
    super.key,
    required this.mode,
    required this.entries,
    this.diff,
  });

  final AarComparisonLayoutMode mode;
  final List<AarComparisonSourceEntry> entries;
  final FitInventoryDiff? diff;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key('aar-comparison-layout-${mode.name}'),
      children: [
        for (final entry in entries)
          SizedBox(
            width: 360,
            child: AarFitComparisonCard(entry: entry, diff: diff),
          ),
      ],
    );
  }
}
