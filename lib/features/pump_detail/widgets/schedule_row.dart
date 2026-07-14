import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dummy_data/providers.dart';
import '../../../core/models/schedule.dart';
import '../../../shared/widgets/section_card.dart';

/// Preview of the pump's next upcoming scheduled session, with a quick
/// active/inactive toggle and a link into the full Schedules list.
/// Per PRD §4.6, when the pump is in Auto Mode this must visually indicate
/// that schedules are overridden/inactive.
class ScheduleRow extends ConsumerWidget {
  const ScheduleRow({super.key, required this.pumpId, required this.isAutoMode});

  final String pumpId;
  final bool isAutoMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final schedules = ref.watch(schedulesProvider)[pumpId] ?? const [];
    final masterPaused = ref.watch(masterSchedulePauseProvider.select((m) => m[pumpId] ?? false));

    Schedule? next;
    int? nextMinutes;
    if (!isAutoMode) {
      final now = DateTime.now();
      for (final s in schedules.where((s) => s.active)) {
        final minutes = s.minutesUntilNext(now);
        if (minutes == null) continue;
        if (nextMinutes == null || minutes < nextMinutes) {
          nextMinutes = minutes;
          next = s;
        }
      }
    }

    return SectionCard(
      title: 'Schedule',
      trailing: TextButton(
        onPressed: () => context.push('/pump/$pumpId/schedules'),
        child: const Text('View All'),
      ),
      children: [
        if (isAutoMode)
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Overridden by Auto Mode — schedules will not run until Auto Mode is turned off.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          )
        else if (masterPaused)
          Row(
            children: [
              Icon(Icons.pause_circle_outline, size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Expanded(child: Text('All schedules are paused for this pump.', style: theme.textTheme.bodySmall)),
            ],
          )
        else if (next == null)
          Text('No upcoming schedules.', style: theme.textTheme.bodySmall)
        else
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(next.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${next.repeatSummary} · ${next.timeRangeLabel}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Switch(
                value: next.active,
                onChanged: (v) => ref.read(schedulesProvider.notifier).setActive(pumpId, next!.id, v),
              ),
            ],
          ),
      ],
    );
  }
}
