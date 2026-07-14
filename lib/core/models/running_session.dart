enum SessionTrigger { manual, schedule, auto }

extension SessionTriggerX on SessionTrigger {
  String get label => switch (this) {
        SessionTrigger.manual => 'Manual',
        SessionTrigger.schedule => 'Scheduled',
        SessionTrigger.auto => 'Auto Mode',
      };
}

class RunningSession {
  const RunningSession({
    required this.pumpId,
    required this.start,
    required this.end,
    this.trigger = SessionTrigger.manual,
  });

  final String pumpId;
  final DateTime start;
  final DateTime end;
  final SessionTrigger trigger;

  Duration get duration => end.difference(start);

  /// Flags very short cycles that suggest fault-driven on/off cycling
  /// rather than a normal operating session.
  bool get isAbnormallyShort => duration.inMinutes < 3;
}
