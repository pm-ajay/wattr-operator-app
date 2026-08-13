/// Live progress of a scheduled run currently in-flight on a pump.
/// Set to null on a Pump when no scheduled session is actively running.
class ScheduledRunProgress {
  const ScheduledRunProgress({
    required this.scheduleId,
    required this.scheduleName,
    required this.deliveredMinutes,
    required this.targetMinutes,
    this.stoppedEarlyReason,
  });

  /// Which configured [Schedule] this run belongs to — lets the Schedules
  /// List screen mark the one that's currently executing.
  final String scheduleId;
  final String scheduleName;
  final int deliveredMinutes;
  final int targetMinutes;

  /// Non-null when a safety protection cut this run short — safety always
  /// takes precedence over an active schedule, per PRD §4.6.
  final String? stoppedEarlyReason;

  double get fraction => targetMinutes <= 0 ? 0 : (deliveredMinutes / targetMinutes).clamp(0.0, 1.0);
}
