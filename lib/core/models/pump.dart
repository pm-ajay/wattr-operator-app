import 'calibration_settings.dart';
import 'discharge_reading.dart';
import 'electrical_reading.dart';
import 'pump_status.dart';
import 'scheduled_run_progress.dart';
import 'threshold_settings.dart';

class Pump {
  const Pump({
    required this.id,
    required this.imei,
    required this.name,
    required this.sectorId,
    required this.sectorName,
    required this.operatorId,
    required this.operatorName,
    required this.status,
    required this.stateSince,
    required this.lastUpdate,
    required this.electricityAvailable,
    required this.voltageReadings,
    required this.currentReadings,
    required this.thresholds,
    required this.voltageHistory,
    required this.currentHistory,
    required this.dischargeLps,
    required this.calibration,
    this.recentAlert,
    this.isStale = false,
    this.activeScheduledRun,
    this.lastDischargeReading,
  });

  final String id;
  final String imei;
  final String name;
  final String sectorId;
  final String sectorName;

  /// The Operator this pump is mapped to (Tenant → JE → Operator → Pump
  /// hierarchy). Shown on the dashboard row only when viewing as a JE.
  final String operatorId;
  final String operatorName;

  final PumpStatus status;

  /// When the pump entered its current status — the basis for "Running for
  /// 2h 14m" / "Off for 1h 03m" style captions.
  final DateTime stateSince;
  final DateTime lastUpdate;
  final bool electricityAvailable;
  final List<PhaseReading> voltageReadings;
  final List<PhaseReading> currentReadings;
  final ThresholdSettings thresholds;

  /// Recent voltage samples (avg across phases) for the detail sparkline.
  final List<double> voltageHistory;
  final List<double> currentHistory;

  /// Water discharge rate while running, in liters per second — the basis
  /// for the Water Volume Calculator on the Schedules screen. Kept in sync
  /// with [lastDischargeReading] whenever a technician records a new one.
  final double dischargeLps;

  /// Sensor calibration set points and CT scaling, configured by a
  /// technician from the Verify Installation page.
  final CalibrationSettings calibration;

  /// e.g. "Overvoltage detected 10 min ago" — null if nothing recent.
  final String? recentAlert;

  final bool isStale;

  /// Live progress of an in-flight scheduled run, if one is currently running.
  final ScheduledRunProgress? activeScheduledRun;

  /// Most recent flow-meter reading a technician recorded on-site, if any.
  final DischargeReading? lastDischargeReading;

  String get maskedImei => '•' * (imei.length - 5) + imei.substring(imei.length - 5);

  String get displayLabel => '$name, $sectorName';

  Pump copyWith({
    PumpStatus? status,
    DateTime? stateSince,
    ThresholdSettings? thresholds,
    bool? isStale,
    CalibrationSettings? calibration,
    double? dischargeLps,
    DischargeReading? lastDischargeReading,
  }) {
    return Pump(
      id: id,
      imei: imei,
      name: name,
      sectorId: sectorId,
      sectorName: sectorName,
      operatorId: operatorId,
      operatorName: operatorName,
      status: status ?? this.status,
      stateSince: stateSince ?? this.stateSince,
      lastUpdate: lastUpdate,
      electricityAvailable: electricityAvailable,
      voltageReadings: voltageReadings,
      currentReadings: currentReadings,
      thresholds: thresholds ?? this.thresholds,
      voltageHistory: voltageHistory,
      currentHistory: currentHistory,
      dischargeLps: dischargeLps ?? this.dischargeLps,
      calibration: calibration ?? this.calibration,
      recentAlert: recentAlert,
      isStale: isStale ?? this.isStale,
      activeScheduledRun: activeScheduledRun,
      lastDischargeReading: lastDischargeReading ?? this.lastDischargeReading,
    );
  }
}
