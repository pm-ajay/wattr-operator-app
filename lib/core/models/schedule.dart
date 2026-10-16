import 'package:flutter/material.dart';

/// A single recurring pump run schedule, scoped to one pump/tower.
/// Days use DateTime.weekday numbering: 1=Mon ... 7=Sun.
/// Sentinel used by [Schedule.copyWith] to distinguish "leave endTime
/// unchanged" from "explicitly set endTime to null" (clear the hard stop).
class _Unset {
  const _Unset();
}

const _unset = _Unset();

class Schedule {
  const Schedule({
    required this.id,
    required this.pumpId,
    required this.name,
    required this.repeatDays,
    required this.startTime,
    required this.duration,
    this.endTime,
    this.active = true,
  });

  final String id;
  final String pumpId;
  final String name;
  final Set<int> repeatDays;
  final TimeOfDay startTime;
  final Duration duration;

  /// Optional hard-stop cutoff. When set, the pump is forced off at this
  /// exact clock time no matter what — even if the run had to pause and
  /// resume (e.g. a power outage) and hasn't finished [duration] yet. When
  /// null, there's no override: the run is expected to stop at
  /// [naturalEndTime].
  final TimeOfDay? endTime;
  final bool active;

  int get startMinutes => startTime.hour * 60 + startTime.minute;
  int get endMinutes => startMinutes + duration.inMinutes;

  /// When the run finishes if nothing overrides it: start + duration.
  TimeOfDay get naturalEndTime {
    final total = endMinutes % (24 * 60);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  bool get hasHardStop => endTime != null;

  /// [endTime] expressed as day-minutes, wrapping to the next day if it's
  /// earlier in the clock than the start time — same convention [endMinutes]
  /// already uses for overnight schedules.
  int get hardStopMinutes {
    final raw = endTime!.hour * 60 + endTime!.minute;
    return raw < startMinutes ? raw + 24 * 60 : raw;
  }

  /// Whether the hard stop can actually cut a normal run short, i.e. it
  /// lands before the run would otherwise finish.
  bool get isHardStopBeforeNaturalEnd => hasHardStop && hardStopMinutes < endMinutes;

  /// What to show/use as "stops at": the hard stop if set, else the natural
  /// end time.
  TimeOfDay get effectiveEndTime => endTime ?? naturalEndTime;

  static const dayLabels = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

  String get repeatSummary {
    if (repeatDays.length == 7) return 'Every day';
    if (repeatDays.isEmpty) return 'Never';
    final sorted = repeatDays.toList()..sort();
    return sorted.map((d) => dayLabels[d]).join(', ');
  }

  static String formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  String get timeRangeLabel => '${formatTime(startTime)} – ${formatTime(effectiveEndTime)}';

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
    Object? endTime = _unset,
    bool? active,
  }) {
    return Schedule(
      id: id,
      pumpId: pumpId,
      name: name ?? this.name,
      repeatDays: repeatDays ?? this.repeatDays,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      endTime: endTime == _unset ? this.endTime : endTime as TimeOfDay?,
      active: active ?? this.active,
    );
  }
}
