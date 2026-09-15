import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../domain/combat_damage_matchup.dart';

class AarMatchupSection extends ConsumerWidget {
  const AarMatchupSection({
    super.key,
    required this.matchup,
    this.correlatedAttackerCount = 0,
    this.outgoing = false,
  });

  final CombatDamageMatchup matchup;
  final int correlatedAttackerCount;
  final bool outgoing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d(
      'COMBAT.UI',
      'AarMatchupSection built for ${matchup.targetLabel} '
          'layer=${matchup.layer} outgoing=$outgoing '
          'correlatedAttackerCount=$correlatedAttackerCount',
    );
    final unknown = matchup.entries.isEmpty || matchup.layer == 'unknown';
    if (unknown) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (outgoing)
              Text(
                "Your outgoing damage vs ${matchup.targetLabel}'s defense",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const Text('Resist profile unknown — no fit evidence'),
          ],
        ),
      );
    }

    final incoming = matchup.ehpAgainstPattern?.total.round() ?? 0;
    final omni = matchup.ehpOmni?.total.round() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (outgoing)
            Text(
              "Your outgoing damage vs ${matchup.targetLabel}'s defense",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          if (correlatedAttackerCount >= 2)
            Text(
              'Incoming profile is a blend across $correlatedAttackerCount attackers; the named resist hole is aggregate, not per attacker.',
              key: const Key('aar-matchup-blend-advisory'),
              style: const TextStyle(color: EveColors.warning),
            ),
          Text(
            outgoing
                ? 'EHP vs outgoing ${_formatNumber(incoming)} · omni ${_formatNumber(omni)} · layer ${matchup.layer}'
                : 'EHP vs incoming ${_formatNumber(incoming)} · omni ${_formatNumber(omni)} · layer ${matchup.layer}',
          ),
          for (final entry in matchup.entries)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _rowLabel(entry),
                style: TextStyle(color: _colorFor(entry.assessment)),
              ),
            ),
        ],
      ),
    );
  }

  String _rowLabel(CombatDamageMatchupEntry entry) {
    final resist = entry.resistPercent?.toStringAsFixed(1) ?? '?';
    final applied = entry.appliedPercent == null
        ? ''
        : ' (${(entry.appliedPercent! * 100).toStringAsFixed(1)}% of damage taken)';
    return '${entry.type}  ${(entry.percent * 100).round()}%  vs  $resist%  ${_word(entry.assessment)}$applied';
  }

  Color? _colorFor(DamageMatchupAssessment assessment) {
    return switch (assessment) {
      DamageMatchupAssessment.resistHole => EveColors.error,
      DamageMatchupAssessment.strongResist => EveColors.success,
      DamageMatchupAssessment.unknown => EveColors.textTertiary,
      DamageMatchupAssessment.neutral => null,
    };
  }

  String _word(DamageMatchupAssessment assessment) {
    return switch (assessment) {
      DamageMatchupAssessment.resistHole => 'hole',
      DamageMatchupAssessment.strongResist => 'strong',
      DamageMatchupAssessment.neutral => 'neutral',
      DamageMatchupAssessment.unknown => 'unknown',
    };
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
