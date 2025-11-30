import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/eve_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../data/dashboard_providers.dart';
import '../dashboard_card.dart';

/// Dashboard card showing wallet balance trends over the last 30 days.
///
/// Displays:
/// - LineChart showing combined balance across all characters over time
/// - Summary statistics: Income, Expenses, Net change
/// - Handles empty data and error states gracefully
///
/// Uses the EVE Online Neocom aesthetic with EveColors.eveSecondary for the line.
class WalletTrendsCard extends ConsumerWidget {
  const WalletTrendsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(walletTrendsProvider);

    return DashboardCard(
      title: 'Wallet Trends (30 Days)',
      icon: Icons.trending_up,
      glowColor: EveColors.eveSecondary,
      isLoading: trendsAsync.isLoading,
      errorMessage: trendsAsync.hasError ? trendsAsync.error.toString() : null,
      onRetry: () {
        ref.invalidate(walletTrendsProvider);
      },
      child: trendsAsync.when(
        data: (trends) => _buildContent(context, trends),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WalletTrendsData trends) {
    // Handle empty data
    if (trends.chartPoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
            ),
            const SizedBox(height: 12),
            Text(
              'No trend data available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(204),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Balance history will appear here over time',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Chart
        SizedBox(
          height: 200,
          child: _buildChart(context, trends),
        ),

        const SizedBox(height: 24),

        // Summary stats
        _buildSummaryStats(context, trends),
      ],
    );
  }

  Widget _buildChart(BuildContext context, WalletTrendsData trends) {
    // Find min/max for Y-axis scaling
    final balances = trends.chartPoints.map((p) => p.balance).toList();
    final minBalance = balances.reduce((a, b) => a < b ? a : b);
    final maxBalance = balances.reduce((a, b) => a > b ? a : b);

    // Add 10% padding to min/max for better visualization
    // Ensure we have a minimum range to avoid division by zero
    var range = maxBalance - minBalance;
    if (range == 0) {
      range = maxBalance * 0.1; // Use 10% of value as range if all points are equal
      if (range == 0) {
        range = 1000000.0; // Fallback to 1M ISK if value is zero
      }
    }
    final paddedMin = (minBalance - range * 0.1).clamp(0.0, double.infinity);
    final paddedMax = maxBalance + range * 0.1;

    // Create spots for line chart
    final spots = trends.chartPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.balance);
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(right: 16, top: 8),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (paddedMax - paddedMin) / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: EveColors.darkSurfaceVariant,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _formatYAxisLabel(value),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                        ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: trends.chartPoints.length > 10
                    ? trends.chartPoints.length / 5
                    : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= trends.chartPoints.length) {
                    return const SizedBox.shrink();
                  }
                  final point = trends.chartPoints[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${point.date.month}/${point.date.day}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                          ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(color: EveColors.darkSurfaceVariant),
              bottom: BorderSide(color: EveColors.darkSurfaceVariant),
            ),
          ),
          minX: 0,
          maxX: (trends.chartPoints.length - 1).toDouble(),
          minY: paddedMin,
          maxY: paddedMax,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: EveColors.eveSecondary,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: EveColors.eveSecondary.withAlpha(26),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final point = trends.chartPoints[spot.x.toInt()];
                  return LineTooltipItem(
                    '${point.date.month}/${point.date.day}\n${formatIskCompact(point.balance)}',
                    Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Colors.white,
                        ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStats(BuildContext context, WalletTrendsData trends) {
    return Row(
      children: [
        Expanded(
          child: _StatItem(
            label: 'Income',
            value: formatIskCompact(trends.income),
            color: EveColors.success,
          ),
        ),
        Expanded(
          child: _StatItem(
            label: 'Expenses',
            value: formatIskCompact(trends.expenses),
            color: EveColors.error,
          ),
        ),
        Expanded(
          child: _StatItem(
            label: 'Net',
            value: formatIskCompact(trends.net),
            color: trends.net >= 0 ? EveColors.success : EveColors.error,
          ),
        ),
      ],
    );
  }

  /// Formats Y-axis labels in compact ISK format.
  String _formatYAxisLabel(double value) {
    final absValue = value.abs();
    final sign = value < 0 ? '-' : '';

    if (absValue >= 1e12) {
      return '$sign${(absValue / 1e12).toStringAsFixed(1)}T';
    } else if (absValue >= 1e9) {
      return '$sign${(absValue / 1e9).toStringAsFixed(1)}B';
    } else if (absValue >= 1e6) {
      return '$sign${(absValue / 1e6).toStringAsFixed(1)}M';
    } else if (absValue >= 1e3) {
      return '$sign${(absValue / 1e3).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}

/// Single summary statistic item.
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }
}
