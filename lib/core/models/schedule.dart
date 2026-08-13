import 'package:flutter/material.dart';

/// A single recurring pump run schedule, scoped to one pump/tower.
/// Days use DateTime.weekday numbering: 1=Mon ... 7=Sun.
class Schedule {
  const Schedule({
    required this.id,
    required this.pumpId,
    required this.name,
    required this.repeatDays,
    required this.startTime,
    required this.duration,
    this.active = true,
  });

  final String id;
  final String pumpId;
  final String name;
  final Set<int> repeatDays;
  final TimeOfDay startTime;
  final Duration duration;
  final bool active;

  int get startMinutes => startTime.hour * 60 + startTime.minute;
  int get endMinutes => startMinutes + duration.inMinutes;

  TimeOfDay get endTime {
    final total = endMinutes % (24 * 60);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  static const _dayLabels = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

  String get repeatSummary {
    if (repeatDays.length == 7) return 'Every day';
    if (repeatDays.isEmpty) return 'Never';
    final sorted = repeatDays.toList()..sort();
    return sorted.map((d) => _dayLabels[d]).join(', ');
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  String get timeRangeLabel => '${_formatTime(startTime)} – ${_formatTime(endTime)}';

  /// Whether this schedule's recurring window overlaps another's, ignoring active/paused state.
  bool overlapsWith(Schedule other) {
    if (repeatDays.intersection(other.repeatDays).isEmpty) return false;
    return startMinutes < other.endMinutes && other.startMinutes < endMinutes;
  }

  /// Whether this schedule sits within [minGapMinutes] of [other] on a day
  /// they share, even though the two don't overlap. Only considers the gap
  /// within the same calendar day, not across a midnight boundary.
  bool violatesMinGapWith(Schedule other, int minGapMinutes) {
    if (repeatDays.intersection(other.repeatDays).isEmpty) return false;
    if (overlapsWith(other)) return false;
    final gap = endMinutes <= other.startMinutes
        ? other.startMinutes - endMinutes
        : startMinutes - other.endMinutes;
    return gap < minGapMinutes;
  }

  /// Minutes from [now] until this schedule's next start time, considering
  /// repeat days. Returns null if [repeatDays] is empty.
  int? minutesUntilNext(DateTime now) {
    if (repeatDays.isEmpty) return null;
    final nowMinutes = now.hour * 60 + now.minute;
    for (var offset = 0; offset < 8; offset++) {
      final day = ((now.weekday - 1 + offset) % 7) + 1;
      if (!repeatDays.contains(day)) continue;
      final delta = offset * 24 * 60 + startMinutes - nowMinutes;
      if (offset == 0 && delta <= 0) continue;
      return delta;
    }
    return null;
  }

  Schedule copyWith({
    String? name,
    Set<int>? repeatDays,
    TimeOfDay? startTime,
    Duration? duration,
    bool? active,
  }) {
    return Schedule(
      id: id,
      pumpId: pumpId,
      name: name ?? this.name,
      repeatDays: repeatDays ?? this.repeatDays,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      active: active ?? this.active,
    );
  }
}
