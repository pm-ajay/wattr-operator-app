import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dummy_data/providers.dart';
import '../../../core/models/pump.dart';
import '../../../core/models/pump_mode.dart';
import '../../../core/models/pump_status.dart';
import '../../../core/models/user_role.dart';
import '../../../core/utils/format_duration.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/masked_id_text.dart';
import '../../../shared/widgets/pump_status_ring.dart';

class PumpListTile extends ConsumerWidget {
  const PumpListTile({super.key, required this.pump, required this.onTap});

  final Pump pump;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(pumpModeProvider(pump.id));
    final scheduledRun = pump.activeScheduledRun;
    final isJE = ref.watch(sessionProvider.select((s) => s.role)) == UserRole.je;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: () => _handleQuickAction(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PumpStatusRing(
                status: pump.status,
                mode: mode,
                isStale: pump.isStale,
                scheduleProgress: scheduledRun?.fraction,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pump.name,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (isJE) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Operator: ${pump.operatorName}',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      _caption(pump, mode),
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _durationLine(pump),
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    pump.isStale ? 'stale' : timeAgo(pump.lastUpdate),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: pump.isStale ? theme.colorScheme.error : theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  MaskedIdText(fullId: pump.imei, style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _caption(Pump pump, PumpMode mode) {
    if (pump.activeScheduledRun != null) {
      final pct = (pump.activeScheduledRun!.fraction * 100).round();
      return 'On Schedule · $pct%';
    }
    return switch (pump.status.severity) {
      PumpSeverity.running => mode == PumpMode.auto ? 'Running · Auto Mode' : 'Running · Manual',
      PumpSeverity.caution => 'Fault · ${pump.status.shortCause}',
      PumpSeverity.off => 'Off · ${pump.status.shortCause}',
    };
  }

  String _durationLine(Pump pump) {
    final run = pump.activeScheduledRun;
    if (run != null) return '${run.deliveredMinutes} of ${run.targetMinutes} min';

    final elapsed = formatDurationShort(DateTime.now().difference(pump.stateSince));
    return switch (pump.status.severity) {
      PumpSeverity.running => 'Running for $elapsed',
      PumpSeverity.caution => 'Faulted for $elapsed',
      PumpSeverity.off => 'Off for $elapsed',
    };
  }

  Future<void> _handleQuickAction(BuildContext context, WidgetRef ref) async {
    if (ref.read(pumpModeProvider(pump.id)) == PumpMode.auto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual control is overridden while Auto Mode is on.')),
      );
      return;
    }
    final turningOn = !pump.status.isOn;
    final confirmed = await showConfirmDialog(
      context,
      title: turningOn ? 'Turn on pump?' : 'Turn off pump?',
      message: '${turningOn ? 'Turn on' : 'Turn off'} ${pump.displayLabel}?',
      confirmLabel: turningOn ? 'Turn On' : 'Turn Off',
      isDestructive: !turningOn,
    );
    if (!confirmed) return;
    final notifier = ref.read(pumpsProvider.notifier);
    if (turningOn) {
      notifier.setOn(pump.id);
    } else {
      notifier.setOff(pump.id);
    }
  }
}
