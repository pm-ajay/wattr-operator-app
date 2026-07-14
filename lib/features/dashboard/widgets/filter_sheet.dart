import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dummy_data/providers.dart';
import '../../../core/models/user_role.dart';
import '../dashboard_state.dart';

Future<void> showDashboardFilterSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _FilterSheetContent(),
  );
}

class _FilterSheetContent extends ConsumerWidget {
  const _FilterSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(dashboardFiltersProvider);
    final notifier = ref.read(dashboardFiltersProvider.notifier);
    final theme = Theme.of(context);
    final isJE = ref.watch(sessionProvider.select((s) => s.role)) == UserRole.je;
    final operators = ref.watch(operatorsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter by status', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in DashboardStatusFilter.values)
                    ChoiceChip(
                      label: Text(_statusLabel(f)),
                      selected: filters.statusFilter == f,
                      onSelected: (_) => notifier.setStatusFilter(f),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Filter by mode', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in DashboardModeFilter.values)
                    ChoiceChip(
                      label: Text(_modeLabel(f)),
                      selected: filters.modeFilter == f,
                      onSelected: (_) => notifier.setModeFilter(f),
                    ),
                ],
              ),
              if (isJE) ...[
                const SizedBox(height: 20),
                Text('Filter by Operator', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: filters.operatorId == null,
                      onSelected: (_) => notifier.clearOperatorFilter(),
                    ),
                    for (final operator in operators)
                      ChoiceChip(
                        label: Text(operator.name),
                        selected: filters.operatorId == operator.id,
                        onSelected: (_) => notifier.setOperatorFilter(operator.id),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Text('Sort by', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in DashboardSort.values)
                    ChoiceChip(
                      label: Text(s == DashboardSort.recency ? 'Most recent' : 'Name (A-Z)'),
                      selected: filters.sort == s,
                      onSelected: (_) => notifier.setSort(s),
                    ),
                ],
              ),
              if (filters.sectorId != null) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {
                    notifier.clearSectorFilter();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Clear sector filter'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(DashboardStatusFilter f) => switch (f) {
        DashboardStatusFilter.all => 'All',
        DashboardStatusFilter.on => 'On',
        DashboardStatusFilter.off => 'Off',
        DashboardStatusFilter.fault => 'Fault',
      };

  String _modeLabel(DashboardModeFilter f) => switch (f) {
        DashboardModeFilter.all => 'All',
        DashboardModeFilter.manual => 'Manual',
        DashboardModeFilter.schedule => 'Schedule',
        DashboardModeFilter.auto => 'Auto',
      };
}
