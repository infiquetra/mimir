import 'package:flutter/material.dart';

import '../../../../core/logging/logger.dart';
import '../../data/aar_fit_comparison_service.dart';
import '../../domain/aar_fit_bom.dart';
import '../../domain/aar_fit_calculation.dart';
import '../../domain/aar_fit_comparison.dart';
import '../../domain/aar_fit_inventory_diff.dart';
import '../../domain/aar_fit_pricing.dart';
import '../../domain/aar_fit_proposal.dart';
import '../../domain/aar_fit_spares.dart';
import 'aar_fit_bom_view.dart';
import 'aar_fit_comparison_card.dart';
import 'aar_fit_comparison_labels.dart';
import 'aar_fit_comparison_table.dart';

export 'aar_fit_comparison_labels.dart';

class _EncounterWorkspaceMemory {
  String? focusedSourceId;
  bool changesOnly = false;
  String profileId = 'omni';
}

final _memory = <String, _EncounterWorkspaceMemory>{};

_EncounterWorkspaceMemory _memoryFor(String encounterId) {
  return _memory.putIfAbsent(encounterId, _EncounterWorkspaceMemory.new);
}

const _allowedProfiles = {'omni', 'incoming', 'aggregate'};

String _normalizeProfile(String id) =>
    _allowedProfiles.contains(id) ? id : 'omni';

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
    this.selectedProfileId = 'omni',
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
  late final _EncounterWorkspaceMemory _saved;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _saved = _memoryFor(widget.encounterId);
    _saved.profileId = _normalizeProfile(
      _saved.profileId == 'omni' ? widget.selectedProfileId : _saved.profileId,
    );
    Log.d('COMBAT.UI', 'comparison workspace init ${widget.encounterId}');
  }

  Future<void> _capture() async {
    final result = await widget.onCaptureCurrent?.call();
    if (!mounted) return;
    final message = switch (result?.code) {
      AarComparisonFailureCode.authUnavailable => kComparisonAuthUnavailable,
      AarComparisonFailureCode.noShip => kComparisonNoShip,
      AarComparisonFailureCode.captureFailure => kComparisonCaptureFailure,
      _ => kComparisonCaptureSaved,
    };
    _presentFeedback(message);
  }

  Future<void> _refreshPrices() async {
    final result = await widget.onRefreshPrices?.call();
    if (!mounted) return;
    final message = result != null && result.isSuccess
        ? 'Price estimates refreshed.'
        : widget.priceRefreshHasCache
        ? 'Could not refresh prices. Showing cached estimates.'
        : 'Could not refresh prices. Price estimates are unavailable.';
    _presentFeedback(message);
  }

  void _presentFeedback(String message) {
    if (!mounted) return;
    setState(() => _feedback = message);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.clearSnackBars();
    messenger?.showSnackBar(SnackBar(content: Text('$message ')));
  }

  void _select(String id) {
    setState(() => _saved.focusedSourceId = id);
  }

  void _setProfile(String id) {
    setState(() => _saved.profileId = id);
    widget.onProfileChanged?.call(id);
  }

  List<AarComparisonSourceEntry> _visible(
    AarComparisonLayoutMode mode,
    List<AarComparisonSourceEntry> entries,
  ) {
    if (entries.isEmpty) return const [];
    if (mode == AarComparisonLayoutMode.fourColumn) {
      return entries.take(4).toList();
    }
    if (mode == AarComparisonLayoutMode.stacked) {
      final focused = _saved.focusedSourceId;
      for (final entry in entries) {
        if (entry.id == focused) return [entry];
      }
      return [entries.first];
    }
    final extra = mode == AarComparisonLayoutMode.baselinePlusTwo ? 2 : 1;
    final baseline = entries.first;
    final rest = entries.skip(1).toList();
    final focused = _saved.focusedSourceId;
    final ordered = <AarComparisonSourceEntry>[
      if (focused != null)
        for (final entry in rest)
          if (entry.id == focused) entry,
      ...rest.where((entry) => entry.id != focused),
    ];
    return [baseline, ...ordered.take(extra)];
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.sources.visibleEntries;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final mode = aarComparisonLayoutModeForWidth(
          constraints.maxWidth,
          textScale: textScale,
        );
        final visible = _visible(mode, entries);
        return Column(
          key: const Key('aar-fit-comparison-workspace'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
              ],
            ),
            if (_feedback != null) Text(_feedback!),
            if (widget.sources.visibleEntries.length > 1)
              AarComparisonSourceSelector(
                sources: widget.sources,
                onSelect: _select,
              ),
            AarComparisonAssumptionsBar(
              selectedProfileId: _saved.profileId,
              onProfileChanged: _setProfile,
            ),
            const Wrap(
              spacing: 8,
              children: [Text('Added'), Text('Removed'), Text('Modified')],
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => setState(() => _saved.changesOnly = false),
                  child: const Text('Show all'),
                ),
                TextButton(
                  onPressed: () => setState(() => _saved.changesOnly = true),
                  child: const Text('Changes only'),
                ),
              ],
            ),
            if (widget.diff != null && !widget.diff!.hasRecordedChanges)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No recorded equipment changes'),
              ),
            AarComparisonColumns(
              mode: mode,
              entries: entries,
              visible: visible,
              diff: widget.diff,
              changesOnly: _saved.changesOnly,
              focusedId: _saved.focusedSourceId,
              ownLossDeduplicated: widget.sources.ownLossDeduplicated,
              onSelect: _select,
            ),
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
            if (widget.proposal != null) _proposalDisclosure(widget.proposal!),
          ],
        );
      },
    );
  }

  Widget _proposalDisclosure(AarFitProposal proposal) {
    final unstructured =
        proposal.target == null ||
        proposal.status == AarProposalValidationStatus.invalid ||
        proposal.status == AarProposalValidationStatus.unsupportedVersion;
    final earlier =
        proposal.baselineSnapshotId != null &&
        proposal.baselineSnapshotId != widget.currentBaselineSnapshotId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (earlier) const Text('Based on an earlier fit.'),
        if (unstructured) const Text('No structured proposed fit.'),
        if (proposal.rationale.isNotEmpty) Text(proposal.rationale),
      ],
    );
  }
}

class AarComparisonSourceSelector extends StatelessWidget {
  const AarComparisonSourceSelector({
    super.key,
    required this.sources,
    this.onSelect,
  });

  final AarComparisonSources sources;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('aar-comparison-source-selector'),
      spacing: 4,
      children: [
        for (final entry in sources.visibleEntries)
          TextButton(
            key: Key('aar-comparison-select-${entry.id}'),
            onPressed: () => onSelect?.call(entry.id),
            child: Text(entry.label),
          ),
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
      value: _normalizeProfile(selectedProfileId),
      items: const [
        DropdownMenuItem(value: 'omni', child: Text('Omni')),
        DropdownMenuItem(value: 'incoming', child: Text('Incoming allocation')),
        DropdownMenuItem(value: 'aggregate', child: Text('Aggregate blend')),
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
    required this.visible,
    this.diff,
    this.changesOnly = false,
    this.focusedId,
    this.ownLossDeduplicated = false,
    this.onSelect,
  });

  final AarComparisonLayoutMode mode;
  final List<AarComparisonSourceEntry> entries;
  final List<AarComparisonSourceEntry> visible;
  final FitInventoryDiff? diff;
  final bool changesOnly;
  final String? focusedId;
  final bool ownLossDeduplicated;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('aar-comparison-layout-${mode.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mode == AarComparisonLayoutMode.stacked)
          Wrap(
            spacing: 8,
            children: [
              for (final entry in entries)
                ChoiceChip(
                  key: Key('aar-comparison-source-tab-${entry.id}'),
                  label: Text(entry.label, overflow: TextOverflow.ellipsis),
                  selected: visible.any((item) => item.id == entry.id),
                  onSelected: (_) => onSelect?.call(entry.id),
                ),
            ],
          ),
        if (mode == AarComparisonLayoutMode.stacked)
          for (final entry in visible)
            AarFitComparisonCard(
              entry: entry,
              diff: diff,
              changesOnly: changesOnly,
              ownLossDeduplicated: ownLossDeduplicated,
            )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in visible)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AarFitComparisonCard(
                      entry: entry,
                      diff: diff,
                      changesOnly: changesOnly,
                      ownLossDeduplicated: ownLossDeduplicated,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
