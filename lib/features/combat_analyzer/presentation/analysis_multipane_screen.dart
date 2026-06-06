import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/widgets/eve_type_icon.dart';
import '../data/combat_analysis_service.dart';
import '../data/combat_damage_profile_resolver.dart';
import '../data/combat_providers.dart';
import '../domain/combat_aar_report.dart';
import '../domain/combat_damage_profile.dart';
import '../domain/combat_enrichment.dart';
import '../domain/parsed_combat_encounter.dart';
import '../../fitting/domain/models.dart';
import '../../wallet/data/wallet_providers.dart';
import 'widgets/damage_chart_painter.dart';

class AnalysisMultiPaneScreen extends ConsumerStatefulWidget {
  final ParsedCombatEncounter encounter;

  const AnalysisMultiPaneScreen({super.key, required this.encounter});

  @override
  ConsumerState<AnalysisMultiPaneScreen> createState() =>
      _AnalysisMultiPaneScreenState();
}

class _AnalysisMultiPaneScreenState
    extends ConsumerState<AnalysisMultiPaneScreen> {
  Future<CombatEncounter?>? _cachedAnalysisFuture;
  Future<CombatEncounter>? _analysisFuture;
  CombatAnalysisProgress? _analysisProgress;

  @override
  void initState() {
    super.initState();
    Log.d('COMBAT.UI', 'AnalysisMultiPaneScreen.initState()');
    _cachedAnalysisFuture = _loadCachedAnalysis();
  }

  Future<CombatEncounter?> _loadCachedAnalysis() {
    Log.d('COMBAT.UI', '_loadCachedAnalysis() - START');
    return ref
        .read(combatAnalysisServiceProvider)
        .getCachedAnalysis(widget.encounter);
  }

  void _startAnalysis({bool forceRefresh = false}) {
    Log.i(
      'COMBAT.UI',
      forceRefresh
          ? 'User requested combat re-analysis'
          : 'User requested combat analysis',
    );
    setState(() => _analysisProgress = null);
    final future = ref
        .read(combatAnalysisServiceProvider)
        .analyzeEncounter(
          widget.encounter,
          forceRefresh: forceRefresh,
          onProgress: (progress) {
            Log.d('COMBAT.UI', 'Analysis progress UI: ${progress.label}');
            if (!mounted) return;
            setState(() => _analysisProgress = progress);
          },
        );
    setState(() {
      _analysisFuture = future;
    });
  }

  Future<void> _captureCurrentFit({required bool confirmed}) async {
    Log.i(
      'COMBAT.UI',
      'User requested current fit capture confirmed=$confirmed',
    );
    try {
      await ref
          .read(combatEnrichmentServiceProvider)
          .captureCurrentPilotFit(widget.encounter, confirmed: confirmed);
      ref.invalidate(combatEnrichmentProvider(widget.encounter.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirmed
                ? 'Current fit confirmed for this AAR. Re-analyze to include it.'
                : 'Current fit snapshot saved as reference evidence.',
          ),
        ),
      );
      setState(() {});
    } catch (e, stack) {
      Log.e('COMBAT.UI', 'Failed to capture current fit', e, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to capture fit: $e')));
    }
  }

  Future<void> _showImportFitDialog() async {
    Log.i('COMBAT.UI', 'User opened pilot fit import dialog');
    final controller = TextEditingController();
    final rawFit = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import Pilot Fit'),
          content: SizedBox(
            width: 560,
            child: TextField(
              controller: controller,
              minLines: 10,
              maxLines: 16,
              decoration: const InputDecoration(
                hintText: '[Rifter, Fight Fit]\nDamage Control II\n...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (rawFit == null || rawFit.trim().isEmpty) return;

    try {
      await ref
          .read(combatEnrichmentServiceProvider)
          .importPilotFit(widget.encounter, rawFit);
      ref.invalidate(combatEnrichmentProvider(widget.encounter.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilot fit imported. Re-analyze to include it.'),
        ),
      );
      setState(() {});
    } catch (e, stack) {
      Log.e('COMBAT.UI', 'Failed to import pilot fit', e, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to import fit: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    Log.d('COMBAT.UI', 'AnalysisMultiPaneScreen.build()');
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '${_formatAarDateUtc(widget.encounter.startTime)} ${widget.encounter.characterName} - After Action Report',
        ),
      ),
      body: _analysisFuture != null
          ? _buildAnalysisFuture(theme, _analysisFuture!)
          : _buildCachedAnalysisFuture(theme),
    );
  }

  Widget _buildCachedAnalysisFuture(ThemeData theme) {
    return FutureBuilder<CombatEncounter?>(
      future: _cachedAnalysisFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildError(
            theme,
            'Failed to Load Cached Analysis',
            snapshot.error!,
          );
        }

        final cached = snapshot.data;
        if (cached == null) {
          return _buildAnalyzePrompt(theme);
        }

        return _buildAnalysisContent(theme, cached);
      },
    );
  }

  Widget _buildAnalysisFuture(
    ThemeData theme,
    Future<CombatEncounter> analysisFuture,
  ) {
    return FutureBuilder<CombatEncounter>(
      future: analysisFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildProgress(theme, _analysisProgress);
        }

        if (snapshot.hasError) {
          return _buildError(theme, 'Analysis Failed', snapshot.error!);
        }

        return _buildAnalysisContent(theme, snapshot.data!);
      },
    );
  }

  Widget _buildAnalyzePrompt(ThemeData theme) {
    final encounter = widget.encounter;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Parsed Encounter',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  _StatChip(label: 'Pilot', value: encounter.characterName),
                  _StatChip(label: 'Outcome', value: encounter.outcomeLabel),
                  _StatChip(
                    label: 'Dealt',
                    value: '${encounter.totalDamageDealt}',
                  ),
                  _StatChip(
                    label: 'Taken',
                    value: '${encounter.totalDamageReceived}',
                  ),
                  _StatChip(
                    label: 'Duration',
                    value: '${encounter.durationSeconds}s',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _startAnalysis(),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Analyze With AI'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(ThemeData theme, CombatAnalysisProgress? progress) {
    Log.d('COMBAT.UI', '_buildProgress(${progress?.label})');
    final value = progress?.isIndeterminate == true ? null : progress?.value;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                progress?.label ?? 'Preparing analysis',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: value),
              const SizedBox(height: 12),
              Text(
                progress?.detail ??
                    'Starting the After Action Report workflow.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Step ${progress.stage} of ${progress.stageCount}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme, String title, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _analysisFuture = null;
                  _cachedAnalysisFuture = _loadCachedAnalysis();
                });
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back To Encounter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisContent(ThemeData theme, CombatEncounter dbEncounter) {
    final report = _reportFromDb(dbEncounter);
    final encounter = widget.encounter;
    final enrichmentAsync = ref.watch(combatEnrichmentProvider(encounter.id));
    final enrichment = enrichmentAsync.when(
      data: (value) => value ?? _logOnlyEnrichment(encounter),
      loading: () => null,
      error: (error, stack) {
        Log.e('COMBAT.UI', 'Failed to load AAR enrichment', error, stack);
        return _logOnlyEnrichment(encounter);
      },
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCommandStrip(theme, encounter, report, enrichment),
          const SizedBox(height: 16),
          enrichment == null
              ? _buildEvidenceLoadingCard(theme)
              : _buildEvidenceCard(theme, enrichment),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 900;
              final timeline = _buildTimelineCard(theme, encounter, report);
              final summary = _buildSummaryCard(theme, report);
              if (narrow) {
                return Column(
                  children: [summary, const SizedBox(height: 16), timeline],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: summary),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: timeline),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _buildReportTabs(theme, encounter, report, enrichment),
        ],
      ),
    );
  }

  CombatAarReport _reportFromDb(CombatEncounter dbEncounter) {
    final analysisJson = dbEncounter.analysisJson;
    if (analysisJson != null && analysisJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(analysisJson);
        if (decoded is Map) {
          return CombatAarReport.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (e, stack) {
        Log.e('COMBAT.UI', 'Failed to parse structured AAR report', e, stack);
      }
    }
    return CombatAarReport.fromLegacy(
      summary: dbEncounter.llmSummary,
      mistakes: dbEncounter.llmFeedbackMistakes,
      improvements: dbEncounter.llmFeedbackImprovements,
      fits: dbEncounter.llmFeedbackFits,
    );
  }

  Widget _buildCommandStrip(
    ThemeData theme,
    ParsedCombatEncounter encounter,
    CombatAarReport report,
    CombatEnrichment? enrichment,
  ) {
    final color = switch (encounter.outcome) {
      CombatOutcome.likelyVictory => Colors.greenAccent,
      CombatOutcome.likelyDefeat => Colors.redAccent,
      CombatOutcome.unknown => Colors.amberAccent,
    };
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.headline,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _startAnalysis(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Re-analyze'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _StatChip(
                  label: 'Outcome',
                  value: encounter.outcomeLabel,
                  color: color,
                ),
                _StatChip(label: 'Pilot', value: encounter.characterName),
                _StatChip(
                  label: 'Duration',
                  value: '${encounter.durationSeconds}s',
                ),
                _StatChip(
                  label: 'Dealt',
                  value: '${encounter.totalDamageDealt}',
                ),
                _StatChip(
                  label: 'Taken',
                  value: '${encounter.totalDamageReceived}',
                ),
                _StatChip(
                  label: 'Target',
                  value: encounter.aggregates.primaryTarget,
                ),
                _StatChip(
                  label: 'Weapon',
                  value: encounter.aggregates.primaryWeapon,
                ),
                _StatChip(
                  label: 'Confidence',
                  value: '${(report.confidence * 100).round()}%',
                ),
                _StatChip(
                  label: 'Evidence',
                  value: enrichment?.badgeLabel ?? 'Checking',
                  color: _evidenceColor(enrichment?.status),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceLoadingCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('Checking AAR evidence', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceCard(ThemeData theme, CombatEnrichment enrichment) {
    final color = _evidenceColor(enrichment.status);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_outlined, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Evidence', style: theme.textTheme.titleMedium),
                ),
                _EvidenceBadge(label: enrichment.badgeLabel, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _StatChip(label: 'Source', value: enrichment.sourceLabel),
                _StatChip(
                  label: 'Confidence',
                  value: '${(enrichment.matchConfidence * 100).round()}%',
                  color: color,
                ),
                if (enrichment.killmailId != null)
                  _StatChip(
                    label: 'Killmail',
                    value: '${enrichment.killmailId}',
                    color: color,
                  ),
                if (enrichment.killmailTime != null)
                  _StatChip(
                    label: 'Time',
                    value: _formatAarDateUtc(enrichment.killmailTime!),
                  ),
                if (enrichment.victimShipTypeId != null)
                  _StatChip(
                    label: 'Victim Ship',
                    value: 'Type #${enrichment.victimShipTypeId}',
                  ),
                if (enrichment.finalBlowShipTypeId != null)
                  _StatChip(
                    label: 'Final Blow Ship',
                    value: 'Type #${enrichment.finalBlowShipTypeId}',
                  ),
              ],
            ),
            if (enrichment.matchReason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(enrichment.matchReason, style: theme.textTheme.bodyMedium),
            ],
            if (enrichment.limitations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Limitations', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              ...enrichment.limitations.map((item) => Text('- $item')),
            ],
            if (enrichment.status == CombatEnrichmentStatus.needsReauth) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).startAuthFlow(),
                icon: const Icon(Icons.login),
                label: const Text('Reauthorize Character'),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _showImportFitDialog,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import Pilot Fit'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _captureCurrentFit(confirmed: false),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Snapshot Current Fit'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _captureCurrentFit(confirmed: true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Use Current Fit For This Fight'),
                ),
              ],
            ),
            if (enrichment.pilotFitEvidence != null) ...[
              const SizedBox(height: 12),
              _StatChip(
                label: 'Pilot Fit',
                value: enrichment.pilotFitEvidence!.confidence.name,
                color: Colors.lightBlueAccent,
              ),
            ],
            if (!enrichment.evidenceLedger.isEmpty) ...[
              const SizedBox(height: 12),
              Text('Evidence Ledger', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              ...enrichment.evidenceLedger.facts
                  .take(5)
                  .map(
                    (fact) => Text(
                      '${fact.id}: ${fact.label} - ${fact.value} (${fact.confidence.name})',
                    ),
                  ),
              if (enrichment.evidenceLedger.unknowns.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Open Unknowns', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                ...enrichment.evidenceLedger.unknowns
                    .take(4)
                    .map(
                      (unknown) =>
                          Text('- ${unknown.label}: ${unknown.detail}'),
                    ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, CombatAarReport report) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Commander Summary', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(report.summary, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text('Outcome Assessment', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(report.outcomeAssessment, style: theme.textTheme.bodyMedium),
            if (report.unknowns.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Unknowns', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...report.unknowns.map((unknown) => Text('- $unknown')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(
    ThemeData theme,
    ParsedCombatEncounter encounter,
    CombatAarReport report,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Damage Timeline', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Expanded(
                child: AarTimelineChart(
                  points: encounter.aggregates.cumulativeDamage,
                  keyMoments: report.keyMoments,
                  events: encounter.events,
                  startTime: encounter.startTime,
                  durationSeconds: encounter.durationSeconds,
                  pilotName: encounter.characterName,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportTabs(
    ThemeData theme,
    ParsedCombatEncounter encounter,
    CombatAarReport report,
    CombatEnrichment? enrichment,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTabController(
          length: 4,
          child: SizedBox(
            height: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Mistakes'),
                    Tab(text: 'Damage'),
                    Tab(text: 'Improvements'),
                    Tab(text: 'Fits'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildMistakesTab(theme, report),
                      _buildDamageTab(theme, encounter, report),
                      _buildImprovementsTab(theme, report),
                      _buildFitsTab(theme, encounter, report, enrichment),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMistakesTab(ThemeData theme, CombatAarReport report) {
    if (report.rankedMistakes.isEmpty) {
      return const Center(child: Text('No ranked mistakes were identified.'));
    }
    return ListView.separated(
      itemCount: report.rankedMistakes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final mistake = report.rankedMistakes[index];
        return _AarCard(
          leading: '#${mistake.rank}',
          title: mistake.title,
          subtitle: mistake.severity.toUpperCase(),
          body: [
            if (mistake.evidence.isNotEmpty) 'Evidence: ${mistake.evidence}',
            if (mistake.impact.isNotEmpty) 'Impact: ${mistake.impact}',
            if (mistake.correction.isNotEmpty)
              'Correction: ${mistake.correction}',
          ],
        );
      },
    );
  }

  Widget _buildDamageTab(
    ThemeData theme,
    ParsedCombatEncounter encounter,
    CombatAarReport report,
  ) {
    Log.d('COMBAT.UI', '_buildDamageTab(${encounter.id})');
    final damageProfileAsync = ref.watch(
      combatDamageProfileProvider(encounter),
    );
    return damageProfileAsync.when(
      data: (profile) =>
          _buildDamageTabContent(theme, encounter, report, profile),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        Log.e('COMBAT.UI', 'Failed to render damage profile', error, stack);
        return _buildDamageTabContent(
          theme,
          encounter,
          report,
          const CombatDamageProfile(
            entries: [],
            unknownWeapons: [],
            totalProfiledDamage: 0,
          ),
        );
      },
    );
  }

  Widget _buildDamageTabContent(
    ThemeData theme,
    ParsedCombatEncounter encounter,
    CombatAarReport report,
    CombatDamageProfile profile,
  ) {
    final aggregates = encounter.aggregates;
    return ListView(
      children: [
        if (!report.damageAnalysis.isEmpty)
          _AarCard(
            leading: Icons.analytics,
            title: 'AI Damage Assessment',
            subtitle:
                'Confidence: ${(report.damageAnalysis.confidence * 100).round()}%',
            body: [
              report.damageAnalysis.summary,
              if (report.damageAnalysis.evidence.isNotEmpty)
                'Evidence: ${report.damageAnalysis.evidence}',
              ...report.damageAnalysis.unknowns.map((item) => 'Unknown: $item'),
            ],
          ),
        if (!report.damageAnalysis.isEmpty) const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              title: 'Damage Dealt',
              value: '${aggregates.totalDamageDealt}',
              detail: 'Peak ${aggregates.peakOutgoingHit}',
              color: Colors.greenAccent,
            ),
            _MetricCard(
              title: 'Damage Taken',
              value: '${aggregates.totalDamageReceived}',
              detail: 'Peak ${aggregates.peakIncomingHit}',
              color: Colors.redAccent,
            ),
            _MetricCard(
              title: 'Shots Fired',
              value: '${aggregates.outgoingShotCount}',
              detail: '${aggregates.outgoingHitCount} hits',
              color: Colors.lightBlueAccent,
            ),
            _MetricCard(
              title: 'Hit Rate',
              value: _formatPercent(aggregates.outgoingHitRate),
              detail: '${aggregates.missCount} misses',
              color: Colors.amberAccent,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ApplicationSection(aggregates: aggregates),
        const SizedBox(height: 16),
        _DamageTypeSection(profile: profile, report: report),
        const SizedBox(height: 16),
        _BreakdownSection(
          title: 'Primary Targets',
          values: encounter.aggregates.damageByTarget,
          color: Colors.greenAccent,
        ),
        const SizedBox(height: 16),
        _BreakdownSection(
          title: 'Weapons And Drones',
          values: encounter.aggregates.damageByWeapon,
          color: Colors.lightBlueAccent,
        ),
        const SizedBox(height: 16),
        _BreakdownSection(
          title: 'Incoming Sources',
          values: encounter.aggregates.incomingBySource,
          color: Colors.redAccent,
        ),
      ],
    );
  }

  Widget _buildImprovementsTab(ThemeData theme, CombatAarReport report) {
    final cards = <Widget>[
      ...report.recommendations.map(
        (recommendation) => _AarCard(
          leading: recommendation.linkedMistakeRank == null
              ? Icons.trending_up
              : '#${recommendation.linkedMistakeRank}',
          title: recommendation.title,
          subtitle: 'Recommendation',
          body: [recommendation.details],
        ),
      ),
      ...report.trainingDrills.map(
        (drill) => _AarCard(
          leading: Icons.fitness_center,
          title: drill.title,
          subtitle: 'Training Drill',
          body: [drill.details],
        ),
      ),
    ];
    if (cards.isEmpty) {
      return const Center(child: Text('No improvements were identified.'));
    }
    return ListView.separated(
      itemCount: cards.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => cards[index],
    );
  }

  Widget _buildFitsTab(
    ThemeData theme,
    ParsedCombatEncounter encounter,
    CombatAarReport report,
    CombatEnrichment? enrichment,
  ) {
    final observed = {
      ...encounter.aggregates.damageByWeapon.keys,
      ...report.fitAdvice.expand((advice) => advice.observedItems),
    }.where((item) => item != 'Unknown').toList();

    return ListView(
      children: [
        if (enrichment?.pilotFitEvidence != null) ...[
          _DestroyedFitSection(
            fitting: enrichment!.pilotFitEvidence!.fitting,
            title:
                'Pilot Fit - ${enrichment.pilotFitEvidence!.confidence.name}',
          ),
          const SizedBox(height: 12),
        ],
        if (enrichment?.destroyedFit != null) ...[
          _DestroyedFitSection(
            fitting: enrichment!.destroyedFit!,
            title: enrichment.victimName == null
                ? 'Destroyed Ship Fit'
                : 'Destroyed Ship Fit - ${enrichment.victimName}',
          ),
          const SizedBox(height: 12),
        ],
        if (observed.isNotEmpty)
          _AarCard(
            leading: Icons.visibility,
            title: 'Observed Weapons And Drones',
            subtitle: 'From combat log evidence',
            body: observed.toList(),
          ),
        const SizedBox(height: 12),
        if (report.fitAdvice.isEmpty)
          const Center(child: Text('No fitting advice was identified.'))
        else
          ...report.fitAdvice.map(
            (advice) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AarCard(
                leading: Icons.construction,
                title: advice.title,
                subtitle: 'Confidence: ${advice.confidence}',
                body: [
                  advice.details,
                  if (advice.recommendedItems.isNotEmpty)
                    'Recommended: ${advice.recommendedItems.join(', ')}',
                  if (advice.limitations.isNotEmpty)
                    'Limitations: ${advice.limitations}',
                ],
              ),
            ),
          ),
      ],
    );
  }

  CombatEnrichment _logOnlyEnrichment(ParsedCombatEncounter encounter) {
    return CombatEnrichment(
      parsedEncounterId: encounter.id,
      status: CombatEnrichmentStatus.logOnly,
      source: CombatEnrichmentSource.none,
      matchReason: 'No killmail evidence is cached for this AAR.',
      limitations: const ['This report is based on combat-log evidence only.'],
    );
  }
}

String _formatAarDateUtc(DateTime value) {
  final utc = value.toUtc();
  final year = utc.year.toString().padLeft(4, '0');
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  final hour = utc.hour.toString().padLeft(2, '0');
  final minute = utc.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute UTC';
}

String _formatPercent(double value) => '${(value * 100).round()}%';

Color _evidenceColor(CombatEnrichmentStatus? status) {
  return switch (status) {
    CombatEnrichmentStatus.killmailMatched => Colors.greenAccent,
    CombatEnrichmentStatus.ambiguous => Colors.amberAccent,
    CombatEnrichmentStatus.needsReauth => Colors.orangeAccent,
    CombatEnrichmentStatus.logOnly || null => Colors.white70,
  };
}

class _EvidenceBadge extends StatelessWidget {
  const _EvidenceBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
        color: color.withAlpha(22),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DestroyedFitSection extends StatelessWidget {
  const _DestroyedFitSection({required this.fitting, required this.title});

  final Fitting fitting;
  final String title;

  @override
  Widget build(BuildContext context) {
    final groups = [
      _FitSlotGroupData('High', fitting.highSlots),
      _FitSlotGroupData('Mid', fitting.medSlots),
      _FitSlotGroupData('Low', fitting.lowSlots),
      _FitSlotGroupData('Rig', fitting.rigSlots),
      _FitSlotGroupData('Subsystem', fitting.subsystems),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent.withAlpha(70)),
        color: Colors.greenAccent.withAlpha(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EveTypeIcon(typeId: fitting.shipTypeId, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: groups
                .where((group) => group.modules.isNotEmpty)
                .map((group) => _FitSlotGroup(group: group))
                .toList(),
          ),
          if (fitting.drones.isNotEmpty || fitting.cargo.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (fitting.drones.isNotEmpty)
                  _InventoryGroup(
                    title: 'Drones',
                    items: fitting.drones
                        .map(
                          (drone) => _InventoryItem(
                            typeId: drone.typeId,
                            quantity: drone.quantity,
                          ),
                        )
                        .toList(),
                  ),
                if (fitting.cargo.isNotEmpty)
                  _InventoryGroup(
                    title: 'Cargo',
                    items: fitting.cargo
                        .map(
                          (item) => _InventoryItem(
                            typeId: item.typeId,
                            quantity: item.quantity,
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FitSlotGroupData {
  const _FitSlotGroupData(this.title, this.modules);

  final String title;
  final List<FittedModule> modules;
}

class _FitSlotGroup extends StatelessWidget {
  const _FitSlotGroup({required this.group});

  final _FitSlotGroupData group;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ...group.modules.map(
            (module) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _FitModuleTile(module: module),
            ),
          ),
        ],
      ),
    );
  }
}

class _FitModuleTile extends ConsumerWidget {
  const _FitModuleTile({required this.module});

  final FittedModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = ref.watch(itemNameProvider(module.typeId));
    final chargeNameAsync = module.chargeTypeId == null
        ? null
        : ref.watch(itemNameProvider(module.chargeTypeId!));
    final moduleName = nameAsync.when(
      data: (name) => name,
      loading: () => module.typeName,
      error: (error, stack) => module.typeName,
    );
    final chargeName = chargeNameAsync?.when(
      data: (name) => name,
      loading: () => module.chargeName ?? 'Type #${module.chargeTypeId}',
      error: (error, stack) =>
          module.chargeName ?? 'Type #${module.chargeTypeId}',
    );
    return Row(
      children: [
        EveTypeIcon(typeId: module.typeId, size: 30),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(moduleName, overflow: TextOverflow.ellipsis),
              if (chargeName != null)
                Text(
                  chargeName,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InventoryItem {
  const _InventoryItem({required this.typeId, required this.quantity});

  final int typeId;
  final int quantity;
}

class _InventoryGroup extends StatelessWidget {
  const _InventoryGroup({required this.title, required this.items});

  final String title;
  final List<_InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ...items
              .take(8)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _InventoryTile(item: item),
                ),
              ),
          if (items.length > 8)
            Text(
              '+${items.length - 8} more',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _InventoryTile extends ConsumerWidget {
  const _InventoryTile({required this.item});

  final _InventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = ref.watch(itemNameProvider(item.typeId));
    final name = nameAsync.when(
      data: (value) => value,
      loading: () => 'Type #${item.typeId}',
      error: (error, stack) => 'Type #${item.typeId}',
    );
    return Row(
      children: [
        EveTypeIcon(typeId: item.typeId, size: 30),
        const SizedBox(width: 8),
        Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Text('x${item.quantity}', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.primary).withAlpha(28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (color ?? Theme.of(context).colorScheme.primary).withAlpha(70),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                color: Colors.white.withAlpha(150),
                fontSize: 12,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String title;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
        color: color.withAlpha(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ApplicationSection extends StatelessWidget {
  const _ApplicationSection({required this.aggregates});

  final CombatAggregates aggregates;

  @override
  Widget build(BuildContext context) {
    final qualities = aggregates.outgoingHitQualityCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Application', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _PercentRow(
          label: 'Hits',
          count: aggregates.outgoingHitCount,
          total: aggregates.outgoingShotCount,
          color: Colors.greenAccent,
        ),
        _PercentRow(
          label: 'Misses',
          count: aggregates.missCount,
          total: aggregates.outgoingShotCount,
          color: Colors.redAccent,
        ),
        ...qualities.map(
          (entry) => _PercentRow(
            label: entry.key,
            count: entry.value,
            total: aggregates.outgoingShotCount,
            color: Colors.amberAccent,
          ),
        ),
      ],
    );
  }
}

class _PercentRow extends StatelessWidget {
  const _PercentRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 8,
                color: color,
                backgroundColor: Colors.white.withAlpha(18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              '$count / $total (${_formatPercent(percent)})',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DamageTypeSection extends StatelessWidget {
  const _DamageTypeSection({required this.profile, required this.report});

  final CombatDamageProfile profile;
  final CombatAarReport report;

  @override
  Widget build(BuildContext context) {
    final llmEntries = report.damageAnalysis.damageTypes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Damage Type Profile',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (profile.entries.isEmpty)
          Text(
            'No exact SDE damage type match for observed outgoing weapons.',
            style: TextStyle(color: Colors.white.withAlpha(160)),
          )
        else
          ...profile.entries.map(
            (entry) => _DamageTypeRow(
              label: entry.type,
              amount: entry.amount,
              percent: entry.percent,
              confidence: entry.confidenceLabel,
              source: entry.source,
              color: _damageTypeColor(entry.type),
            ),
          ),
        if (llmEntries.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'AI inferred notes',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          ...llmEntries.map(
            (entry) => _DamageTypeRow(
              label: entry.type,
              amount: entry.amount,
              percent: entry.percent > 1 ? entry.percent / 100 : entry.percent,
              confidence: entry.confidence,
              source: entry.source,
              color: _damageTypeColor(entry.type),
            ),
          ),
        ],
        if (profile.unknownWeapons.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Unknown damage type: ${profile.unknownWeapons.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (report.damageAnalysis.defenseNotes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Defense notes', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ...report.damageAnalysis.defenseNotes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${note.layer}: ${note.note} (${note.confidence})'),
            ),
          ),
        ],
      ],
    );
  }

  Color _damageTypeColor(String type) {
    return switch (type.toLowerCase()) {
      'em' => Colors.lightBlueAccent,
      'thermal' => Colors.orangeAccent,
      'kinetic' => Colors.purpleAccent,
      'explosive' => Colors.redAccent,
      _ => Colors.white70,
    };
  }
}

class _DamageTypeRow extends StatelessWidget {
  const _DamageTypeRow({
    required this.label,
    required this.amount,
    required this.percent,
    required this.confidence,
    required this.source,
    required this.color,
  });

  final String label;
  final int amount;
  final double percent;
  final String confidence;
  final String source;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clampedPercent = percent.clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: clampedPercent,
                minHeight: 8,
                color: color,
                backgroundColor: Colors.white.withAlpha(18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 190,
            child: Text(
              '$amount ${_formatPercent(percent)} - $confidence',
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (source.isNotEmpty) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: source,
              child: const Icon(Icons.info_outline, size: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class _AarCard extends StatelessWidget {
  const _AarCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final Object leading;
  final String title;
  final String subtitle;
  final List<String> body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withAlpha(35),
            child: leading is IconData
                ? Icon(leading as IconData, size: 18)
                : Text(leading.toString()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withAlpha(140),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ...body
                    .where((line) => line.trim().isNotEmpty)
                    .map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(line),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({
    required this.title,
    required this.values,
    required this.color,
  });

  final String title;
  final Map<String, int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final sorted = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sorted.isEmpty ? 0 : sorted.first.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          Text('No data', style: TextStyle(color: Colors.white.withAlpha(150)))
        else
          ...sorted
              .take(8)
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(entry.value.toString()),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: maxValue == 0 ? 0 : entry.value / maxValue,
                          color: color,
                          backgroundColor: Colors.white.withAlpha(18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}
