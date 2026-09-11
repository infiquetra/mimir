import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/eve_type_icon.dart';
import '../../../fitting/domain/models.dart';
import '../../../wallet/data/wallet_providers.dart';
import '../../domain/aar_fit_derivation.dart';
import '../../domain/combat_damage_matchup.dart';
import 'aar_matchup_section.dart';

class AarDerivedStatsPanel extends ConsumerWidget {
  const AarDerivedStatsPanel({
    super.key,
    required this.derivation,
    required this.title,
    this.matchup,
  });

  final AarFitDerivation derivation;
  final String title;
  final CombatDamageMatchup? matchup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d(
      'COMBAT.UI',
      'AarDerivedStatsPanel built for ${derivation.subject.name}',
    );
    final stats = derivation.stats;
    final defenses = stats.defenses;
    final allFive = derivation.skills.basis == AarSkillBasis.allFive;
    final shipName = ref.watch(itemNameProvider(derivation.shipTypeId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EveTypeIcon(typeId: derivation.shipTypeId, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      shipName.when(
                        data: (name) => Text(
                          name,
                          style: const TextStyle(
                            color: EveColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        loading: () => const Text('Loading...'),
                        error: (_, _) => Text('Ship #${derivation.shipTypeId}'),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          color: EveColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: allFive
                        ? EveColors.warning.withValues(alpha: 0.16)
                        : EveColors.surfaceBright,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: allFive
                          ? EveColors.warning
                          : EveColors.borderSubtle,
                    ),
                  ),
                  child: Text(
                    allFive ? 'assumes All V' : 'ESI skills',
                    style: TextStyle(
                      color: allFive
                          ? EveColors.warning
                          : EveColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section('DEFENSE'),
            Text('EHP (omni) ${_formatNumber(defenses.totalEhp.round())}'),
            Text(
              '${_formatNumber(defenses.totalEhp.round())} EHP '
              '(shield ${_formatNumber(defenses.shieldEhp.round())} / '
              'armor ${_formatNumber(defenses.armorEhp.round())} / '
              'hull ${_formatNumber(defenses.hullEhp.round())})',
            ),
            _layerRow('Shield', defenses.shieldHp, defenses.shieldResists),
            _layerRow('Armor', defenses.armorHp, defenses.armorResists),
            _layerRow('Hull', defenses.hullHp, defenses.hullResists),
            Row(
              children: [
                const Text('Tank'),
                const SizedBox(width: 8),
                Tooltip(
                  message: derivation.tank.reasoning,
                  child: Chip(label: Text(derivation.tank.label)),
                ),
              ],
            ),
            if (defenses.effectiveArmorRepair > 0)
              Text(
                'Active armor ${defenses.effectiveArmorRepair.toStringAsFixed(1)} HP/s',
              ),
            if (defenses.effectiveShieldBoost > 0)
              Text(
                'Active shield ${defenses.effectiveShieldBoost.toStringAsFixed(1)} HP/s',
              ),
            if (defenses.effectiveHullRepair > 0)
              Text(
                'Active hull ${defenses.effectiveHullRepair.toStringAsFixed(1)} HP/s',
              ),
            if (defenses.peakShieldRecharge > 0)
              Text(
                'Passive shield ${defenses.peakShieldRecharge.toStringAsFixed(1)} HP/s',
              ),
            Text(
              'armor ${defenses.effectiveArmorRepair.toStringAsFixed(1)} HP/s, '
              'shield ${defenses.effectiveShieldBoost.toStringAsFixed(1)} HP/s, '
              'hull ${defenses.effectiveHullRepair.toStringAsFixed(1)} HP/s; '
              'passive shield ${defenses.peakShieldRecharge.toStringAsFixed(1)} HP/s',
            ),
            const SizedBox(height: 12),
            _section('CAPACITOR'),
            if (stats.capacitorCapacity == 0)
              const Text('—')
            else ...[
              Text('Capacity ${stats.capacitorCapacity.round()} GJ'),
              Text(
                'Recharge ${(stats.capacitorRecharge / 1000).toStringAsFixed(1)} s',
              ),
              Text(
                stats.isCapStable
                    ? 'Stable at ${stats.capacitorStable.round()}%'
                    : 'Empty in ${stats.capacitorStable.round()} s',
              ),
            ],
            const SizedBox(height: 12),
            _section('OFFENSE'),
            Text(
              'DPS ${stats.dpsTotal.toStringAsFixed(1)} '
              '(guns ${stats.dpsGuns.toStringAsFixed(1)} / '
              'missiles ${stats.dpsMissiles.toStringAsFixed(1)} / '
              'drones ${stats.dpsDrones.toStringAsFixed(1)} / '
              'fighters ${stats.dpsFighters.toStringAsFixed(1)}); '
              'volley ${stats.volley.round()}',
            ),
            if (stats.optimalRange > 0)
              Text(
                'Optimal ${(stats.optimalRange / 1000).toStringAsFixed(1)} km',
              ),
            if (stats.falloffRange > 0)
              Text(
                'Falloff ${(stats.falloffRange / 1000).toStringAsFixed(1)} km',
              ),
            const SizedBox(height: 12),
            _section('MOBILITY'),
            Text(
              '${_formatNumber(stats.maxVelocity.round())} m/s; '
              'sig ${stats.signatureRadius.round()} m; '
              'align ${stats.alignTime.toStringAsFixed(1)} s',
            ),
            const SizedBox(height: 12),
            Text(derivation.coverage.describe()),
            for (final limitation in derivation.limitations)
              Text('- $limitation'),
            if (matchup != null) ...[
              const SizedBox(height: 12),
              AarMatchupSection(matchup: matchup!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: EveColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _layerRow(String label, double hp, ResistProfile resists) {
    return Text(
      '$label ${_formatNumber(hp.round())} HP · '
      'EM ${resists.em.toStringAsFixed(1)}% / '
      'Th ${resists.thermal.toStringAsFixed(1)}% / '
      'Kin ${resists.kinetic.toStringAsFixed(1)}% / '
      'Exp ${resists.explosive.toStringAsFixed(1)}%',
    );
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
