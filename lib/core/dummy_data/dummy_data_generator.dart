import 'dart:math';

import 'package:flutter/material.dart' show TimeOfDay;

import '../models/calibration_settings.dart';
import '../models/electrical_reading.dart';
import '../models/notification_item.dart';
import '../models/operator.dart' as domain;
import '../models/pump.dart';
import '../models/pump_status.dart';
import '../models/running_session.dart';
import '../models/schedule.dart';
import '../models/scheduled_run_progress.dart';
import '../models/sector.dart';
import '../models/threshold_settings.dart';

/// Everything the UI needs, generated once per app session so screens
/// stay internally consistent (a faulted pump also has a matching
/// notification, an OFF reason, etc.) without any real backend.
class DummyAppData {
  const DummyAppData({
    required this.sectors,
    required this.pumps,
    required this.runningSessions,
    required this.notifications,
    required this.schedulesByPump,
    required this.operators,
    required this.generatedAt,
  });

  final List<Sector> sectors;
  final List<Pump> pumps;
  final Map<String, List<RunningSession>> runningSessions;
  final List<NotificationItem> notifications;
  final Map<String, List<Schedule>> schedulesByPump;
  final List<domain.Operator> operators;
  final DateTime generatedAt;
}

const _operatorNames = [
  'Priya Sharma',
  'Aman Gill',
  'Ravinder Singh',
  'Simran Kaur',
  'Harpreet Bhatia',
];

const _operatorPhones = [
  '+91 98765 43210',
  '+91 91234 56780',
  '+91 99887 76655',
  '+91 90011 22334',
  '+91 97001 23456',
];

const _scheduleNamePool = [
  'Morning Fill',
  'Evening Top-up',
  'Overnight Recharge',
  'Midday Boost',
  'Peak Demand Fill',
];

const _sectorNames = [
  'Sector 78, MC Mohali',
  'Sector 70, MC Mohali',
  'Sector 68, MC Mohali',
  'Sector 91, MC Mohali',
  'Sector 15, MC Chandigarh',
  'Sector 22, MC Chandigarh',
  'Phase 3B2, MC Mohali',
  'Phase 7, MC Mohali',
  'Zirakpur Zone 1',
  'Zirakpur Zone 2',
  'Kharar Township',
  'Dera Bassi North',
  'Dera Bassi South',
  'Sector 40, MC Chandigarh',
  'Sector 45, MC Chandigarh',
  'Landran Road Zone',
  'Sohana Zone',
  'Balongi Zone',
];

const _faultStatuses = [
  PumpStatus.faultOvervoltage,
  PumpStatus.faultUndervoltage,
  PumpStatus.faultOverload,
  PumpStatus.faultDryRun,
  PumpStatus.faultReversePhase,
];

const _offStatuses = [
  PumpStatus.offRemote,
  PumpStatus.offBypass,
  PumpStatus.offPowerDown,
];

DummyAppData generateDummyAppData({int seed = 42, DateTime? now}) {
  final rnd = Random(seed);
  final referenceNow = now ?? DateTime.now();

  final sectors = [
    for (var i = 0; i < _sectorNames.length; i++) Sector(id: 'sec_$i', name: _sectorNames[i]),
  ];

  final operators = [
    for (var i = 0; i < _operatorNames.length; i++)
      domain.Operator(id: 'op_$i', name: _operatorNames[i], phone: _operatorPhones[i]),
  ];

  final pumps = <Pump>[];
  final sessionsByPump = <String, List<RunningSession>>{};
  final notifications = <NotificationItem>[];
  final schedulesByPump = <String, List<Schedule>>{};

  var pumpCounter = 0;
  for (final sector in sectors) {
    final pumpCountInSector = 5 + rnd.nextInt(3); // 5-7 pumps per sector -> 100+
    for (var t = 1; t <= pumpCountInSector; t++) {
      pumpCounter++;
      final id = 'pump_$pumpCounter';
      final imei = _randomImei(rnd);

      final statusRoll = rnd.nextDouble();
      final PumpStatus status;
      if (statusRoll < 0.62) {
        status = PumpStatus.on;
      } else if (statusRoll < 0.85) {
        status = _offStatuses[rnd.nextInt(_offStatuses.length)];
      } else {
        status = _faultStatuses[rnd.nextInt(_faultStatuses.length)];
      }

      // Most pumps sync within the last few minutes; only a small slice
      // goes stale (connection lost) to demonstrate that state without
      // dominating the dashboard.
      final isStaleRoll = rnd.nextDouble() < 0.08;
      final minutesAgo = isStaleRoll ? 90 + rnd.nextInt(600) : rnd.nextInt(8);
      final lastUpdate = referenceNow.subtract(Duration(minutes: minutesAgo));

      final hp = [3.0, 5.0, 7.5, 10.0, 12.5][rnd.nextInt(5)];
      final supplyVoltage = [SupplyVoltage.v230, SupplyVoltage.v380, SupplyVoltage.v415][rnd.nextInt(3)];
      final phaseType = supplyVoltage == SupplyVoltage.v230 ? PhaseType.single : PhaseType.three;

      final vMin = 180.0 + rnd.nextInt(20);
      final vMax = 250.0 + rnd.nextInt(30);
      final flAmps = ThresholdSettings.estimateFullLoadAmps(hp: hp, voltage: supplyVoltage, phase: phaseType);
      final iMin = flAmps * 0.4;
      final iMax = flAmps * 1.15;

      final thresholds = ThresholdSettings(
        sendIntervalOnSeconds: 30,
        sendIntervalOffSeconds: 300,
        autoDelaySeconds: 10 + rnd.nextInt(20),
        autoMaxDurationMinutes: 60 + rnd.nextInt(120),
        autoModeEnabled: rnd.nextBool(),
        vMin: vMin,
        vMax: vMax,
        phasedownVoltage: vMin + 10,
        phasedownEnabled: true,
        overVoltageEnabled: true,
        underVoltageEnabled: true,
        iMin: iMin,
        iMax: iMax,
        overloadEnabled: true,
        dryRunEnabled: true,
        reversePhaseEnabled: phaseType == PhaseType.three,
        motorHp: hp,
        supplyVoltage: supplyVoltage,
        phaseType: phaseType,
        currentAutoCalculated: true,
      );

      final isFault = status.isFault;
      final voltageReadings = _phaseReadings(
        rnd: rnd,
        min: thresholds.vMin,
        max: thresholds.vMax,
        forceOutOfRange: status == PumpStatus.faultOvervoltage || status == PumpStatus.faultUndervoltage,
        forceAbove: status == PumpStatus.faultOvervoltage,
        active: status == PumpStatus.on || isFault,
      );
      final currentReadings = _phaseReadings(
        rnd: rnd,
        min: thresholds.iMin,
        max: thresholds.iMax,
        forceOutOfRange: status == PumpStatus.faultOverload || status == PumpStatus.faultDryRun,
        forceAbove: status == PumpStatus.faultOverload,
        forceBelow: status == PumpStatus.faultDryRun,
        active: status == PumpStatus.on || isFault,
      );

      final voltageHistory = _history(rnd, thresholds.vMin, thresholds.vMax, thresholds.vMax);
      final currentHistory = _history(rnd, thresholds.iMin, thresholds.iMax, thresholds.iMax);

      String? recentAlert;
      final DateTime stateSince;
      if (isFault) {
        final agoMinutes = 2 + rnd.nextInt(45);
        recentAlert = '${status.label} detected $agoMinutes min ago';
        stateSince = referenceNow.subtract(Duration(minutes: agoMinutes));
      } else if (status == PumpStatus.on) {
        stateSince = referenceNow.subtract(Duration(minutes: 5 + rnd.nextInt(60 * 8)));
      } else {
        stateSince = referenceNow.subtract(Duration(minutes: 10 + rnd.nextInt(60 * 20)));
      }

      final schedules = _generateSchedules(rnd, id);
      schedulesByPump[id] = schedules;
      final hasActiveSchedule = schedules.any((s) => s.active) && !thresholds.autoModeEnabled;

      ScheduledRunProgress? activeScheduledRun;
      if (hasActiveSchedule && rnd.nextDouble() < 0.3) {
        final activeOnes = schedules.where((s) => s.active).toList();
        final chosen = activeOnes[rnd.nextInt(activeOnes.length)];
        final target = chosen.duration.inMinutes;
        if (isFault) {
          activeScheduledRun = ScheduledRunProgress(
            scheduleId: chosen.id,
            scheduleName: chosen.name,
            deliveredMinutes: (target * (0.2 + rnd.nextDouble() * 0.3)).round(),
            targetMinutes: target,
            stoppedEarlyReason: status.label,
          );
        } else if (status == PumpStatus.on) {
          activeScheduledRun = ScheduledRunProgress(
            scheduleId: chosen.id,
            scheduleName: chosen.name,
            deliveredMinutes: (target * rnd.nextDouble()).round().clamp(0, target - 1),
            targetMinutes: target,
          );
        }
      }

      final operator = operators[pumpCounter % operators.length];

      // Rough heuristic for a tubewell pump's discharge rate, loosely
      // scaled off motor HP so bigger motors move more water.
      final dischargeLps = double.parse((hp * (1.0 + rnd.nextDouble() * 0.8)).toStringAsFixed(1));

      final outputCurrentAmps = double.parse(((thresholds.iMin + thresholds.iMax) / 2).toStringAsFixed(2));
      final calibration = CalibrationSettings(
        outputCurrentAmps: outputCurrentAmps,
        currentMultiplier: CalibrationSettings.multiplierFor(outputCurrentAmps),
        voltageSetPoints: {for (final p in Phase.values) p: (thresholds.vMin + thresholds.vMax) / 2},
        currentSetPoints: {for (final p in Phase.values) p: (thresholds.iMin + thresholds.iMax) / 2},
      );

      final pump = Pump(
        id: id,
        imei: imei,
        name: 'Tw $t',
        sectorId: sector.id,
        sectorName: sector.name,
        operatorId: operator.id,
        operatorName: operator.name,
        status: status,
        stateSince: stateSince,
        lastUpdate: lastUpdate,
        electricityAvailable: status != PumpStatus.offPowerDown,
        voltageReadings: voltageReadings,
        currentReadings: currentReadings,
        thresholds: thresholds,
        voltageHistory: voltageHistory,
        currentHistory: currentHistory,
        dischargeLps: dischargeLps,
        calibration: calibration,
        recentAlert: recentAlert,
        isStale: minutesAgo > 30,
        activeScheduledRun: activeScheduledRun,
      );
      pumps.add(pump);

      sessionsByPump[id] = _generateSessions(
        rnd,
        referenceNow,
        pumpId: id,
        includeAbnormal: isFault,
        autoModeEnabled: thresholds.autoModeEnabled,
        hasActiveSchedule: hasActiveSchedule,
      );

      if (isFault || status == PumpStatus.offPowerDown) {
        notifications.add(_notificationFor(pump, referenceNow, rnd));
      }
    }
  }

  notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return DummyAppData(
    sectors: sectors,
    pumps: pumps,
    runningSessions: sessionsByPump,
    notifications: notifications,
    schedulesByPump: schedulesByPump,
    operators: operators,
    generatedAt: referenceNow,
  );
}

List<Schedule> _generateSchedules(Random rnd, String pumpId) {
  final count = rnd.nextInt(4); // 0-3 schedules per pump
  final schedules = <Schedule>[];
  final usedNames = <String>{};

  for (var i = 0; i < count; i++) {
    Schedule? candidate;
    for (var attempt = 0; attempt < 5; attempt++) {
      final startHour = 4 + rnd.nextInt(19);
      final startMinute = [0, 15, 30, 45][rnd.nextInt(4)];
      final durationMinutes = 10 + rnd.nextInt(35);
      final dayPattern = rnd.nextDouble();
      final Set<int> days;
      if (dayPattern < 0.4) {
        days = {1, 2, 3, 4, 5, 6, 7};
      } else if (dayPattern < 0.7) {
        days = {1, 2, 3, 4, 5};
      } else {
        days = {for (var d = 1; d <= 7; d++) if (rnd.nextBool()) d}..add(1 + rnd.nextInt(7));
      }

      final proposed = Schedule(
        id: '${pumpId}_sched_$i',
        pumpId: pumpId,
        name: _scheduleNamePool[rnd.nextInt(_scheduleNamePool.length)],
        repeatDays: days,
        startTime: TimeOfDay(hour: startHour, minute: startMinute),
        duration: Duration(minutes: durationMinutes),
        active: rnd.nextDouble() < 0.8,
      );

      if (usedNames.contains(proposed.name)) continue;
      if (schedules.any((s) => s.overlapsWith(proposed))) continue;
      candidate = proposed;
      break;
    }
    if (candidate != null) {
      schedules.add(candidate);
      usedNames.add(candidate.name);
    }
  }
  return schedules;
}

String _randomImei(Random rnd) {
  final buffer = StringBuffer();
  for (var i = 0; i < 15; i++) {
    buffer.write(rnd.nextInt(10));
  }
  return buffer.toString();
}

List<PhaseReading> _phaseReadings({
  required Random rnd,
  required double min,
  required double max,
  required bool active,
  bool forceOutOfRange = false,
  bool forceAbove = false,
  bool forceBelow = false,
}) {
  final mid = (min + max) / 2;
  return Phase.values.map((phase) {
    double value;
    if (!active) {
      value = 0;
    } else if (forceOutOfRange) {
      if (forceAbove) {
        value = max + (max - min) * (0.05 + rnd.nextDouble() * 0.15);
      } else if (forceBelow) {
        value = min - (max - min) * (0.05 + rnd.nextDouble() * 0.15);
      } else {
        value = rnd.nextBool() ? max + (max - min) * 0.1 : min - (max - min) * 0.1;
      }
    } else {
      // mostly comfortable, occasionally nudged near a limit
      final roll = rnd.nextDouble();
      if (roll < 0.15) {
        value = min + (max - min) * (0.02 + rnd.nextDouble() * 0.06);
      } else if (roll < 0.3) {
        value = max - (max - min) * (0.02 + rnd.nextDouble() * 0.06);
      } else {
        value = mid + (rnd.nextDouble() - 0.5) * (max - min) * 0.3;
      }
    }
    return PhaseReading(phase: phase, value: double.parse(value.toStringAsFixed(1)), min: min, max: max);
  }).toList();
}

List<double> _history(Random rnd, double min, double max, double cap) {
  final mid = (min + max) / 2;
  var current = mid;
  return List.generate(24, (_) {
    current += (rnd.nextDouble() - 0.5) * (max - min) * 0.1;
    current = current.clamp(0, cap * 1.2);
    return double.parse(current.toStringAsFixed(1));
  });
}

List<RunningSession> _generateSessions(
  Random rnd,
  DateTime now, {
  required String pumpId,
  required bool includeAbnormal,
  required bool autoModeEnabled,
  required bool hasActiveSchedule,
}) {
  final sessions = <RunningSession>[];
  for (var d = 0; d < 30; d++) {
    final day = now.subtract(Duration(days: d));
    final sessionsToday = rnd.nextInt(3);
    for (var s = 0; s < sessionsToday; s++) {
      final startHour = 4 + rnd.nextInt(18);
      final start = DateTime(day.year, day.month, day.day, startHour, rnd.nextInt(60));
      final isAbnormal = includeAbnormal && rnd.nextDouble() < 0.25;
      final durationMinutes = isAbnormal ? 1 + rnd.nextInt(2) : 15 + rnd.nextInt(150);
      final SessionTrigger trigger;
      if (autoModeEnabled) {
        trigger = SessionTrigger.auto;
      } else if (hasActiveSchedule && rnd.nextDouble() < 0.5) {
        trigger = SessionTrigger.schedule;
      } else {
        trigger = SessionTrigger.manual;
      }
      sessions.add(
        RunningSession(
          pumpId: pumpId,
          start: start,
          end: start.add(Duration(minutes: durationMinutes)),
          trigger: trigger,
        ),
      );
    }
  }
  sessions.sort((a, b) => b.start.compareTo(a.start));
  return sessions;
}

NotificationItem _notificationFor(Pump pump, DateTime now, Random rnd) {
  final type = switch (pump.status) {
    PumpStatus.faultOvervoltage => NotificationType.overvoltage,
    PumpStatus.faultUndervoltage => NotificationType.undervoltage,
    PumpStatus.faultOverload => NotificationType.overload,
    PumpStatus.faultDryRun => NotificationType.dryRun,
    PumpStatus.faultReversePhase => NotificationType.reversePhase,
    PumpStatus.offPowerDown => NotificationType.powerDown,
    _ => NotificationType.restored,
  };
  return NotificationItem(
    id: 'notif_${pump.id}',
    type: type,
    pumpId: pump.id,
    pumpName: pump.name,
    sectorName: pump.sectorName,
    message: '${type.label} at ${pump.displayLabel}',
    timestamp: pump.lastUpdate,
  );
}
