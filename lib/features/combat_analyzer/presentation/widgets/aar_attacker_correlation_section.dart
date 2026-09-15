import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/eve_type_icon.dart';
import '../../../wallet/data/wallet_providers.dart';
import '../../data/combat_providers.dart';
import '../../domain/combat_attacker_correlation.dart';
import '../../domain/parsed_combat_encounter.dart';

class AarAttackerCorrelationSection extends ConsumerWidget {
  const AarAttackerCorrelationSection({super.key, required this.encounter});

  final ParsedCombatEncounter encounter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d(
      'COMBAT.UI',
      'AarAttackerCorrelationSection built for ${encounter.id}',
    );
    final incomingBySource = encounter.aggregates.incomingBySource;
    final async = ref.watch(combatAttackerCorrelationProvider(encounter));
    return async.when(
      skipLoadingOnReload: true,
      data: (correlation) => AarAttackerCorrelationBody(
        correlation: correlation,
        incomingBySource: incomingBySource,
      ),
      loading: () =>
          const LinearProgressIndicator(key: Key('aar-attackers-loading')),
      error: (error, stack) {
        Log.e('COMBAT.UI', 'Attacker correlation unavailable', error, stack);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Attacker correlation unavailable',
              key: Key('aar-attackers-error'),
            ),
            AarAttackerCorrelationBody(
              correlation: null,
              incomingBySource: incomingBySource,
            ),
          ],
        );
      },
    );
  }
}

class AarAttackerCorrelationBody extends ConsumerStatefulWidget {
  const AarAttackerCorrelationBody({
    super.key,
    required this.correlation,
    required this.incomingBySource,
  });

  final AttackerCorrelation? correlation;
  final Map<String, int> incomingBySource;

  @override
  ConsumerState<AarAttackerCorrelationBody> createState() =>
      _AarAttackerCorrelationBodyState();
}

class _AarAttackerCorrelationBodyState
    extends ConsumerState<AarAttackerCorrelationBody> {
  bool _uncorrelatedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final correlation = widget.correlation;
    Log.d(
      'COMBAT.UI',
      'AarAttackerCorrelationBody built correlation=${correlation != null} '
          'sources=${widget.incomingBySource.length}',
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(correlation),
            if (correlation == null)
              ..._plainActorRows()
            else ...[
              for (final row in correlation.correlated) _correlatedRow(row),
              if (correlation.npcIncomingDamage > 0) _npcBucket(correlation),
              if (correlation.unattributedIncomingDamage > 0)
                _unattributedBucket(correlation),
              if (correlation.uncorrelatedPlayerParticipants.isNotEmpty)
                _uncorrelatedToggle(correlation),
              if (correlation.selfIsVictim && correlation.correlated.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Attacker fits are not exposed by killmails; hulls shown are ship types only.',
                    key: Key('aar-attackers-fits-note'),
                    style: TextStyle(
                      color: EveColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(AttackerCorrelation? correlation) {
    if (correlation == null) {
      return const Text(
        'Incoming Sources',
        style: TextStyle(fontWeight: FontWeight.w600),
      );
    }
    return Row(
      children: [
        const Text('Attackers', style: TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(
          correlation.summaryLine,
          key: const Key('aar-attackers-summary'),
          style: const TextStyle(color: EveColors.textSecondary),
        ),
      ],
    );
  }

  List<Widget> _plainActorRows() {
    return [
      for (final entry in widget.incomingBySource.entries)
        Padding(
          key: Key('aar-actor-row-${normalizeCombatName(entry.key)}'),
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(child: Text(entry.key)),
              Text(_formatNumber(entry.value)),
            ],
          ),
        ),
    ];
  }

  Widget _correlatedRow(CorrelatedAttacker row) {
    final typeId = row.participant.shipTypeId ?? 0;
    return Padding(
      key: Key('aar-attacker-row-${row.participant.key}'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EveTypeIcon(typeId: typeId, size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.actor.displayName),
                _shipName(row.participant.shipTypeId),
                Text(
                  row.signalLabels.join(', '),
                  style: const TextStyle(
                    color: EveColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(_formatNumber(row.actor.damageDealt)),
          const SizedBox(width: 8),
          _badge(row),
        ],
      ),
    );
  }

  Widget _badge(CorrelatedAttacker row) {
    final (icon, color) = switch (row.confidence) {
      AttackerCorrelationConfidence.confirmed => (
        Icons.check_circle,
        EveColors.success,
      ),
      AttackerCorrelationConfidence.probable => (
        Icons.help_outline,
        EveColors.warning,
      ),
      AttackerCorrelationConfidence.possible => (
        Icons.warning_amber,
        EveColors.warning,
      ),
    };
    return Row(
      key: Key('aar-attacker-badge-${row.participant.key}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(row.confidence.label),
      ],
    );
  }

  Widget _npcBucket(AttackerCorrelation correlation) {
    final actors = [
      for (final actor in correlation.unattributedActors)
        if (actor.actorClass == CombatActorClass.npc) actor,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        key: const Key('aar-attackers-npc'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('NPC damage')),
              Text(_formatNumber(correlation.npcIncomingDamage)),
            ],
          ),
          for (final actor in actors)
            Text(
              '${actor.displayName} — ${correlation.reasons['actor:${actor.key}']?.label ?? UncorrelatedReason.npcActor.label}',
              style: const TextStyle(
                color: EveColors.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _unattributedBucket(AttackerCorrelation correlation) {
    final actors = [
      for (final actor in correlation.unattributedActors)
        if (actor.actorClass != CombatActorClass.npc) actor,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        key: const Key('aar-attackers-unattributed'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Unattributed')),
              Text(_formatNumber(correlation.unattributedIncomingDamage)),
            ],
          ),
          for (final actor in actors)
            Text(
              '${actor.displayName} — ${correlation.reasons['actor:${actor.key}']?.label ?? UncorrelatedReason.notOnKillmail.label}',
              style: const TextStyle(
                color: EveColors.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _uncorrelatedToggle(AttackerCorrelation correlation) {
    final players = correlation.uncorrelatedPlayerParticipants;
    final n = players.length;
    final label = correlation.selfIsVictim
        ? '$n attacker${n == 1 ? '' : 's'} not present in your combat log'
        : '$n other attacker${n == 1 ? '' : 's'} on this kill';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          key: const Key('aar-attackers-uncorrelated-toggle'),
          onPressed: () {
            setState(() => _uncorrelatedExpanded = !_uncorrelatedExpanded);
          },
          child: Text(label),
        ),
        if (_uncorrelatedExpanded)
          for (final participant in players) _uncorrelatedRow(participant),
      ],
    );
  }

  Widget _uncorrelatedRow(CombatKillmailParticipant participant) {
    final name = _participantName(participant);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(
            Icons.remove_circle_outline,
            color: EveColors.textSecondary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(name), _shipName(participant.shipTypeId)],
            ),
          ),
          if (participant.damageDone != null)
            Text(_formatNumber(participant.damageDone!)),
        ],
      ),
    );
  }

  Widget _shipName(int? typeId) {
    return ref
        .watch(itemNameProvider(typeId ?? 0))
        .when(
          data: (name) => Text(name),
          loading: () => const Text('Loading…'),
          error: (_, _) => Text('Type #$typeId'),
        );
  }

  static String _participantName(CombatKillmailParticipant participant) {
    final characterName = participant.characterName?.trim();
    if (characterName != null && characterName.isNotEmpty) {
      return characterName;
    }
    if (participant.shipTypeId != null) {
      return 'Type #${participant.shipTypeId}';
    }
    return participant.key;
  }

  static String _formatNumber(int n) {
    final sign = n < 0 ? '-' : '';
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$sign$buf';
  }
}
