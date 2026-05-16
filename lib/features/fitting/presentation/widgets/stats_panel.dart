import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import '../fitting_providers.dart';

class StatsPanel extends ConsumerWidget {
  const StatsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(fittingStatsProvider);
    final fitting = ref.watch(activeFittingProvider);

    if (fitting == null) {
      return const Center(
        child: Text(
          'No ship selected',
          style: TextStyle(color: EveColors.textSecondary, fontSize: 12),
        ),
      );
    }

    return statsAsync.when(
      data: (stats) {
        if (stats == null) {
          return const Center(
            child: Text('Calculating...', style: TextStyle(color: EveColors.textSecondary, fontSize: 12)),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildSectionHeader('DEFENSE'),
            _buildStatRow('EHP', '${stats.defenses.totalEhp.toStringAsFixed(0)}'),
            _buildStatRow('Shield', '${stats.defenses.shieldHp.toStringAsFixed(0)} HP'),
            _buildStatRow('Armor', '${stats.defenses.armorHp.toStringAsFixed(0)} HP'),
            _buildStatRow('Hull', '${stats.defenses.hullHp.toStringAsFixed(0)} HP'),

            const SizedBox(height: 16),
            _buildSectionHeader('CAPACITOR'),
            _buildStatRow('Capacity', '${stats.capacitorCapacity.toStringAsFixed(0)} GJ'),
            _buildStatRow('Recharge', '${(stats.capacitorRecharge / 1000).toStringAsFixed(1)} s'),
            _buildStatRow('Stable', stats.isCapStable ? 'Yes' : '${stats.capacitorStable.toStringAsFixed(0)}s'),

            const SizedBox(height: 16),
            _buildSectionHeader('NAVIGATION'),
            _buildStatRow('Max Speed', '${stats.maxVelocity.toStringAsFixed(0)} m/s'),
            _buildStatRow('Align', '${stats.alignTime.toStringAsFixed(1)} s'),
            _buildStatRow('Warp', '${stats.warpSpeed.toStringAsFixed(1)} AU/s'),

            const SizedBox(height: 16),
            _buildSectionHeader('TARGETING'),
            _buildStatRow('Range', '${(stats.targetRange / 1000).toStringAsFixed(1)} km'),
            _buildStatRow('Scan Res', '${stats.scanResolution.toStringAsFixed(0)} mm'),
            _buildStatRow('Sig Radius', '${stats.signatureRadius.toStringAsFixed(0)} m'),
            _buildStatRow('Max Targets', '${stats.maxLockedTargets}'),

            if (stats.dpsTotal > 0) ...[
              const SizedBox(height: 16),
              _buildSectionHeader('OFFENSE'),
              _buildStatRow('DPS', '${stats.dpsTotal.toStringAsFixed(1)}'),
              _buildStatRow('Volley', '${stats.volley.toStringAsFixed(0)}'),
              if (stats.optimalRange > 0)
                _buildStatRow('Optimal', '${(stats.optimalRange / 1000).toStringAsFixed(1)} km'),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: const TextStyle(color: EveColors.error, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: EveColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: EveColors.textSecondary,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: EveColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
