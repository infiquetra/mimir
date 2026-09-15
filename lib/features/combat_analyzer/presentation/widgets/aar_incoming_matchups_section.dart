import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../wallet/data/wallet_providers.dart';
import '../../data/combat_providers.dart';
import '../../domain/aar_attacker_matchup.dart';
import '../../domain/combat_attacker_correlation.dart';
import '../../domain/parsed_combat_encounter.dart';
import 'aar_attacker_matchup_card.dart';

class AarIncomingMatchupsSection extends ConsumerStatefulWidget {
  const AarIncomingMatchupsSection({super.key, required this.encounter});

  final ParsedCombatEncounter encounter;

  @override
  ConsumerState<AarIncomingMatchupsSection> createState() =>
      _AarIncomingMatchupsSectionState();
}

class _AarIncomingMatchupsSectionState
    extends ConsumerState<AarIncomingMatchupsSection> {
  String? _encounterId;
  final Set<String> _expanded = {};
  final Set<String> _userTouched = {};
  bool _openedDefault = false;
  bool _aggregateExpanded = false;

  @override
  Widget build(BuildContext context) {
    Log.d(
      'COMBAT.UI',
      'AarIncomingMatchupsSection built for ${widget.encounter.id}',
    );
    final state = ref.watch(aarIncomingMatchupsProvider(widget.encounter));
    final child = _body(state);
    if (state.allocationStatus != AarIncomingDependencyStatus.ready) {
      return child;
    }
    return ListView(shrinkWrap: true, children: [child]);
  }

  Widget _body(AarIncomingMatchupState state) {
    final id = widget.encounter.id;
    if (state.allocationStatus == AarIncomingDependencyStatus.loading) {
      return Card(
        key: Key('aar-incoming-$id-loading'),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assessing incoming damage…'),
              SizedBox(height: 8),
              LinearProgressIndicator(),
            ],
          ),
        ),
      );
    }
    if (state.allocationStatus == AarIncomingDependencyStatus.invalid) {
      return Card(
        key: Key('aar-incoming-$id-invalid'),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Incoming totals are inconsistent'),
        ),
      );
    }
    if (state.allocationStatus == AarIncomingDependencyStatus.error) {
      return Card(
        key: Key('aar-incoming-$id-error'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Incoming profile unavailable'),
              TextButton(
                key: Key('aar-incoming-$id-retry'),
                onPressed: _retry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final notices = <Widget>[
      if (state.correlationStatus == AarIncomingDependencyStatus.unavailable ||
          state.correlationStatus == AarIncomingDependencyStatus.error)
        const Text('Attribution unavailable'),
      if (state.defenseStatus == AarIncomingDependencyStatus.unavailable ||
          state.defenseStatus == AarIncomingDependencyStatus.error)
        const Text('Pilot defense unavailable'),
    ];

    final bundle = state.bundle;
    final total =
        bundle?.allocation.totalIncomingDamage ??
        widget.encounter.totalDamageReceived;
    if (bundle == null || total <= 0) {
      if (notices.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: notices,
        );
      }
      return Card(
        key: Key('aar-incoming-$id-empty'),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('No incoming damage'),
        ),
      );
    }

    final attackers = _sortedAttackers(bundle);
    _syncExpansion(attackers, bundle.encounterId);
    final positiveSources = bundle.allocation.sources
        .where((source) => source.loggedDamage > 0)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...notices,
        _overview(bundle),
        const SizedBox(height: 8),
        _aggregate(bundle, positiveSources),
        const SizedBox(height: 8),
        for (final attacker in attackers) ...[
          AarAttackerMatchupCard(
            matchup: attacker,
            encounterId: bundle.encounterId,
            expanded: _expanded.contains(attacker.source.allocation.sourceId),
            onToggle: () => _toggle(attacker.source.allocation.sourceId),
            totalIncomingDamage: bundle.allocation.totalIncomingDamage,
          ),
          const SizedBox(height: 8),
        ],
        if (bundle.unattributed.isNotEmpty) ...[
          _residualGroup(
            key: Key('aar-incoming-$id-unattributed'),
            title: 'Unattributed (X)',
            sources: bundle.unattributed,
            total: bundle.allocation.totalIncomingDamage,
            possible: true,
          ),
          const SizedBox(height: 8),
        ],
        if (bundle.npc.isNotEmpty) ...[
          _residualGroup(
            key: Key('aar-incoming-$id-npc'),
            title: 'NPC (N)',
            sources: bundle.npc,
            total: bundle.allocation.totalIncomingDamage,
            possible: false,
          ),
          const SizedBox(height: 8),
        ],
        if (bundle.notObserved.isNotEmpty) _notObserved(bundle),
      ],
    );
  }

  Widget _overview(AarIncomingMatchupBundle bundle) {
    final allocation = bundle.allocation;
    final t = allocation.totalIncomingDamage;
    final k = allocation.resolvedDamage;
    final u = allocation.untypedDamage;
    final attributed = bundle.attackers.fold<int>(
      0,
      (sum, row) => sum + row.source.allocation.loggedDamage,
    );
    final x = bundle.unattributed.fold<int>(
      0,
      (sum, row) => sum + row.allocation.loggedDamage,
    );
    final n = bundle.npc.fold<int>(
      0,
      (sum, row) => sum + row.allocation.loggedDamage,
    );
    final coverage = t == 0 ? 0.0 : k / t;
    final attributedShare = t == 0 ? 0.0 : attributed / t;
    return Card(
      key: Key('aar-incoming-${bundle.encounterId}-overview'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Incoming overview',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Text('T ${_formatInt(t)}'),
                Text(
                  'K/T ${_formatInt(k)}/${_formatInt(t)} ${_percent(coverage)}',
                ),
                Text('Attributed ${_percent(attributedShare)}'),
                Text('X ${_formatInt(x)}'),
                Text('N ${_formatInt(n)}'),
                Text('U ${_formatInt(u)} already included'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _aggregate(AarIncomingMatchupBundle bundle, int positiveSources) {
    final showAdvisory = positiveSources > 1;
    return Card(
      key: Key('aar-incoming-${bundle.encounterId}-aggregate-defense'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () =>
                  setState(() => _aggregateExpanded = !_aggregateExpanded),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Aggregate defense (combined sources)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    _aggregateExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ],
              ),
            ),
            if (showAdvisory)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Incoming profile is a blend across $positiveSources attackers; the named resist hole is aggregate, not per attacker.',
                  key: Key('aar-incoming-${bundle.encounterId}-blend-advisory'),
                  style: const TextStyle(color: EveColors.warning),
                ),
              ),
            if (bundle.aggregateDefense.ehp != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'EHP ${_formatInt(bundle.aggregateDefense.ehp!.total.round())}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _residualGroup({
    required Key key,
    required String title,
    required List<AarIncomingSource> sources,
    required int total,
    required bool possible,
  }) {
    final amount = sources.fold<int>(
      0,
      (sum, row) => sum + row.allocation.loggedDamage,
    );
    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${_formatInt(amount)} logged'),
            for (final source in sources) ...[
              const SizedBox(height: 6),
              Text(source.allocation.rawActorName),
              Text(_formatInt(source.allocation.loggedDamage)),
              if (source.allocation.resolvedDamage > 0)
                Text(
                  '${_formatInt(source.allocation.resolvedDamage)}/'
                  '${_formatInt(source.allocation.loggedDamage)} resolved',
                ),
              if (possible &&
                  source.identity?.confidence ==
                      AttackerCorrelationConfidence.possible)
                Text('Possible match to ${_possibleName(source.identity!)}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _notObserved(AarIncomingMatchupBundle bundle) {
    return Card(
      key: Key('aar-incoming-${bundle.encounterId}-not-observed'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Not observed in this log',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            for (final participant in bundle.notObserved)
              _notObservedRow(participant),
          ],
        ),
      ),
    );
  }

  Widget _notObservedRow(CombatKillmailParticipant participant) {
    final name = (participant.characterName?.trim().isNotEmpty ?? false)
        ? participant.characterName!
        : 'Character name unavailable';
    final typeId = participant.shipTypeId;
    if (typeId == null) {
      return Text(name);
    }
    final ship = ref.watch(itemNameProvider(typeId));
    return ship.when(
      data: (value) => Text(
        '$name · ${value.trim().isEmpty || value.contains('Type #') ? 'Unknown ship' : value}',
      ),
      loading: () => Text('$name · Loading…'),
      error: (_, _) => Text('$name · Unknown ship'),
    );
  }

  String _possibleName(CorrelatedAttacker identity) {
    final name = identity.participant.characterName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return identity.actor.displayName;
  }

  List<AarAttackerMatchup> _sortedAttackers(AarIncomingMatchupBundle bundle) {
    final list = [...bundle.attackers];
    list.sort((a, b) {
      final byDamage = b.source.allocation.loggedDamage.compareTo(
        a.source.allocation.loggedDamage,
      );
      if (byDamage != 0) return byDamage;
      final aName =
          a.source.identity?.participant.characterName ??
          a.source.allocation.normalizedActorName;
      final bName =
          b.source.identity?.participant.characterName ??
          b.source.allocation.normalizedActorName;
      final byName = aName.compareTo(bName);
      if (byName != 0) return byName;
      return a.source.allocation.sourceId.compareTo(
        b.source.allocation.sourceId,
      );
    });
    return list;
  }

  void _syncExpansion(List<AarAttackerMatchup> attackers, String encounterId) {
    if (_encounterId != encounterId) {
      _encounterId = encounterId;
      _expanded.clear();
      _userTouched.clear();
      _openedDefault = false;
      _aggregateExpanded = false;
    }
    final eligible = {
      for (final attacker in attackers) attacker.source.allocation.sourceId,
    };
    _expanded.removeWhere((id) => !eligible.contains(id));
    _userTouched.removeWhere((id) => !eligible.contains(id));
    if (!_openedDefault && _userTouched.isEmpty && attackers.isNotEmpty) {
      _expanded.add(attackers.first.source.allocation.sourceId);
      _openedDefault = true;
    }
  }

  void _toggle(String sourceId) {
    setState(() {
      _userTouched.add(sourceId);
      if (!_expanded.add(sourceId)) {
        _expanded.remove(sourceId);
      }
    });
  }

  void _retry() {
    ref.invalidate(aarIncomingMatchupsProvider(widget.encounter));
  }
}

String _formatInt(int value) {
  final sign = value < 0 ? '-' : '';
  final digits = value.abs().toString();
  final buf = StringBuffer(sign);
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

String _percent(double fraction) {
  if (!fraction.isFinite) return '0%';
  return '${(fraction * 100).round()}%';
}
