import 'package:flutter/material.dart';

import '../models/schedule.dart';

/// Literal/technical schedule-name suggestion built from exactly what the
/// operator picked — no stylized day-pattern words — e.g.
/// "Mon, Wed, Sat 7:00 AM (20 min)" or "Daily 10:00 PM (2 hr)".
/// Returns null when there isn't enough information yet to suggest a name.
String? suggestScheduleName({
  required Set<int> days,
  required TimeOfDay startTime,
  required Duration duration,
}) {
  if (days.isEmpty || duration.inMinutes <= 0) return null;
  final dayLabel = days.length == 7
      ? 'Daily'
      : (days.toList()..sort()).map((d) => Schedule.dayLabels[d]).join(', ');
  final timeLabel = Schedule.formatTime(startTime);
  final durationLabel = formatDurationLabel(duration.inMinutes);
  return '$dayLabel $timeLabel ($durationLabel)';
}

/// "45 min", "1 hr", or "1 hr 30 min".
String formatDurationLabel(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '$minutes min';
  if (minutes == 0) return '$hours hr';
  return '$hours hr $minutes min';
}
