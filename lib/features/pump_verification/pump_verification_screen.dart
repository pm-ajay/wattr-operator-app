import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/electrical_reading.dart';
import '../../core/models/pump.dart';
import '../../core/models/pump_mode.dart';
import '../../core/models/pump_status.dart';
import '../../core/theme/status_colors.dart';
import '../../core/utils/time_ago.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/section_card.dart';
import 'widgets/calibration_sheet.dart';
import 'widgets/discharge_entry_sheet.dart';
import 'widgets/protection_settings_sheet.dart';

/// Installation/commissioning view for a technician on-site: live device
/// vitals plus the controls needed to bring a pump into service — power,
/// protection thresholds, sensor calibration, and an initial discharge
/// reading. Electrical readings here (Power Factor, phase angle) are
/// simulated fresh each time this screen opens (and on every pull-to-
/// refresh), never reused from a cached snapshot, since a technician needs
/// to trust what's on screen reflects the pump right now.
class PumpVerificationScreen extends ConsumerStatefulWidget {
  const PumpVerificationScreen({super.key, required this.pumpId});

  final String pumpId;

  @override
  ConsumerState<PumpVerificationScreen> createState() => _PumpVerificationScreenState();
}

class _PumpVerificationScreenState extends ConsumerState<PumpVerificationScreen> {
  _LiveSnapshot? _snapshot;

  void _refresh(Pump pump) {
    setState(() => _snapshot = _LiveSnapshot.generate(pump));
  }

  Future<void> _handleToggle(Pump pump) async {
    final isOn = pump.status.isOn;
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
      notifier.setOff(pump.id);
    } else {
      notifier.setOn(pump.id);
    }
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  /// Awaits a bottom sheet and shows the confirmation from this screen's own
  /// stable context — not the sheet's, which is already being torn down by
  /// the time it would need to show one.
  Future<void> _openSheet(Future<bool> Function() open, String savedMessage) async {
    final saved = await open();
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(savedMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pumps = ref.watch(pumpsProvider);
    final matches = pumps.where((p) => p.id == widget.pumpId);
    final pump = matches.isEmpty ? null : matches.first;

    if (pump == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Pump not found.')));
    }

    // Generated once per pump per screen instance — a fresh live pull on
    // open, not regenerated on every unrelated rebuild.
    _snapshot ??= _LiveSnapshot.generate(pump);
    final snapshot = _snapshot!;

    final operators = ref.watch(operatorsProvider);
    final operator = operators.firstWhere((o) => o.id == pump.operatorId);
    final mode = ref.watch(pumpModeProvider(pump.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Device Info')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(pump),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                Icon(Icons.sensors, size: 15, color: theme.colorScheme.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Live readings — fetched ${timeAgo(snapshot.generatedAt)}. Pull down to refresh.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _IdentityCard(
              pump: pump,
              snapshot: snapshot,
              mode: mode,
              operatorName: operator.name,
              operatorPhone: operator.phone,
              onToggle: () => _handleToggle(pump),
              onCopy: _copyToClipboard,
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Communication & Run Info',
              children: [_CommunicationInfoSection(pump: pump)],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Active Fault',
              children: [_ActiveFaultSection(pump: pump, snapshot: snapshot)],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Electrical Readings',
              subtitle: 'Live per-phase voltage, current, and phase angle',
              children: [_ElectricalReadingsTable(pump: pump, snapshot: snapshot)],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Protection Settings',
              subtitle: 'Scope and parameters match MIS',
              trailing: TextButton(
                onPressed: () => _openSheet(
                  () => showProtectionSettingsSheet(context, pump: pump),
                  'Protection settings saved.',
                ),
                child: const Text('Configure'),
              ),
              children: [_ProtectionSummary(pump: pump)],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Calibration',
              trailing: TextButton(
                onPressed: () => _openSheet(
                  () => showCalibrationSheet(context, pump: pump),
                  'Calibration saved.',
                ),
                child: const Text('Calibrate'),
              ),
              children: [_CalibrationSummary(pump: pump)],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Discharge',
              trailing: TextButton(
                onPressed: () => _openSheet(
                  () => showDischargeEntrySheet(context, pump: pump),
                  'Discharge reading recorded.',
                ),
                child: const Text('Record Reading'),
              ),
              children: [_DischargeSummary(pump: pump)],
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.pump,
    required this.snapshot,
    required this.mode,
    required this.operatorName,
    required this.operatorPhone,
    required this.onToggle,
    required this.onCopy,
  });

  final Pump pump;
  final _LiveSnapshot snapshot;
  final PumpMode mode;
  final String operatorName;
  final String operatorPhone;
  final VoidCallback onToggle;
  final void Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = StatusColors.colorFor(pump.status.severity);
    final bg = StatusColors.bgFor(pump.status.severity);
    final kw = snapshot.instantaneousKw(pump);
    final ratedKw = pump.thresholds.motorHp * 0.746;
    final outlineStyle = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    final isOn = pump.status.isOn;
    final autoOverride = mode == PumpMode.auto;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pump.displayLabel,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    pump.status.label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => onCopy('IMEI', pump.imei),
              child: Row(
                children: [
                  Icon(Icons.perm_device_information, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 6),
                  Text('IMEI', style: outlineStyle),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(pump.imei, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.copy, size: 14, color: theme.colorScheme.outline),
                ],
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => onCopy('Phone number', operatorPhone),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 6),
                  Text('Operator', style: outlineStyle),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$operatorName · $operatorPhone',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.copy, size: 14, color: theme.colorScheme.outline),
                ],
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text('Live Power', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  'Rated ${pump.thresholds.motorHp.toStringAsFixed(1)} HP (~${ratedKw.toStringAsFixed(2)} kW)',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (kw != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(kw.toStringAsFixed(2), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 6),
                  Text('kW', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
                ],
              )
            else
              Text('Not running', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
            const Divider(height: 24),
            if (autoOverride)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Manual control is overridden while Auto Mode is on.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: isOn ? theme.colorScheme.error : StatusColors.good),
                icon: Icon(isOn ? Icons.power_settings_new : Icons.play_arrow),
                label: Text(isOn ? 'Turn Off Pump' : 'Turn On Pump'),
                onPressed: autoOverride ? null : onToggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElectricalReadingsTable extends StatelessWidget {
  const _ElectricalReadingsTable({required this.pump, required this.snapshot});

  final Pump pump;
  final _LiveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = pump.status.isOn;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    Color readingColor(PhaseReading r) {
      if (r.isOutOfRange) return theme.colorScheme.error;
      if (r.isNearLimit) return StatusColors.warn;
      return theme.colorScheme.onSurface;
    }

    final voltageByPhase = {for (final r in pump.voltageReadings) r.phase: r};
    final currentByPhase = {for (final r in pump.currentReadings) r.phase: r};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 32),
            Expanded(child: Text('VOLTAGE', style: labelStyle)),
            Expanded(child: Text('CURRENT', style: labelStyle)),
            Expanded(child: Text('PHASE ANGLE', style: labelStyle)),
          ],
        ),
        const SizedBox(height: 8),
        for (final phase in Phase.values) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(phase.label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Expanded(
                  child: Text(
                    '${voltageByPhase[phase]!.value.toStringAsFixed(0)} V',
                    style: TextStyle(fontWeight: FontWeight.w600, color: readingColor(voltageByPhase[phase]!)),
                  ),
                ),
                Expanded(
                  child: Text(
                    running ? '${currentByPhase[phase]!.value.toStringAsFixed(1)} A' : '—',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: running ? readingColor(currentByPhase[phase]!) : theme.colorScheme.outline,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${snapshot.phaseAngles[phase]!.toStringAsFixed(1)}°',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Divider(height: 20),
        Row(
          children: [
            Icon(
              snapshot.isBalanced ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              size: 16,
              color: snapshot.isBalanced ? StatusColors.good : StatusColors.crit,
            ),
            const SizedBox(width: 6),
            Text(
              snapshot.isBalanced
                  ? 'Phases balanced (ideal ~120° apart)'
                  : 'Phases imbalanced — check sequence and wiring',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: snapshot.isBalanced ? StatusColors.good : StatusColors.crit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('Power Factor', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (!running || snapshot.powerFactor == null)
              Text('Not running', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))
            else
              _PowerFactorPill(value: snapshot.powerFactor!),
          ],
        ),
      ],
    );
  }
}

class _PowerFactorPill extends StatelessWidget {
  const _PowerFactorPill({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final (label, color) = value >= 0.90
        ? ('Good', StatusColors.good)
        : value >= 0.75
            ? ('Fair', StatusColors.warn)
            : ('Poor', StatusColors.crit);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ],
    );
  }
}

/// Friendly fault name for the Active Fault card — plain terms a technician
/// recognizes on-site, distinct from [PumpStatus.label]'s fuller wording.
String _faultName(PumpStatus status) => switch (status) {
      PumpStatus.faultOvervoltage => 'Overvoltage',
      PumpStatus.faultUndervoltage => 'Undervoltage',
      PumpStatus.faultOverload => 'Over Current',
      PumpStatus.faultDryRun => 'Dry Run',
      PumpStatus.faultReversePhase => 'Reverse Phase',
      _ => status.label,
    };

class _ActiveIssue {
  const _ActiveIssue({required this.name, required this.detail});

  final String name;
  final String detail;
}

/// Combines two independent sources of "something's wrong right now": a
/// device-reported fault, and phase imbalance detected live on this screen
/// (which the pump's own status may not yet reflect). Either, both, or
/// neither can apply at once.
class _ActiveFaultSection extends StatelessWidget {
  const _ActiveFaultSection({required this.pump, required this.snapshot});

  final Pump pump;
  final _LiveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final issues = [
      if (pump.status.isFault)
        _ActiveIssue(name: _faultName(pump.status), detail: '${pump.status.shortReason} · since ${timeAgo(pump.stateSince)}'),
      if (!snapshot.isBalanced)
        const _ActiveIssue(
          name: 'Phase Imbalance',
          detail: 'Angles deviate from ~120° apart — check phase sequence and wiring',
        ),
    ];

    if (issues.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: StatusColors.goodBg, borderRadius: BorderRadius.circular(10)),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: StatusColors.good),
            SizedBox(width: 8),
            Text('No active fault', style: TextStyle(color: StatusColors.good, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < issues.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ActiveIssueBanner(issue: issues[i]),
        ],
      ],
    );
  }
}

class _ActiveIssueBanner extends StatelessWidget {
  const _ActiveIssueBanner({required this.issue});

  final _ActiveIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(issue.name, style: TextStyle(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(issue.detail, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _CommunicationInfoSection extends StatelessWidget {
  const _CommunicationInfoSection({required this.pump});

  final Pump pump;

  @override
  Widget build(BuildContext context) {
    final running = pump.status.isOn;
    final lastRun = running ? 'Currently running (since ${timeAgo(pump.stateSince)})' : timeAgo(pump.stateSince);

    return Column(
      children: [
        _InfoLine(label: 'Last Communication', value: timeAgo(pump.lastUpdate)),
        const SizedBox(height: 10),
        _InfoLine(label: 'Last Run Date', value: lastRun),
      ],
    );
  }
}

class _ProtectionSummary extends StatelessWidget {
  const _ProtectionSummary({required this.pump});

  final Pump pump;

  @override
  Widget build(BuildContext context) {
    final t = pump.thresholds;
    return Column(
      children: [
        _InfoLine(label: 'Voltage Range', value: '${t.vMin.toStringAsFixed(0)}–${t.vMax.toStringAsFixed(0)} V'),
        const SizedBox(height: 10),
        _InfoLine(label: 'Current Range', value: '${t.iMin.toStringAsFixed(1)}–${t.iMax.toStringAsFixed(1)} A'),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ProtectionChip(label: 'Overvoltage', enabled: t.overVoltageEnabled),
              _ProtectionChip(label: 'Undervoltage', enabled: t.underVoltageEnabled),
              _ProtectionChip(label: 'Overload', enabled: t.overloadEnabled),
              _ProtectionChip(label: 'Dry Run', enabled: t.dryRunEnabled),
              _ProtectionChip(label: 'Reverse Phase', enabled: t.reversePhaseEnabled),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProtectionChip extends StatelessWidget {
  const _ProtectionChip({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled ? StatusColors.good : theme.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: enabled ? StatusColors.goodBg : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(enabled ? Icons.check_circle : Icons.circle_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _CalibrationSummary extends StatelessWidget {
  const _CalibrationSummary({required this.pump});

  final Pump pump;

  @override
  Widget build(BuildContext context) {
    final c = pump.calibration;
    return Column(
      children: [
        _InfoLine(
          label: 'Current Multiplier',
          value: '${c.currentMultiplier.toStringAsFixed(2)}× (from ${c.outputCurrentAmps.toStringAsFixed(2)} A)',
        ),
        const SizedBox(height: 10),
        _InfoLine(
          label: 'Set Voltage (R/Y/B)',
          value: Phase.values.map((p) => '${c.voltageSetPoints[p]!.toStringAsFixed(0)}V').join(' / '),
        ),
        const SizedBox(height: 10),
        _InfoLine(
          label: 'Set Current (R/Y/B)',
          value: Phase.values.map((p) => '${c.currentSetPoints[p]!.toStringAsFixed(1)}A').join(' / '),
        ),
      ],
    );
  }
}

class _DischargeSummary extends StatelessWidget {
  const _DischargeSummary({required this.pump});

  final Pump pump;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reading = pump.lastDischargeReading;
    if (reading == null) {
      return Text(
        'No discharge reading recorded yet.',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reading.photoBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(reading.photoBytes!, width: 56, height: 56, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${reading.lps.toStringAsFixed(2)} LPS',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Recorded ${timeAgo(reading.recordedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              if (reading.hasLocation)
                Text(
                  '${reading.latitude!.toStringAsFixed(5)}, ${reading.longitude!.toStringAsFixed(5)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Simulated live electrical readings for this open of the screen — not
/// stored on [Pump], not part of the seeded dummy dataset, and regenerated
/// on every open and every pull-to-refresh so it never reads as a stale,
/// cached value.
class _LiveSnapshot {
  const _LiveSnapshot({required this.generatedAt, required this.powerFactor, required this.phaseAngles});

  final DateTime generatedAt;
  final double? powerFactor;
  final Map<Phase, double> phaseAngles;

  bool get isBalanced {
    const nominal = {Phase.r: 0.0, Phase.y: 120.0, Phase.b: 240.0};
    return Phase.values.every((p) => (phaseAngles[p]! - nominal[p]!).abs() <= 15.0);
  }

  /// Instantaneous three-phase power from the pump's live voltage/current
  /// readings and this snapshot's Power Factor — null while the pump isn't
  /// running, since current and PF aren't meaningful then.
  double? instantaneousKw(Pump pump) {
    final pf = powerFactor;
    if (pf == null) return null;
    final avgV = pump.voltageReadings.map((r) => r.value).reduce((a, b) => a + b) / pump.voltageReadings.length;
    final avgI = pump.currentReadings.map((r) => r.value).reduce((a, b) => a + b) / pump.currentReadings.length;
    return sqrt(3) * avgV * avgI * pf / 1000;
  }

  static _LiveSnapshot generate(Pump pump) {
    final rnd = Random();
    final running = pump.status.isOn;
    final reversed = pump.status == PumpStatus.faultReversePhase;
    double jitter() => (rnd.nextDouble() * 8) - 4;

    return _LiveSnapshot(
      generatedAt: DateTime.now(),
      powerFactor: running ? 0.6 + rnd.nextDouble() * 0.39 : null,
      phaseAngles: {
        Phase.r: 0.0,
        Phase.y: (reversed ? 240.0 : 120.0) + jitter(),
        Phase.b: (reversed ? 120.0 : 240.0) + jitter(),
      },
    );
  }
}
