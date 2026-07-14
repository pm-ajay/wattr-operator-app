import 'package:flutter/material.dart';

import '../../../core/models/schedule.dart';
import '../../../core/theme/status_colors.dart';

class ScheduleTile extends StatelessWidget {
  const ScheduleTile({
    super.key,
    required this.schedule,
    required this.masterPaused,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  final Schedule schedule;
  final bool masterPaused;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivelyRunning = schedule.active && !masterPaused;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onEdit,
        title: Row(
          children: [
            Expanded(
              child: Text(schedule.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: effectivelyRunning ? StatusColors.goodBg : StatusColors.warnBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                effectivelyRunning ? 'Active' : (masterPaused ? 'Paused' : 'Inactive'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: effectivelyRunning ? StatusColors.good : StatusColors.warn,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${schedule.repeatSummary} · ${schedule.timeRangeLabel}'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: schedule.active, onChanged: masterPaused ? null : onToggleActive),
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
