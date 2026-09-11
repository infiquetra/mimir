import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../data/combat_providers.dart';
import '../../domain/aar_evidence_assessment.dart';
import '../../domain/parsed_combat_encounter.dart';

class AarEvidenceActionHandlers {
  const AarEvidenceActionHandlers({
    this.onUseCurrentFit,
    this.onImportFit,
    this.onSearchKillmails,
    this.onReauthorize,
  });

  final VoidCallback? onUseCurrentFit;
  final VoidCallback? onImportFit;
  final VoidCallback? onSearchKillmails;
  final VoidCallback? onReauthorize;

  VoidCallback? operator [](AarEvidenceAction action) => switch (action) {
    AarEvidenceAction.useCurrentFit => onUseCurrentFit,
    AarEvidenceAction.importFit => onImportFit,
    AarEvidenceAction.searchKillmails => onSearchKillmails,
    AarEvidenceAction.reauthorize => onReauthorize,
  };
}

/// Provider-aware shell: watches [aarEvidenceAssessmentProvider], owns collapse.
class AarEvidenceChecklistCard extends ConsumerStatefulWidget {
  const AarEvidenceChecklistCard({
    super.key,
    required this.encounter,
    this.handlers = const AarEvidenceActionHandlers(),
  });

  final ParsedCombatEncounter encounter;
  final AarEvidenceActionHandlers handlers;

  @override
  ConsumerState<AarEvidenceChecklistCard> createState() =>
      _AarEvidenceChecklistCardState();
}

class _AarEvidenceChecklistCardState
    extends ConsumerState<AarEvidenceChecklistCard> {
  bool? _collapsed;

  @override
  Widget build(BuildContext context) {
    Log.d(
      'COMBAT.UI',
      'AarEvidenceChecklistCard built for ${widget.encounter.id}',
    );
    final async = ref.watch(aarEvidenceAssessmentProvider(widget.encounter));
    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (assessment) {
        final collapsed = _collapsed ?? assessment.collapsedByDefault;
        return AarEvidenceChecklistBody(
          assessment: assessment,
          handlers: widget.handlers,
          collapsed: collapsed,
          onToggle: () => setState(() => _collapsed = !collapsed),
        );
      },
      loading: () => const AarEvidenceSkeletonCard(),
      error: (error, stackTrace) => const AarEvidenceUnavailableCard(),
    );
  }
}

class AarEvidenceSkeletonCard extends StatelessWidget {
  const AarEvidenceSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    Log.d('COMBAT.UI', 'AarEvidenceSkeletonCard');
    return const Card(
      key: Key('aar-evidence-skeleton'),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assessing evidence…'),
            SizedBox(height: 8),
            LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class AarEvidenceUnavailableCard extends StatelessWidget {
  const AarEvidenceUnavailableCard({super.key});

  @override
  Widget build(BuildContext context) {
    Log.d('COMBAT.UI', 'AarEvidenceUnavailableCard');
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Text('Evidence assessment unavailable'),
      ),
    );
  }
}

class AarEvidenceChecklistBody extends StatelessWidget {
  const AarEvidenceChecklistBody({
    super.key,
    required this.assessment,
    required this.handlers,
    required this.collapsed,
    required this.onToggle,
  });

  final AarEvidenceAssessment assessment;
  final AarEvidenceActionHandlers handlers;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    Log.d(
      'COMBAT.UI',
      'AarEvidenceChecklistBody ${assessment.logLine} collapsed=$collapsed',
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Evidence Completeness',
                    style: TextStyle(
                      color: EveColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Chip(
                  key: const Key('aar-evidence-score-chip'),
                  label: Text('${assessment.score}%'),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  key: const Key('aar-evidence-toggle'),
                  onPressed: onToggle,
                  icon: Icon(collapsed ? Icons.expand_more : Icons.expand_less),
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              key: const Key('aar-evidence-progress'),
              value: assessment.score / 100,
              color: _bandColor(assessment.band),
              backgroundColor: EveColors.borderSubtle,
            ),
            const SizedBox(height: 8),
            Text(
              assessment.bandLabel,
              style: const TextStyle(
                color: EveColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              assessment.headline,
              style: const TextStyle(color: EveColors.textPrimary),
            ),
            if (!collapsed) ...[
              const SizedBox(height: 12),
              for (final row in assessment.ordered)
                AarEvidenceChecklistRow(row: row, handlers: handlers),
              AarEvidenceLimitsSection(limits: assessment.structuralLimits),
            ],
          ],
        ),
      ),
    );
  }
}

class AarEvidenceChecklistRow extends StatelessWidget {
  AarEvidenceChecklistRow({required this.row, required this.handlers})
    : super(key: Key('aar-evidence-row-${row.dimension.name}'));

  final AarEvidenceDimensionResult row;
  final AarEvidenceActionHandlers handlers;

  @override
  Widget build(BuildContext context) {
    final visual = _statusVisual(row.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(visual.$1, color: visual.$2, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          row.dimension.label,
                          style: const TextStyle(
                            color: EveColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          row.status.label,
                          style: TextStyle(color: visual.$2, fontSize: 12),
                        ),
                        if (row.status == AarEvidenceStatus.missing)
                          Padding(
                            key: Key('aar-evidence-gain-${row.dimension.name}'),
                            padding: EdgeInsets.zero,
                            child: Text(
                              '+${row.pointsToComplete} pts',
                              style: const TextStyle(
                                color: EveColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.detail,
                      style: const TextStyle(
                        color: EveColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (row.actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in row.actions)
                    if (handlers[action] != null)
                      OutlinedButton.icon(
                        key: Key(
                          'aar-evidence-action-${action.name}-${row.dimension.name}',
                        ),
                        onPressed: handlers[action],
                        icon: Icon(_actionIcon(action), size: 16),
                        label: Text(action.buttonLabel),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class AarEvidenceLimitsSection extends StatelessWidget {
  const AarEvidenceLimitsSection({super.key, required this.limits});

  final List<AarStructuralLimit> limits;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('aar-evidence-limits'),
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Known limits',
            style: TextStyle(
              color: EveColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final limit in limits)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                limit.detail,
                style: const TextStyle(
                  color: EveColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Color _bandColor(AarEvidenceBand band) => switch (band) {
  AarEvidenceBand.low => EveColors.error,
  AarEvidenceBand.partial => EveColors.warning,
  AarEvidenceBand.good || AarEvidenceBand.complete => EveColors.success,
};

(IconData, Color) _statusVisual(AarEvidenceStatus status) => switch (status) {
  AarEvidenceStatus.complete => (Icons.check_circle, EveColors.success),
  AarEvidenceStatus.partial => (Icons.warning_amber, EveColors.warning),
  AarEvidenceStatus.inferred => (Icons.help_outline, EveColors.warning),
  AarEvidenceStatus.missing => (Icons.cancel_outlined, EveColors.error),
  AarEvidenceStatus.unavailable => (Icons.block, EveColors.textSecondary),
};

IconData _actionIcon(AarEvidenceAction action) => switch (action) {
  AarEvidenceAction.useCurrentFit => Icons.screenshot_monitor,
  AarEvidenceAction.importFit => Icons.upload_file,
  AarEvidenceAction.searchKillmails => Icons.search,
  AarEvidenceAction.reauthorize => Icons.lock_open,
};
