import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/utils/formatters.dart';

/// 30-day price history chart with average price line and volume bars.
class PriceHistoryChart extends StatelessWidget {
  final List<MarketHistoryEntry> history;

  const PriceHistoryChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No price history available',
            style: TextStyle(color: EveColors.textSecondary),
          ),
        ),
      );
    }

    // Take the last 60 days for the chart
    final data = history.length > 60 ? history.sublist(history.length - 60) : history;

    final prices = data.map((e) => e.average).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;
    final chartMinY = (minPrice - priceRange * 0.1).clamp(0.0, double.infinity);
    final chartMaxY = maxPrice + priceRange * 0.1;

    final maxVolume = data.map((e) => e.volume).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Price chart
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: priceRange > 0 ? priceRange / 4 : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: EveColors.textSecondary.withOpacity(0.1),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: (data.length / 4).ceilToDouble().clamp(1, 30),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('MM/dd').format(data[index].date),
                          style: const TextStyle(
                            color: EveColors.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        _compactIsk(value),
                        style: const TextStyle(
                          color: EveColors.textSecondary,
                          fontSize: 9,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (data.length - 1).toDouble(),
              minY: chartMinY,
              maxY: chartMaxY,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xEE1A2332),
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final entry = data[spot.x.toInt()];
                      return LineTooltipItem(
                        '${DateFormat('MMM dd').format(entry.date)}\n'
                        'Avg: ${formatIsk(entry.average)}\n'
                        'Vol: ${_formatVolume(entry.volume)}',
                        const TextStyle(
                          color: EveColors.textPrimary,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                // High/low range as a filled area
                LineChartBarData(
                  spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.highest)).toList(),
                  isCurved: true,
                  curveSmoothness: 0.2,
                  color: Colors.transparent,
                  barWidth: 0,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
                LineChartBarData(
                  spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.lowest)).toList(),
                  isCurved: true,
                  curveSmoothness: 0.2,
                  color: Colors.transparent,
                  barWidth: 0,
                  dotData: const FlDotData(show: false),
                ),
                // Average price line
                LineChartBarData(
                  spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.average)).toList(),
                  isCurved: true,
                  curveSmoothness: 0.2,
                  color: const Color(0xFF4FC3F7),
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF4FC3F7).withOpacity(0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Volume bars
        SizedBox(
          height: 50,
          child: BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: data.asMap().entries.map((e) {
                final normalizedVol = maxVolume > 0 ? e.value.volume / maxVolume : 0.0;
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: normalizedVol,
                      color: const Color(0xFF4FC3F7).withOpacity(0.3),
                      width: (200 / data.length).clamp(1.0, 6.0),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(1),
                        topRight: Radius.circular(1),
                      ),
                    ),
                  ],
                );
              }).toList(),
              barTouchData: BarTouchData(enabled: false),
            ),
          ),
        ),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 12, height: 2, color: const Color(0xFF4FC3F7)),
            const SizedBox(width: 4),
            const Text('Average Price', style: TextStyle(color: EveColors.textSecondary, fontSize: 10)),
            const SizedBox(width: 16),
            Container(width: 12, height: 8, color: const Color(0xFF4FC3F7).withOpacity(0.3)),
            const SizedBox(width: 4),
            const Text('Volume', style: TextStyle(color: EveColors.textSecondary, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  String _compactIsk(double value) {
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)}B';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  String _formatVolume(int volume) {
    if (volume >= 1e9) return '${(volume / 1e9).toStringAsFixed(1)}B';
    if (volume >= 1e6) return '${(volume / 1e6).toStringAsFixed(1)}M';
    if (volume >= 1e3) return '${(volume / 1e3).toStringAsFixed(1)}K';
    return volume.toString();
  }
}
