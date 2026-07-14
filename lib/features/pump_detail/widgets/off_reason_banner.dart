import 'package:flutter/material.dart';

import '../../../core/models/pump_status.dart';
import '../../../core/theme/status_colors.dart';

class OffReasonBanner extends StatelessWidget {
  const OffReasonBanner({super.key, required this.status});

  final PumpStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severity = status.severity;
    final color = StatusColors.colorFor(severity);
    final bg = StatusColors.bgFor(severity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(status), color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.label, style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(status.shortReason, style: theme.textTheme.bodySmall?.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(PumpStatus status) => switch (status) {
        PumpStatus.on => Icons.check_circle,
        PumpStatus.offRemote => Icons.settings_remote,
        PumpStatus.offBypass => Icons.swap_horiz,
        PumpStatus.offPowerDown => Icons.power_off,
        PumpStatus.faultOvervoltage || PumpStatus.faultUndervoltage => Icons.bolt,
        PumpStatus.faultOverload => Icons.flash_on,
        PumpStatus.faultDryRun => Icons.water_drop_outlined,
        PumpStatus.faultReversePhase => Icons.sync_problem,
      };
}
