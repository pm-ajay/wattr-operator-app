import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dummy_data/providers.dart';
import '../../../core/models/calibration_settings.dart';
import '../../../core/models/electrical_reading.dart';
import '../../../core/models/pump.dart';

Future<bool> showCalibrationSheet(BuildContext context, {required Pump pump}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _CalibrationForm(pump: pump),
    ),
  );
  return saved ?? false;
}

class _CalibrationForm extends ConsumerStatefulWidget {
  const _CalibrationForm({required this.pump});

  final Pump pump;

  @override
  ConsumerState<_CalibrationForm> createState() => _CalibrationFormState();
}

class _CalibrationFormState extends ConsumerState<_CalibrationForm> {
  late CalibrationSettings _c;
  late TextEditingController _outputCurrent;
  late Map<Phase, TextEditingController> _voltageControllers;
  late Map<Phase, TextEditingController> _currentControllers;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _c = widget.pump.calibration;
    _outputCurrent = TextEditingController(text: _c.outputCurrentAmps.toStringAsFixed(2));
    _voltageControllers = {
      for (final p in Phase.values) p: TextEditingController(text: _c.voltageSetPoints[p]!.toStringAsFixed(0)),
    };
    _currentControllers = {
      for (final p in Phase.values) p: TextEditingController(text: _c.currentSetPoints[p]!.toStringAsFixed(1)),
    };
  }

  @override
  void dispose() {
    _outputCurrent.dispose();
    for (final c in _voltageControllers.values) {
      c.dispose();
    }
    for (final c in _currentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _liveMultiplier => CalibrationSettings.multiplierFor(double.tryParse(_outputCurrent.text) ?? 0);

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final outputCurrent = double.tryParse(_outputCurrent.text) ?? _c.outputCurrentAmps;
    final updated = _c.copyWith(
      outputCurrentAmps: outputCurrent,
      voltageSetPoints: {
        for (final p in Phase.values) p: double.tryParse(_voltageControllers[p]!.text) ?? _c.voltageSetPoints[p]!,
      },
      currentSetPoints: {
        for (final p in Phase.values) p: double.tryParse(_currentControllers[p]!.text) ?? _c.currentSetPoints[p]!,
      },
    );
    await Future.delayed(const Duration(milliseconds: 400));
    ref.read(pumpsProvider.notifier).updateCalibration(widget.pump.id, updated);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Calibration', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text(
                'Current Multiplier Output',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Enter the output current you measured directly — the multiplier is derived automatically.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _outputCurrent,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Output Current', suffixText: 'A', isDense: true),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text('Derived Multiplier', style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text(
                      '${_liveMultiplier.toStringAsFixed(2)}×',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const Divider(height: 28),
              Text('Set Voltage (R/Y/B)', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final p in Phase.values) ...[
                    if (p != Phase.values.first) const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _voltageControllers[p],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        decoration: InputDecoration(labelText: p.label, suffixText: 'V', isDense: true),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Text('Set Current (R/Y/B)', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final p in Phase.values) ...[
                    if (p != Phase.values.first) const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _currentControllers[p],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        decoration: InputDecoration(labelText: p.label, suffixText: 'A', isDense: true),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Calibration'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
