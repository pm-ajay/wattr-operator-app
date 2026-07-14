import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/models/running_session.dart';

class DailyRuntimeChart extends StatelessWidget {
  const DailyRuntimeChart({super.key, required this.sessions, required this.days});

  final List<RunningSession> sessions;
  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final bucketCount = days.clamp(1, 14);
    final hoursPerDay = List<double>.filled(bucketCount, 0);

    for (final s in sessions) {
      final daysAgo = DateTime(now.year, now.month, now.day).difference(
        DateTime(s.start.year, s.start.month, s.start.day),
      ).inDays;
      if (daysAgo >= 0 && daysAgo < bucketCount) {
        hoursPerDay[bucketCount - 1 - daysAgo] += s.duration.inMinutes / 60.0;
      }
    }

    final maxY = (hoursPerDay.isEmpty ? 1.0 : hoursPerDay.reduce((a, b) => a > b ? a : b));

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 4 : maxY * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final daysAgo = bucketCount - 1 - value.toInt();
                  final label = daysAgo == 0 ? 'Today' : '-${daysAgo}d';
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(label, style: theme.textTheme.labelSmall),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < hoursPerDay.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: hoursPerDay[i],
                    color: theme.colorScheme.primary,
                    width: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
