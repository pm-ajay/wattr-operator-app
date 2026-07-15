import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/pump.dart';
import '../../core/models/pump_mode.dart';
import '../../core/models/pump_status.dart';
import '../../core/models/user_role.dart';

enum DashboardStatusFilter { all, on, off, fault }

enum DashboardModeFilter { all, manual, schedule, auto }

enum DashboardSort { recency, name }

class DashboardFilters {
  const DashboardFilters({
    this.query = '',
    this.statusFilter = DashboardStatusFilter.all,
    this.modeFilter = DashboardModeFilter.all,
    this.sort = DashboardSort.recency,
    this.operatorId,
  });

  final String query;
  final DashboardStatusFilter statusFilter;
  final DashboardModeFilter modeFilter;
  final DashboardSort sort;

  /// JE-only: narrow the combined pump list down to one Operator's pumps.
  /// Meaningless (and ignored) while viewing as an Operator, since
  /// [scopedPumpsProvider] already restricts to that Operator.
  final String? operatorId;

  DashboardFilters copyWith({
    String? query,
    DashboardStatusFilter? statusFilter,
    DashboardModeFilter? modeFilter,
    DashboardSort? sort,
    String? Function()? operatorId,
  }) {
    return DashboardFilters(
      query: query ?? this.query,
      statusFilter: statusFilter ?? this.statusFilter,
      modeFilter: modeFilter ?? this.modeFilter,
      sort: sort ?? this.sort,
      operatorId: operatorId != null ? operatorId() : this.operatorId,
    );
  }
}

final dashboardFiltersProvider = NotifierProvider<DashboardFiltersNotifier, DashboardFilters>(
  DashboardFiltersNotifier.new,
);

class DashboardFiltersNotifier extends Notifier<DashboardFilters> {
  @override
  DashboardFilters build() => const DashboardFilters();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setStatusFilter(DashboardStatusFilter filter) => state = state.copyWith(statusFilter: filter);

  void setModeFilter(DashboardModeFilter filter) => state = state.copyWith(modeFilter: filter);

  void setSort(DashboardSort sort) => state = state.copyWith(sort: sort);

  void setOperatorFilter(String? operatorId) => state = state.copyWith(operatorId: () => operatorId);

  void clearOperatorFilter() => state = state.copyWith(operatorId: () => null);
}

/// Pumps visible to the currently-previewed persona: an Operator sees only
/// their own pumps; a JE sees the combined list across every Operator
/// mapped under them.
final scopedPumpsProvider = Provider<List<Pump>>((ref) {
  final pumps = ref.watch(pumpsProvider);
  final session = ref.watch(sessionProvider);
  if (session.role == UserRole.je) return pumps;
  return pumps.where((p) => p.operatorId == session.operatorId).toList();
});

/// The dashboard lists every visible pump directly — there's no sector or
/// location grouping since that mapping doesn't exist for this deployment.
final filteredPumpsProvider = Provider<List<Pump>>((ref) {
  final pumps = ref.watch(scopedPumpsProvider);
  final filters = ref.watch(dashboardFiltersProvider);
  final isJE = ref.watch(sessionProvider.select((s) => s.role)) == UserRole.je;

  var result = pumps.where((p) {
    if (isJE && filters.operatorId != null && p.operatorId != filters.operatorId) return false;
    final matchesStatus = switch (filters.statusFilter) {
      DashboardStatusFilter.all => true,
      DashboardStatusFilter.on => p.status.isOn,
      DashboardStatusFilter.off => !p.status.isOn && !p.status.isFault,
      DashboardStatusFilter.fault => p.status.isFault,
    };
    if (!matchesStatus) return false;

    final mode = ref.watch(pumpModeProvider(p.id));
    final matchesMode = switch (filters.modeFilter) {
      DashboardModeFilter.all => true,
      DashboardModeFilter.manual => mode == PumpMode.manual,
      DashboardModeFilter.schedule => mode == PumpMode.scheduled,
      DashboardModeFilter.auto => mode == PumpMode.auto,
    };
    if (!matchesMode) return false;

    if (filters.query.isEmpty) return true;
    final q = filters.query.toLowerCase();
    return p.name.toLowerCase().contains(q);
  }).toList();

  result.sort((a, b) {
    if (filters.sort == DashboardSort.recency) return b.lastUpdate.compareTo(a.lastUpdate);
    return a.name.compareTo(b.name);
  });

  return result;
});

class DashboardSummary {
  const DashboardSummary({required this.total, required this.on, required this.off, required this.fault});

  final int total;
  final int on;
  final int off;
  final int fault;
}

final dashboardSummaryProvider = Provider<DashboardSummary>((ref) {
  final pumps = ref.watch(scopedPumpsProvider);
  return DashboardSummary(
    total: pumps.length,
    on: pumps.where((p) => p.status.isOn).length,
    fault: pumps.where((p) => p.status.isFault).length,
    off: pumps.where((p) => !p.status.isOn && !p.status.isFault).length,
  );
});
