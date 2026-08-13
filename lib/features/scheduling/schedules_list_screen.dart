import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/pump_mode.dart';
import '../../shared/widgets/confirm_dialog.dart';
import 'schedule_form_sheet.dart';
import 'widgets/schedule_tile.dart';
import 'widgets/water_calculator_sheet.dart';

class SchedulesListScreen extends ConsumerWidget {
  const SchedulesListScreen({super.key, required this.pumpId});

  final String pumpId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pumps = ref.watch(pumpsProvider);
    final matches = pumps.where((p) => p.id == pumpId);
    final pump = matches.isEmpty ? null : matches.first;
    final pumpLabel = pump?.displayLabel ?? '';

    final schedules = ref.watch(schedulesProvider)[pumpId] ?? const [];
    final masterPaused = ref.watch(masterSchedulePauseProvider.select((m) => m[pumpId] ?? false));
    final isAutoMode = ref.watch(pumpModeProvider(pumpId)) == PumpMode.auto;

    return Scaffold(
      appBar: AppBar(
        title: Text('Schedules — $pumpLabel'),
        actions: [
          if (pump != null)
            IconButton(
              icon: const Icon(Icons.calculate_outlined),
              tooltip: 'Water Volume Calculator',
              onPressed: () async {
                final minutes = await showWaterCalculatorSheet(
                  context,
                  pumpLabel: pump.displayLabel,
                  dischargeLps: pump.dischargeLps,
                );
                if (minutes != null && context.mounted) {
                  showScheduleFormSheet(context, pumpId: pumpId, initialDurationMinutes: minutes);
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (isAutoMode)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: theme.colorScheme.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This pump is in Auto Mode, so schedules are overridden and will not run until Auto Mode is turned off in Settings.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pause all schedules'),
              subtitle: const Text('Temporarily stop all schedules for this pump without deleting them.'),
              value: masterPaused,
              onChanged: (v) => ref.read(masterSchedulePauseProvider.notifier).setPaused(pumpId, v),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: schedules.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_outlined, size: 40, color: theme.colorScheme.outline),
                        const SizedBox(height: 12),
                        const Text('No schedules yet for this pump.'),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final schedule in schedules)
                        ScheduleTile(
                          schedule: schedule,
                          masterPaused: masterPaused,
                          onToggleActive: (v) =>
                              ref.read(schedulesProvider.notifier).setActive(pumpId, schedule.id, v),
                          onEdit: () => showScheduleFormSheet(context, pumpId: pumpId, existing: schedule),
                          onDelete: () async {
                            final confirmed = await showConfirmDialog(
                              context,
                              title: 'Delete schedule?',
                              message: 'Delete "${schedule.name}"? This cannot be undone.',
                              confirmLabel: 'Delete',
                              isDestructive: true,
                            );
                            if (confirmed) {
                              ref.read(schedulesProvider.notifier).deleteSchedule(pumpId, schedule.id);
                            }
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showScheduleFormSheet(context, pumpId: pumpId),
        icon: const Icon(Icons.add),
        label: const Text('Add new schedule'),
      ),
    );
  }
}
