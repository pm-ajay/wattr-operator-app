import 'package:flutter/material.dart';

import '../../core/models/electrical_reading.dart';
import '../../core/theme/status_colors.dart';

/// Visual min/max range indicator so operators can tell "normal" vs
/// "near limit" vs "out of range" without reading raw numbers.
class ThresholdBar extends StatelessWidget {
  const ThresholdBar({super.key, required this.reading, required this.unit});

  final PhaseReading reading;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = reading.isOutOfRange
        ? StatusColors.crit
        : reading.isNearLimit
            ? StatusColors.warn
            : StatusColors.good;
    final clampedFraction = reading.fraction.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Phase ${reading.phase.label}', style: theme.textTheme.labelMedium),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reading.isOutOfRange)
                  Icon(Icons.warning_amber_rounded, size: 14, color: color)
                else if (reading.isNearLimit)
                  Icon(Icons.trending_up, size: 14, color: color),
                if (reading.isOutOfRange || reading.isNearLimit) const SizedBox(width: 3),
                Text(
                  '${reading.value.toStringAsFixed(1)} $unit',
                  style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(child: Container(color: theme.colorScheme.surfaceContainerHighest)),
                  ],
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: FractionallySizedBox(
                widthFactor: reading.isOutOfRange ? 1.0 : (clampedFraction == 0 ? 0.02 : clampedFraction),
                child: SizedBox(height: 8, child: Container(color: color)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Min ${reading.min.toStringAsFixed(0)}', style: theme.textTheme.labelSmall),
            Text('Max ${reading.max.toStringAsFixed(0)}', style: theme.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}
