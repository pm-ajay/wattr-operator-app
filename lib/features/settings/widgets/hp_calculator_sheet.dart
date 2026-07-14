import 'package:flutter/material.dart';

import '../../../core/models/threshold_settings.dart';

class HpCalculatorResult {
  const HpCalculatorResult({
    required this.motorHp,
    required this.supplyVoltage,
    required this.phaseType,
    required this.iMin,
    required this.iMax,
  });

  final double motorHp;
  final SupplyVoltage supplyVoltage;
  final PhaseType phaseType;
  final double iMin;
  final double iMax;
}

Future<HpCalculatorResult?> showHpCalculatorSheet(
  BuildContext context, {
  required double initialHp,
  required SupplyVoltage initialVoltage,
  required PhaseType initialPhase,
}) {
  return showModalBottomSheet<HpCalculatorResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _HpCalculatorSheetContent(
        initialHp: initialHp,
        initialVoltage: initialVoltage,
        initialPhase: initialPhase,
      ),
    ),
  );
}

class _HpCalculatorSheetContent extends StatefulWidget {
  const _HpCalculatorSheetContent({
    required this.initialHp,
    required this.initialVoltage,
    required this.initialPhase,
  });

  final double initialHp;
  final SupplyVoltage initialVoltage;
  final PhaseType initialPhase;

  @override
  State<_HpCalculatorSheetContent> createState() => _HpCalculatorSheetContentState();
}

class _HpCalculatorSheetContentState extends State<_HpCalculatorSheetContent> {
  late double _hp = widget.initialHp;
  late SupplyVoltage _voltage = widget.initialVoltage;
  late PhaseType _phase = widget.initialPhase;

  static const _hpOptions = [1.0, 2.0, 3.0, 5.0, 7.5, 10.0, 12.5, 15.0, 20.0];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flAmps = ThresholdSettings.estimateFullLoadAmps(hp: _hp, voltage: _voltage, phase: _phase);
    final iMin = flAmps * 0.4;
    final iMax = flAmps * 1.15;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recalculate from Motor HP', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'We estimate safe current thresholds from your motor rating using a standard full-load current formula.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            Text('Motor HP', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hp in _hpOptions)
                  ChoiceChip(
                    label: Text('${hp % 1 == 0 ? hp.toInt() : hp} HP'),
                    selected: _hp == hp,
                    onSelected: (_) => setState(() => _hp = hp),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Supply Voltage', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final v in SupplyVoltage.values)
                  ChoiceChip(
                    label: Text(v.label),
                    selected: _voltage == v,
                    onSelected: (_) => setState(() {
                      _voltage = v;
                      _phase = v == SupplyVoltage.v230 ? PhaseType.single : PhaseType.three;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Phase Type', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final p in PhaseType.values)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: _phase == p,
                    onSelected: (_) => setState(() => _phase = p),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Suggested current range', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${iMin.toStringAsFixed(1)} A  –  ${iMax.toStringAsFixed(1)} A',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Formula: Full-Load Amps = (HP × 746) ÷ (V × PF × ${_phase == PhaseType.three ? '√3' : '1'}), PF ≈ 0.85. '
                    'Imin = 40% FLA, Imax = 115% FLA.',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  HpCalculatorResult(motorHp: _hp, supplyVoltage: _voltage, phaseType: _phase, iMin: iMin, iMax: iMax),
                ),
                child: const Text('Apply Suggested Values'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
