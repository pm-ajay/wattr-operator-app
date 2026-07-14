import 'package:flutter/material.dart';

import '../../../core/models/scheduled_run_progress.dart';
import '../../../core/theme/status_colors.dart';
import '../../../shared/widgets/section_card.dart';

/// Shown only while a scheduled session is actively running on the pump.
/// If a safety protection cut the run short, that takes visual precedence
/// per PRD §4.6 (safety always overrides an active schedule).
class ScheduledRunCard extends StatelessWidget {
  const ScheduledRunCard({super.key, required this.progress});

  final ScheduledRunProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stoppedEarly = progress.stoppedEarlyReason != null;
    final color = stoppedEarly ? StatusColors.warn : theme.colorScheme.primary;

    return SectionCard(
      title: 'Scheduled Run',
      subtitle: progress.scheduleName,
      children: [
        if (stoppedEarly)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: StatusColors.warnBg, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: StatusColors.warn),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Stopped early — ${progress.stoppedEarlyReason} took precedence over this schedule.',
                    style: const TextStyle(color: StatusColors.warn, fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.fraction,
            minHeight: 10,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${progress.deliveredMinutes}/${progress.targetMinutes} min delivered',
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
