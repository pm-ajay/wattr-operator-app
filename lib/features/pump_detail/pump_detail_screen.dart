import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/pump.dart';
import '../../core/models/pump_mode.dart';
import '../../core/models/pump_status.dart';
import '../../core/models/user_role.dart';
import '../../core/theme/status_colors.dart';
import '../../core/utils/time_ago.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/masked_id_text.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/sparkline.dart';
import '../../shared/widgets/threshold_bar.dart';
import 'widgets/off_reason_banner.dart';
import 'widgets/schedule_row.dart';
import 'widgets/scheduled_run_card.dart';

class PumpDetailScreen extends ConsumerWidget {
  const PumpDetailScreen({super.key, required this.pumpId});

  final String pumpId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pumps = ref.watch(pumpsProvider);
    final matches = pumps.where((p) => p.id == pumpId);
    final pump = matches.isEmpty ? null : matches.first;
    final theme = Theme.of(context);

    if (pump == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Pump not found.')));
    }

    final mode = ref.watch(pumpModeProvider(pumpId));
    final isJE = ref.watch(sessionProvider.select((s) => s.role)) == UserRole.je;

    return Scaffold(
      appBar: AppBar(
        title: Text(pump.displayLabel),
        actions: [
          _StatusIconRow(pump: pump),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          if (pump.isStale)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 18, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last known status — connection lost. Updated ${timeAgo(pump.lastUpdate)}.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          if (pump.recentAlert != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: StatusColors.warnBg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: StatusColors.warn),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pump.recentAlert!,
                      style: const TextStyle(color: StatusColors.warn, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          OffReasonBanner(status: pump.status),
          const SizedBox(height: 12),
          MaskedIdText(fullId: pump.imei),
          const SizedBox(height: 16),
          if (pump.activeScheduledRun != null) ...[
            ScheduledRunCard(progress: pump.activeScheduledRun!),
            const SizedBox(height: 12),
          ],
          SectionCard(
            title: 'Status',
            children: [
              if (isJE) _InfoRow(label: 'Operator', value: pump.operatorName),
              _InfoRow(label: 'Last Update', value: timeAgo(pump.lastUpdate)),
              _InfoRow(
                label: 'Electricity Availability',
                value: pump.electricityAvailable ? 'Available' : 'Not Available',
              ),
              _InfoRow(label: 'Pump Status', value: pump.status.label),
              _InfoRow(label: 'Mode', value: mode.label),
            ],
          ),
          const SizedBox(height: 12),
          ScheduleRow(pumpId: pumpId, isAutoMode: mode == PumpMode.auto),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Voltage Trend',
            subtitle: 'Average across phases, last 24 samples',
            children: [Sparkline(values: pump.voltageHistory, color: theme.colorScheme.primary)],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Voltage Health',
            subtitle: 'Per-phase reading against configured safe range',
            children: [
              for (final reading in pump.voltageReadings) ...[
                ThresholdBar(reading: reading, unit: 'V'),
                const SizedBox(height: 14),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Current Health',
            subtitle: 'Per-phase reading against configured safe range',
            children: [
              for (final reading in pump.currentReadings) ...[
                ThresholdBar(reading: reading, unit: 'A'),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Settings'),
                      onPressed: () => context.push('/pump/$pumpId/settings'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.history),
                      label: const Text('Running Times'),
                      onPressed: () => context.push('/pump/$pumpId/running-times'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (mode == PumpMode.auto)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Manual control is overridden while Auto Mode is on.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: pump.status.isOn ? theme.colorScheme.error : StatusColors.good,
                  ),
                  icon: Icon(pump.status.isOn ? Icons.power_settings_new : Icons.play_arrow),
                  label: Text(pump.status.isOn ? 'Turn Off Pump' : 'Turn On Pump'),
                  onPressed: mode == PumpMode.auto ? null : () => _handleToggle(context, ref, pump.status.isOn),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/wattr-bot', extra: pump.displayLabel),
        tooltip: 'Wattr Bot',
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }

  Future<void> _handleToggle(BuildContext context, WidgetRef ref, bool isOn) async {
    final pump = ref.read(pumpsProvider.notifier).pumpById(pumpId);
    final confirmed = await showConfirmDialog(
      context,
      title: isOn ? 'Turn off pump?' : 'Turn on pump?',
      message: '${isOn ? 'Turn off' : 'Turn on'} pump at ${pump.displayLabel}?',
      confirmLabel: isOn ? 'Turn Off' : 'Turn On',
      isDestructive: isOn,
    );
    if (!confirmed) return;
    final notifier = ref.read(pumpsProvider.notifier);
    if (isOn) {
      notifier.setOff(pumpId);
    } else {
      notifier.setOn(pumpId);
    }
  }
}

/// Independent status badges for the app bar — each appears only when its
/// own condition holds, so a viewer can tell at a glance which of several
/// unrelated things (running, a fault, stale data) apply right now, rather
/// than inferring them all from one combined color.
class _StatusIconRow extends StatelessWidget {
  const _StatusIconRow({required this.pump});

  final Pump pump;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badges = <Widget>[
      if (pump.status.isOn)
        _StatusIcon(icon: Icons.bolt, color: StatusColors.good, tooltip: 'Running'),
      if (pump.recentAlert != null)
        _StatusIcon(icon: Icons.warning_amber_rounded, color: StatusColors.warn, tooltip: pump.recentAlert!),
      if (pump.isStale)
        _StatusIcon(icon: Icons.cloud_off, color: theme.colorScheme.error, tooltip: 'No connectivity'),
    ];
    if (badges.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: badges);
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.icon, required this.color, required this.tooltip});

  final IconData icon;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
