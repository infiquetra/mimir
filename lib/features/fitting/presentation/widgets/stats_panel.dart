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
          style: TextStyle(color: EveColors.textSecondary),
        ),
      );
    }

    return statsAsync.when(
      data: (stats) {
        if (stats == null) {
          return const Center(
            child: Text('Failed to calculate stats'),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('RESOURCES'),
            _buildResourceBar(
              'CPU',
              stats.cpuUsed,
              stats.cpuMax,
              EveColors.photonBlue,
            ),
            const SizedBox(height: 8),
            _buildResourceBar(
              'Powergrid',
              stats.powerUsed,
              stats.powerMax,
              EveColors.minmatar,
            ),
            const SizedBox(height: 8),
            _buildResourceBar(
              'Calibration',
              stats.calibrationUsed.toDouble(),
              stats.calibrationMax.toDouble(),
              Colors.orange,
            ),
            
            const SizedBox(height: 24),
            _buildSectionHeader('DEFENSE'),
            _buildStatRow('Total EHP', '${stats.defenses.totalEhp.toStringAsFixed(0)} EHP'),
            _buildStatRow('Shield HP', '${stats.defenses.shieldHp.toStringAsFixed(0)} HP'),
            _buildStatRow('Armor HP', '${stats.defenses.armorHp.toStringAsFixed(0)} HP'),
            _buildStatRow('Hull HP', '${stats.defenses.hullHp.toStringAsFixed(0)} HP'),

            const SizedBox(height: 24),
            _buildSectionHeader('CAPACITOR'),
            _buildStatRow('Capacity', '${stats.capacitorCapacity.toStringAsFixed(0)} GJ'),
            _buildStatRow('Recharge', '${(stats.capacitorRecharge / 1000).toStringAsFixed(1)} s'),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: const TextStyle(color: EveColors.error),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: EveColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: EveColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: EveColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceBar(String label, double used, double max, Color color) {
    final percent = max > 0 ? (used / max).clamp(0.0, 1.0) : 0.0;
    final isOver = used > max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: EveColors.textSecondary,
                fontSize: 12,
              ),
            ),
            Text(
              '${used.toStringAsFixed(1)} / ${max.toStringAsFixed(1)}',
              style: TextStyle(
                color: isOver ? EveColors.error : EveColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percent,
          backgroundColor: EveColors.surfaceBright,
          valueColor: AlwaysStoppedAnimation<Color>(
            isOver ? EveColors.error : color,
          ),
          minHeight: 6,
        ),
      ],
    );
  }
}
