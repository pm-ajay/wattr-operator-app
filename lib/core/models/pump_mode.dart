/// The three-way control hierarchy from PRD §4.6: Auto (highest priority,
/// bypasses the IoT device at hardware level) > Scheduling > Manual.
/// Must be represented consistently on Pump Detail, Settings, and Scheduling.
enum PumpMode { auto, scheduled, manual }

extension PumpModeX on PumpMode {
  String get label => switch (this) {
        PumpMode.auto => 'Auto Mode',
        PumpMode.scheduled => 'Scheduled',
        PumpMode.manual => 'Manual',
      };

  String get description => switch (this) {
        PumpMode.auto =>
          'Auto Mode is on — the pump runs automatically based on electricity availability and overrides both manual control and any schedules.',
        PumpMode.scheduled => 'Schedules are active for this pump. Manual control still works alongside them.',
        PumpMode.manual => 'This pump is under direct manual control. No schedules are currently active.',
      };
}

PumpMode computePumpMode({required bool autoModeEnabled, required bool hasActiveSchedule}) {
  if (autoModeEnabled) return PumpMode.auto;
  if (hasActiveSchedule) return PumpMode.scheduled;
  return PumpMode.manual;
}

