import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../../characters/data/character_providers.dart';
import '../data/combat_providers.dart';
import '../domain/parsed_combat_encounter.dart';
import 'analysis_multipane_screen.dart';
import 'widgets/device_auth_dialog.dart';

enum EncounterScope { selected, all }

enum EncounterGroupMode { timeline, outcome }

enum EncounterSort { newest, oldest, damageDealt, damageReceived, duration }

class EncounterListScreen extends ConsumerStatefulWidget {
  const EncounterListScreen({super.key});

  @override
  ConsumerState<EncounterListScreen> createState() =>
      _EncounterListScreenState();
}

class _EncounterListScreenState extends ConsumerState<EncounterListScreen> {
  EncounterScope _scope = EncounterScope.selected;
  EncounterGroupMode _groupMode = EncounterGroupMode.timeline;
  EncounterSort _sort = EncounterSort.newest;

  @override
  Widget build(BuildContext context) {
    Log.d('COMBAT.UI', 'EncounterListScreen.build()');
    final encountersAsync = ref.watch(rawEncountersProvider);
    final aarStatusesAsync = ref.watch(combatAarStatusesProvider);
    final aarStatuses = aarStatusesAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const <String, CombatAarStatus>{},
    );
    final activeCharacter = ref.watch(activeCharacterProvider).value;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('AI Combat Analyzer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Choose Log Directory',
            onPressed: () => _chooseLogDirectory(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'LLM Settings',
            onPressed: () {
              Log.i('COMBAT.UI', 'User opened AI settings');
              _showSettingsDialog(context, ref);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Logs',
            onPressed: () {
              Log.i('COMBAT.UI', 'User refreshed combat logs');
              ref.invalidate(rawEncountersProvider);
            },
          ),
        ],
      ),
      body: encountersAsync.when(
        data: (encounters) {
          final visible = _visibleEncounters(encounters, activeCharacter);
          if (encounters.isEmpty) {
            return const Center(
              child: Text(
                'No combat encounters found.\nUse the folder button to select your EVE Gamelogs directory.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return Column(
            children: [
              _buildControls(context, activeCharacter),
              Expanded(
                child: visible.isEmpty
                    ? _buildFilteredEmptyState(activeCharacter)
                    : _buildEncounterList(context, visible, aarStatuses),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Error loading logs:\n$err',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, Character? activeCharacter) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withAlpha(180),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<EncounterScope>(
              segments: [
                ButtonSegment(
                  value: EncounterScope.selected,
                  label: Text(activeCharacter?.name ?? 'Selected'),
                  icon: const Icon(Icons.person),
                ),
                const ButtonSegment(
                  value: EncounterScope.all,
                  label: Text('All'),
                  icon: Icon(Icons.groups),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (value) {
                Log.i(
                  'COMBAT.UI',
                  'Encounter scope changed to ${value.first.name}',
                );
                setState(() => _scope = value.first);
              },
            ),
            SegmentedButton<EncounterGroupMode>(
              segments: const [
                ButtonSegment(
                  value: EncounterGroupMode.timeline,
                  label: Text('Timeline'),
                  icon: Icon(Icons.timeline),
                ),
                ButtonSegment(
                  value: EncounterGroupMode.outcome,
                  label: Text('Outcome'),
                  icon: Icon(Icons.flag),
                ),
              ],
              selected: {_groupMode},
              onSelectionChanged: (value) {
                Log.i(
                  'COMBAT.UI',
                  'Encounter group changed to ${value.first.name}',
                );
                setState(() => _groupMode = value.first);
              },
            ),
            DropdownButton<EncounterSort>(
              value: _sort,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: EncounterSort.newest,
                  child: Text('Newest'),
                ),
                DropdownMenuItem(
                  value: EncounterSort.oldest,
                  child: Text('Oldest'),
                ),
                DropdownMenuItem(
                  value: EncounterSort.damageDealt,
                  child: Text('Damage Dealt'),
                ),
                DropdownMenuItem(
                  value: EncounterSort.damageReceived,
                  child: Text('Damage Taken'),
                ),
                DropdownMenuItem(
                  value: EncounterSort.duration,
                  child: Text('Duration'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                Log.i('COMBAT.UI', 'Encounter sort changed to ${value.name}');
                setState(() => _sort = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState(Character? activeCharacter) {
    final name = activeCharacter?.name ?? 'the selected character';
    return Center(
      child: Text(
        _scope == EncounterScope.selected
            ? 'No combat encounters found for $name.'
            : 'No combat encounters match the current filters.',
        textAlign: TextAlign.center,
      ),
    );
  }

  List<ParsedCombatEncounter> _visibleEncounters(
    List<ParsedCombatEncounter> encounters,
    Character? activeCharacter,
  ) {
    final filtered = encounters.where((encounter) {
      if (_scope == EncounterScope.all) return true;
      if (activeCharacter == null) return false;
      if (encounter.characterId != null) {
        return encounter.characterId == activeCharacter.characterId;
      }
      return encounter.characterName.trim().toLowerCase() ==
          activeCharacter.name.trim().toLowerCase();
    }).toList();

    filtered.sort(_compareEncounters);
    return filtered;
  }

  int _compareEncounters(ParsedCombatEncounter a, ParsedCombatEncounter b) {
    return switch (_sort) {
      EncounterSort.newest => b.startTime.compareTo(a.startTime),
      EncounterSort.oldest => a.startTime.compareTo(b.startTime),
      EncounterSort.damageDealt => b.totalDamageDealt.compareTo(
        a.totalDamageDealt,
      ),
      EncounterSort.damageReceived => b.totalDamageReceived.compareTo(
        a.totalDamageReceived,
      ),
      EncounterSort.duration => b.durationSeconds.compareTo(a.durationSeconds),
    };
  }

  Widget _buildEncounterList(
    BuildContext context,
    List<ParsedCombatEncounter> encounters,
    Map<String, CombatAarStatus> aarStatuses,
  ) {
    if (_groupMode == EncounterGroupMode.timeline) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: encounters.length,
        itemBuilder: (context, index) =>
            _buildEncounterCard(context, encounters[index], aarStatuses),
      );
    }

    final defeats = encounters
        .where((encounter) => encounter.outcome == CombatOutcome.likelyDefeat)
        .toList();
    final victories = encounters
        .where((encounter) => encounter.outcome == CombatOutcome.likelyVictory)
        .toList();
    final unknown = encounters
        .where((encounter) => encounter.outcome == CombatOutcome.unknown)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (defeats.isNotEmpty)
          _buildSection(context, 'Likely Defeats', defeats, aarStatuses),
        if (victories.isNotEmpty)
          _buildSection(context, 'Likely Victories', victories, aarStatuses),
        if (unknown.isNotEmpty)
          _buildSection(context, 'Unknown Outcome', unknown, aarStatuses),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<ParsedCombatEncounter> encounters,
    Map<String, CombatAarStatus> aarStatuses,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ...encounters.map(
          (encounter) => _buildEncounterCard(context, encounter, aarStatuses),
        ),
      ],
    );
  }

  Widget _buildEncounterCard(
    BuildContext context,
    ParsedCombatEncounter encounter,
    Map<String, CombatAarStatus> aarStatuses,
  ) {
    final color = _outcomeColor(encounter.outcome);
    final aarStatus = aarStatuses[encounter.id] ?? CombatAarStatus.none;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withAlpha(70), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Log.i('COMBAT.UI', 'User opened combat analysis ${encounter.id}');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AnalysisMultiPaneScreen(encounter: encounter),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(35),
                  shape: BoxShape.circle,
                ),
                child: Icon(_outcomeIcon(encounter.outcome), color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_formatAarDateUtc(encounter.startTime)} ${encounter.characterName} - AAR',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _AarStatusBadge(status: aarStatus),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _MetaText(encounter.outcomeLabel),
                        _MetaText(_formatDateTime(encounter.startTime)),
                        _MetaText('${encounter.durationSeconds}s'),
                        _MetaText('Dealt ${encounter.totalDamageDealt}'),
                        _MetaText('Taken ${encounter.totalDamageReceived}'),
                        _MetaText(
                          'Target ${encounter.aggregates.primaryTarget}',
                        ),
                        _MetaText(
                          'Weapon ${encounter.aggregates.primaryWeapon}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Color _outcomeColor(CombatOutcome outcome) {
    return switch (outcome) {
      CombatOutcome.likelyVictory => Colors.greenAccent,
      CombatOutcome.likelyDefeat => Colors.redAccent,
      CombatOutcome.unknown => Colors.amberAccent,
    };
  }

  IconData _outcomeIcon(CombatOutcome outcome) {
    return switch (outcome) {
      CombatOutcome.likelyVictory => Icons.emoji_events,
      CombatOutcome.likelyDefeat => Icons.warning_amber,
      CombatOutcome.unknown => Icons.help_outline,
    };
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
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

  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const DeviceAuthDialog(),
    );
  }

  Future<void> _chooseLogDirectory(BuildContext context, WidgetRef ref) async {
    Log.i('COMBAT.UI', 'User opened combat log directory picker');
    try {
      final scanner = await ref.read(logScannerProvider.future);
      final selectedPath = await scanner.promptUserForDirectory();
      if (!context.mounted) return;

      if (selectedPath == null) {
        Log.i('COMBAT.UI', 'User canceled combat log directory picker');
        return;
      }

      Log.i('COMBAT.UI', 'Combat log directory updated');
      ref.invalidate(logScannerProvider);
      final encounters = await ref.refresh(rawEncountersProvider.future);
      Log.i(
        'COMBAT.UI',
        'Combat log directory refresh completed with ${encounters.length} encounters',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Combat log directory updated. Loaded ${encounters.length} encounters.',
          ),
        ),
      );
    } catch (e, stack) {
      Log.e('COMBAT.UI', 'Failed to select combat log directory', e, stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open log directory picker: $e')),
        );
      }
    }
  }
}

class _AarStatusBadge extends StatelessWidget {
  const _AarStatusBadge({required this.status});

  final CombatAarStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      CombatAarStatus.ready => (
        'AAR Ready',
        Icons.fact_check,
        Colors.greenAccent,
      ),
      CombatAarStatus.legacy => (
        'Legacy AAR',
        Icons.history,
        Colors.amberAccent,
      ),
      CombatAarStatus.none => ('Needs AAR', Icons.auto_awesome, Colors.white54),
    };
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12),
    );
  }
}
