import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/schedule_limits.dart';
import '../models/app_language.dart';
import '../models/app_theme_mode.dart';
import '../models/notification_item.dart';
import '../models/operator.dart' as domain;
import '../models/pump.dart';
import '../models/pump_mode.dart';
import '../models/pump_status.dart';
import '../models/running_session.dart';
import '../models/schedule.dart';
import '../models/threshold_settings.dart';
import '../models/user_role.dart';
import 'dummy_data_generator.dart';

final _appDataProvider = Provider<DummyAppData>((ref) => generateDummyAppData());

final operatorsProvider = Provider<List<domain.Operator>>((ref) => ref.watch(_appDataProvider).operators);

/// Which persona this UI-only build is currently previewing as — stands in
/// for a real login, which would auto-scope to exactly one Tenant/role.
class Session {
  const Session({required this.role, required this.operatorId});

  final UserRole role;

  /// The Operator currently being previewed; ignored (but retained) when
  /// role is JE, since a JE sees every Operator's pumps combined.
  final String operatorId;
}

final sessionProvider = NotifierProvider<SessionNotifier, Session>(SessionNotifier.new);

class SessionNotifier extends Notifier<Session> {
  @override
  Session build() {
    final operators = ref.watch(operatorsProvider);
    return Session(role: UserRole.operator, operatorId: operators.first.id);
  }

  void viewAsOperator(String operatorId) => state = Session(role: UserRole.operator, operatorId: operatorId);

  void viewAsJE() => state = Session(role: UserRole.je, operatorId: state.operatorId);
}

final runningSessionsProvider = Provider<Map<String, List<RunningSession>>>(
  (ref) => ref.watch(_appDataProvider).runningSessions,
);

final pumpsProvider = NotifierProvider<PumpsNotifier, List<Pump>>(PumpsNotifier.new);

class PumpsNotifier extends Notifier<List<Pump>> {
  @override
  List<Pump> build() => ref.watch(_appDataProvider).pumps;

  Pump pumpById(String id) => state.firstWhere((p) => p.id == id);

  void setOn(String id) => _updateStatus(id, PumpStatus.on);

  void setOff(String id) => _updateStatus(id, PumpStatus.offRemote);

  void _updateStatus(String id, PumpStatus status) {
    state = [
      for (final pump in state)
        if (pump.id == id) pump.copyWith(status: status, stateSince: DateTime.now()) else pump,
    ];
  }

  void updateThresholds(String id, ThresholdSettings thresholds) {
    state = [
      for (final pump in state)
        if (pump.id == id) pump.copyWith(thresholds: thresholds) else pump,
    ];
  }
}

final schedulesProvider = NotifierProvider<SchedulesNotifier, Map<String, List<Schedule>>>(
  SchedulesNotifier.new,
);

class SchedulesNotifier extends Notifier<Map<String, List<Schedule>>> {
  @override
  Map<String, List<Schedule>> build() => {...ref.watch(_appDataProvider).schedulesByPump};

  List<Schedule> forPump(String pumpId) => state[pumpId] ?? const [];

  /// Returns the first existing active schedule (other than [excludingId])
  /// for the same pump that conflicts with [candidate] — either overlapping
  /// it outright, or falling within the minimum required gap of it — or
  /// null if none conflict. Overlaps are checked first since they're the
  /// stricter violation.
  ({Schedule schedule, bool isGapViolation})? findConflict(Schedule candidate, {String? excludingId}) {
    final existing = forPump(candidate.pumpId).where((s) => s.active && s.id != excludingId);
    for (final s in existing) {
      if (s.overlapsWith(candidate)) return (schedule: s, isGapViolation: false);
    }
    for (final s in existing) {
      if (s.violatesMinGapWith(candidate, scheduleMinGapMinutes)) return (schedule: s, isGapViolation: true);
    }
    return null;
  }

  void addSchedule(Schedule schedule) {
    final list = forPump(schedule.pumpId);
    state = {...state, schedule.pumpId: [...list, schedule]};
  }

  void updateSchedule(Schedule updated) {
    final list = forPump(updated.pumpId);
    state = {
      ...state,
      updated.pumpId: [for (final s in list) if (s.id == updated.id) updated else s],
    };
  }

  void deleteSchedule(String pumpId, String scheduleId) {
    final list = forPump(pumpId);
    state = {
      ...state,
      pumpId: list.where((s) => s.id != scheduleId).toList(),
    };
  }

  void setActive(String pumpId, String scheduleId, bool active) {
    final list = forPump(pumpId);
    state = {
      ...state,
      pumpId: [for (final s in list) if (s.id == scheduleId) s.copyWith(active: active) else s],
    };
  }
}

final masterSchedulePauseProvider = NotifierProvider<MasterSchedulePauseNotifier, Map<String, bool>>(
  MasterSchedulePauseNotifier.new,
);

class MasterSchedulePauseNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {};

  bool isPaused(String pumpId) => state[pumpId] ?? false;

  void setPaused(String pumpId, bool paused) => state = {...state, pumpId: paused};
}

/// The governing control mode for a pump, per the Auto > Scheduling > Manual
/// hierarchy in PRD §4.6 — kept as one source of truth so Pump Detail,
/// Settings, and the Schedules screen all agree on it.
final pumpModeProvider = Provider.family<PumpMode, String>((ref, pumpId) {
  final pumps = ref.watch(pumpsProvider);
  final matches = pumps.where((p) => p.id == pumpId);
  final autoModeEnabled = matches.isEmpty ? false : matches.first.thresholds.autoModeEnabled;
  final schedules = ref.watch(schedulesProvider)[pumpId] ?? const [];
  final masterPaused = ref.watch(masterSchedulePauseProvider)[pumpId] ?? false;
  final hasActiveSchedule = !masterPaused && schedules.any((s) => s.active);
  return computePumpMode(autoModeEnabled: autoModeEnabled, hasActiveSchedule: hasActiveSchedule);
});

final notificationsProvider = NotifierProvider<NotificationsNotifier, List<NotificationItem>>(
  NotificationsNotifier.new,
);

class NotificationsNotifier extends Notifier<List<NotificationItem>> {
  @override
  List<NotificationItem> build() => ref.watch(_appDataProvider).notifications;

  void markAllRead() {
    state = [for (final n in state) n.copyWith(read: true)];
  }
}

final notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesNotifier, Map<NotificationType, bool>>(
  NotificationPreferencesNotifier.new,
);

class NotificationPreferencesNotifier extends Notifier<Map<NotificationType, bool>> {
  @override
  Map<NotificationType, bool> build() => {for (final t in NotificationType.values) t: true};

  void toggle(NotificationType type, bool value) {
    state = {...state, type: value};
  }
}

/// Selection only — no translation is wired up. This exists so the
/// Localization entry point is in place ahead of actual i18n work.
final preferredLanguageProvider = NotifierProvider<PreferredLanguageNotifier, AppLanguage>(
  PreferredLanguageNotifier.new,
);

class PreferredLanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => AppLanguage.english;

  void select(AppLanguage language) => state = language;
}

/// Selection only — the app doesn't actually re-theme itself yet. This
/// exists so the entry point is in place ahead of real theming work.
final preferredThemeModeProvider = NotifierProvider<PreferredThemeModeNotifier, AppThemeMode>(
  PreferredThemeModeNotifier.new,
);

class PreferredThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => AppThemeMode.system;

  void select(AppThemeMode mode) => state = mode;
}

/// Demo-only toggle for previewing the offline banner — not driven by any
/// real connectivity check. Flip it from the drawer to see how the app
/// behaves when data can't be trusted as current.
final isOfflineProvider = NotifierProvider<IsOfflineNotifier, bool>(IsOfflineNotifier.new);

class IsOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setOffline(bool value) => state = value;
}
