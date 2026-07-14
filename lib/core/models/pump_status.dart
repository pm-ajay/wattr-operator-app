/// Traffic-light read: green = running, yellow = needs attention, red = off
/// (for any reason — bypass, remote, or power-down all read the same).
enum PumpSeverity { running, caution, off }

enum PumpStatus {
  on,
  offRemote,
  offBypass,
  offPowerDown,
  faultOvervoltage,
  faultUndervoltage,
  faultOverload,
  faultDryRun,
  faultReversePhase,
}

extension PumpStatusX on PumpStatus {
  bool get isOn => this == PumpStatus.on;

  bool get isFault => switch (this) {
        PumpStatus.faultOvervoltage ||
        PumpStatus.faultUndervoltage ||
        PumpStatus.faultOverload ||
        PumpStatus.faultDryRun ||
        PumpStatus.faultReversePhase =>
          true,
        _ => false,
      };

  PumpSeverity get severity {
    if (isFault) return PumpSeverity.caution;
    if (this == PumpStatus.on) return PumpSeverity.running;
    return PumpSeverity.off;
  }

  String get label => switch (this) {
        PumpStatus.on => 'On',
        PumpStatus.offRemote => 'Off by Remote',
        PumpStatus.offBypass => 'Off by Bypass',
        PumpStatus.offPowerDown => 'Off by Power Down',
        PumpStatus.faultOvervoltage => 'Overvoltage Fault',
        PumpStatus.faultUndervoltage => 'Undervoltage Fault',
        PumpStatus.faultOverload => 'Overload Fault',
        PumpStatus.faultDryRun => 'Dry Run Fault',
        PumpStatus.faultReversePhase => 'Reverse Phase Fault',
      };

  String get shortReason => switch (this) {
        PumpStatus.on => 'Running',
        PumpStatus.offRemote => 'Turned off remotely by operator',
        PumpStatus.offBypass => 'Turned off via bypass switch on-site',
        PumpStatus.offPowerDown => 'Electricity supply is down',
        PumpStatus.faultOvervoltage => 'Voltage exceeded the safe maximum',
        PumpStatus.faultUndervoltage => 'Voltage dropped below the safe minimum',
        PumpStatus.faultOverload => 'Current draw exceeded the safe maximum',
        PumpStatus.faultDryRun => 'Pump ran without adequate water flow',
        PumpStatus.faultReversePhase => 'Incoming phase sequence is reversed',
      };

  /// Bare cause word for compact captions, e.g. "Bypass", "Overvoltage".
  String get shortCause => switch (this) {
        PumpStatus.on => 'Running',
        PumpStatus.offRemote => 'Remote',
        PumpStatus.offBypass => 'Bypass',
        PumpStatus.offPowerDown => 'Power Down',
        PumpStatus.faultOvervoltage => 'Overvoltage',
        PumpStatus.faultUndervoltage => 'Undervoltage',
        PumpStatus.faultOverload => 'Overload',
        PumpStatus.faultDryRun => 'Dry Run',
        PumpStatus.faultReversePhase => 'Reverse Phase',
      };
}
