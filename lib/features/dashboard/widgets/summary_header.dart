import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/status_colors.dart';
import '../dashboard_state.dart';

/// Tapping a stat applies the matching status filter; tapping the active
/// one again clears back to All. Kept in sync with the filter sheet so
/// either entry point reflects the same state.
class SummaryHeader extends ConsumerWidget {
  const SummaryHeader({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(dashboardFiltersProvider.select((f) => f.statusFilter));
    final notifier = ref.read(dashboardFiltersProvider.notifier);

    void toggle(DashboardStatusFilter filter) {
      notifier.setStatusFilter(activeFilter == filter ? DashboardStatusFilter.all : filter);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              label: 'Total Pumps',
              value: summary.total,
              color: null,
              selected: activeFilter == DashboardStatusFilter.all,
              onTap: () => notifier.setStatusFilter(DashboardStatusFilter.all),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              label: 'On',
              value: summary.on,
              color: StatusColors.good,
              selected: activeFilter == DashboardStatusFilter.on,
              onTap: () => toggle(DashboardStatusFilter.on),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              label: 'Off',
              value: summary.off,
              color: StatusColors.crit,
              selected: activeFilter == DashboardStatusFilter.off,
              onTap: () => toggle(DashboardStatusFilter.off),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              label: 'Fault',
              value: summary.fault,
              color: StatusColors.warn,
              selected: activeFilter == DashboardStatusFilter.fault,
              onTap: () => toggle(DashboardStatusFilter.fault),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? tint.withValues(alpha: 0.14) : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? tint : Colors.transparent, width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                '$value',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color ?? theme.colorScheme.onSurface,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? tint : null,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
