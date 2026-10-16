import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dummy_data/providers.dart';
import '../../../core/models/pump.dart';
import '../../../core/models/threshold_settings.dart';
import '../../settings/widgets/labeled_field.dart';

Future<bool> showProtectionSettingsSheet(BuildContext context, {required Pump pump}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ProtectionSettingsForm(pump: pump),
    ),
  );
  return saved ?? false;
}

class _ProtectionSettingsForm extends ConsumerStatefulWidget {
  const _ProtectionSettingsForm({required this.pump});

  final Pump pump;

  @override
  ConsumerState<_ProtectionSettingsForm> createState() => _ProtectionSettingsFormState();
}

class _ProtectionSettingsFormState extends ConsumerState<_ProtectionSettingsForm> {
  late ThresholdSettings _t;
  late TextEditingController _vMin;
  late TextEditingController _vMax;
  late TextEditingController _phasedownVoltage;
  late TextEditingController _iMin;
  late TextEditingController _iMax;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _t = widget.pump.thresholds;
    _vMin = TextEditingController(text: _t.vMin.toStringAsFixed(0));
    _vMax = TextEditingController(text: _t.vMax.toStringAsFixed(0));
    _phasedownVoltage = TextEditingController(text: _t.phasedownVoltage.toStringAsFixed(0));
    _iMin = TextEditingController(text: _t.iMin.toStringAsFixed(1));
    _iMax = TextEditingController(text: _t.iMax.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _vMin.dispose();
    _vMax.dispose();
    _phasedownVoltage.dispose();
    _iMin.dispose();
    _iMax.dispose();
    super.dispose();
  }

  void _applyAutoCurrentRange() {
    final range = _t.recalculatedCurrentRange();
    setState(() {
      _iMin.text = range.iMin.toStringAsFixed(1);
      _iMax.text = range.iMax.toStringAsFixed(1);
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final updated = _t.copyWith(
      vMin: double.tryParse(_vMin.text) ?? _t.vMin,
      vMax: double.tryParse(_vMax.text) ?? _t.vMax,
      phasedownVoltage: double.tryParse(_phasedownVoltage.text) ?? _t.phasedownVoltage,
      iMin: double.tryParse(_iMin.text) ?? _t.iMin,
      iMax: double.tryParse(_iMax.text) ?? _t.iMax,
    );
    await Future.delayed(const Duration(milliseconds: 400));
    ref.read(pumpsProvider.notifier).updateThresholds(widget.pump.id, updated);
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
              Text('Protection Settings', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Same scope and parameters as configured in MIS.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 16),
              Text('Voltage Protection', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LabeledNumberField(
                      label: 'V Min',
                      description: 'Minimum safe voltage.',
                      controller: _vMin,
                      suffixText: 'V',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LabeledNumberField(
                      label: 'V Max',
                      description: 'Maximum safe voltage.',
                      controller: _vMax,
                      suffixText: 'V',
                    ),
                  ),
                ],
              ),
              LabeledSwitch(
                label: 'Overvoltage Protection',
                description: 'Trip the pump if voltage exceeds V Max.',
                value: _t.overVoltageEnabled,
                onChanged: (v) => setState(() => _t = _t.copyWith(overVoltageEnabled: v)),
              ),
              LabeledSwitch(
                label: 'Undervoltage Protection',
                description: 'Trip the pump if voltage drops below V Min.',
                value: _t.underVoltageEnabled,
                onChanged: (v) => setState(() => _t = _t.copyWith(underVoltageEnabled: v)),
              ),
              LabeledSwitch(
                label: 'Phasedown',
                description: 'Reduce load automatically as voltage approaches an unsafe level.',
                value: _t.phasedownEnabled,
                onChanged: (v) => setState(() => _t = _t.copyWith(phasedownEnabled: v)),
              ),
              if (_t.phasedownEnabled)
                LabeledNumberField(
                  label: 'Phasedown Voltage',
                  description: 'Voltage at which phasedown kicks in.',
                  controller: _phasedownVoltage,
                  suffixText: 'V',
                ),
              const Divider(height: 28),
              Text('Current Protection', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              LabeledSwitch(
                label: 'Auto-calculate from Motor HP',
                description: 'Derive I Min/I Max from the configured motor size instead of setting them manually.',
                value: _t.currentAutoCalculated,
                onChanged: (v) {
                  setState(() => _t = _t.copyWith(currentAutoCalculated: v));
                  if (v) _applyAutoCurrentRange();
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: LabeledNumberField(
                      label: 'I Min',
                      description: 'Minimum safe current.',
                      controller: _iMin,
                      suffixText: 'A',
                      enabled: !_t.currentAutoCalculated,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LabeledNumberField(
                      label: 'I Max',
                      description: 'Maximum safe current.',
                      controller: _iMax,
                      suffixText: 'A',
                      enabled: !_t.currentAutoCalculated,
                    ),
                  ),
                ],
              ),
              LabeledSwitch(
                label: 'Overload Protection',
                description: 'Trip the pump if current exceeds I Max.',
                value: _t.overloadEnabled,
                onChanged: (v) => setState(() => _t = _t.copyWith(overloadEnabled: v)),
              ),
              const Divider(height: 28),
              Text('Other Protections', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              LabeledSwitch(
                label: 'Dry Run Protection',
                description: 'Trip the pump if it runs without adequate water flow.',
                value: _t.dryRunEnabled,
                onChanged: (v) => setState(() => _t = _t.copyWith(dryRunEnabled: v)),
              ),
              LabeledSwitch(
                label: 'Reverse Phase Protection',
                description: 'Trip the pump if the incoming phase sequence is reversed.',
                value: _t.reversePhaseEnabled,
                onChanged: (v) => setState(() => _t = _t.copyWith(reversePhaseEnabled: v)),
              ),
              const SizedBox(height: 12),
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
                      : const Text('Save Protection Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
