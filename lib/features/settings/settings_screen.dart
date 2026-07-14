import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/threshold_settings.dart';
import '../../shared/widgets/section_card.dart';
import 'widgets/hp_calculator_sheet.dart';
import 'widgets/labeled_field.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.pumpId});

  final String pumpId;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late ThresholdSettings _original;
  late TextEditingController _sendOn;
  late TextEditingController _sendOff;
  late TextEditingController _autoDelay;
  late TextEditingController _autoMaxDuration;
  late bool _autoModeEnabled;

  late TextEditingController _vMin;
  late TextEditingController _vMax;
  late TextEditingController _phasedownVoltage;
  late bool _phasedownEnabled;
  late bool _overVoltageEnabled;
  late bool _underVoltageEnabled;

  late TextEditingController _iMin;
  late TextEditingController _iMax;
  late bool _overloadEnabled;
  late bool _currentAutoCalculated;
  late double _motorHp;
  late SupplyVoltage _supplyVoltage;
  late PhaseType _phaseType;

  late bool _dryRunEnabled;
  late bool _reversePhaseEnabled;

  bool _isSaving = false;
  bool _initialized = false;
  Map<String, String> _errors = {};

  void _initFrom(ThresholdSettings t) {
    _original = t;
    _sendOn = TextEditingController(text: t.sendIntervalOnSeconds.toString());
    _sendOff = TextEditingController(text: t.sendIntervalOffSeconds.toString());
    _autoDelay = TextEditingController(text: t.autoDelaySeconds.toString());
    _autoMaxDuration = TextEditingController(text: t.autoMaxDurationMinutes.toString());
    _autoModeEnabled = t.autoModeEnabled;

    _vMin = TextEditingController(text: t.vMin.toStringAsFixed(0));
    _vMax = TextEditingController(text: t.vMax.toStringAsFixed(0));
    _phasedownVoltage = TextEditingController(text: t.phasedownVoltage.toStringAsFixed(0));
    _phasedownEnabled = t.phasedownEnabled;
    _overVoltageEnabled = t.overVoltageEnabled;
    _underVoltageEnabled = t.underVoltageEnabled;

    _iMin = TextEditingController(text: t.iMin.toStringAsFixed(1));
    _iMax = TextEditingController(text: t.iMax.toStringAsFixed(1));
    _overloadEnabled = t.overloadEnabled;
    _currentAutoCalculated = t.currentAutoCalculated;
    _motorHp = t.motorHp;
    _supplyVoltage = t.supplyVoltage;
    _phaseType = t.phaseType;

    _dryRunEnabled = t.dryRunEnabled;
    _reversePhaseEnabled = t.reversePhaseEnabled;
    _initialized = true;
  }

  @override
  void dispose() {
    for (final c in [_sendOn, _sendOff, _autoDelay, _autoMaxDuration, _vMin, _vMax, _phasedownVoltage, _iMin, _iMax]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text);

  Map<String, String> _validate() {
    final errors = <String, String>{};
    final vMin = _num(_vMin);
    final vMax = _num(_vMax);
    final iMin = _num(_iMin);
    final iMax = _num(_iMax);

    if (vMin == null) errors['vMin'] = 'Enter a value';
    if (vMax == null) errors['vMax'] = 'Enter a value';
    if (iMin == null) errors['iMin'] = 'Enter a value';
    if (iMax == null) errors['iMax'] = 'Enter a value';

    if (vMin != null && vMin < 0) errors['vMin'] = 'Cannot be negative';
    if (vMax != null && vMax < 0) errors['vMax'] = 'Cannot be negative';
    if (iMin != null && iMin < 0) errors['iMin'] = 'Cannot be negative';
    if (iMax != null && iMax < 0) errors['iMax'] = 'Cannot be negative';

    if (vMin != null && vMax != null && vMin >= vMax) {
      errors['vMin'] = 'Vmin must be less than Vmax';
      errors['vMax'] = 'Vmax must be greater than Vmin';
    }
    if (iMin != null && iMax != null && iMin >= iMax) {
      errors['iMin'] = 'Imin must be less than Imax';
      errors['iMax'] = 'Imax must be greater than Imin';
    }

    if (vMax != null && vMax > 500) errors['vMax'] = 'Outside expected equipment range';
    if (iMax != null && iMax > 300) errors['iMax'] = 'Outside expected equipment range';

    final sendOn = int.tryParse(_sendOn.text);
    final sendOff = int.tryParse(_sendOff.text);
    final autoDelay = int.tryParse(_autoDelay.text);
    final autoMaxDuration = int.tryParse(_autoMaxDuration.text);
    final phasedownVoltage = _num(_phasedownVoltage);

    if (sendOn == null || sendOn <= 0) errors['sendOn'] = 'Enter a positive number of seconds';
    if (sendOff == null || sendOff <= 0) errors['sendOff'] = 'Enter a positive number of seconds';
    if (autoDelay == null || autoDelay < 0) errors['autoDelay'] = 'Cannot be negative';
    if (autoMaxDuration == null || autoMaxDuration <= 0) errors['autoMaxDuration'] = 'Enter a positive number of minutes';
    if (phasedownVoltage == null || phasedownVoltage < 0) {
      errors['phasedownVoltage'] = 'Cannot be negative';
    } else if (vMax != null && phasedownVoltage >= vMax) {
      errors['phasedownVoltage'] = 'Should be below Vmax';
    }

    return errors;
  }

  Future<void> _save() async {
    final errors = _validate();
    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted fields before saving.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final updated = _original.copyWith(
        sendIntervalOnSeconds: int.tryParse(_sendOn.text) ?? _original.sendIntervalOnSeconds,
        sendIntervalOffSeconds: int.tryParse(_sendOff.text) ?? _original.sendIntervalOffSeconds,
        autoDelaySeconds: int.tryParse(_autoDelay.text) ?? _original.autoDelaySeconds,
        autoMaxDurationMinutes: int.tryParse(_autoMaxDuration.text) ?? _original.autoMaxDurationMinutes,
        autoModeEnabled: _autoModeEnabled,
        vMin: _num(_vMin),
        vMax: _num(_vMax),
        phasedownVoltage: _num(_phasedownVoltage),
        phasedownEnabled: _phasedownEnabled,
        overVoltageEnabled: _overVoltageEnabled,
        underVoltageEnabled: _underVoltageEnabled,
        iMin: _num(_iMin),
        iMax: _num(_iMax),
        overloadEnabled: _overloadEnabled,
        dryRunEnabled: _dryRunEnabled,
        reversePhaseEnabled: _reversePhaseEnabled,
        motorHp: _motorHp,
        supplyVoltage: _supplyVoltage,
        phaseType: _phaseType,
        currentAutoCalculated: _currentAutoCalculated,
      );
      ref.read(pumpsProvider.notifier).updateThresholds(widget.pumpId, updated);
      if (!mounted) return;
      setState(() {
        _original = updated;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save settings. Please try again.')),
      );
    }
  }

  Future<void> _openHpCalculator() async {
    final result = await showHpCalculatorSheet(
      context,
      initialHp: _motorHp,
      initialVoltage: _supplyVoltage,
      initialPhase: _phaseType,
    );
    if (result == null) return;
    setState(() {
      _motorHp = result.motorHp;
      _supplyVoltage = result.supplyVoltage;
      _phaseType = result.phaseType;
      _iMin.text = result.iMin.toStringAsFixed(1);
      _iMax.text = result.iMax.toStringAsFixed(1);
      _currentAutoCalculated = true;
      _errors = {..._errors}..remove('iMin')..remove('iMax');
    });
  }

  @override
  Widget build(BuildContext context) {
    final pumps = ref.watch(pumpsProvider);
    final matches = pumps.where((p) => p.id == widget.pumpId);
    if (matches.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Pump not found.')));
    }
    final pump = matches.first;
    if (!_initialized) _initFrom(pump.thresholds);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Settings — ${pump.displayLabel}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          SectionCard(
            title: 'Communication',
            subtitle: 'How often the device reports its status',
            children: [
              LabeledNumberField(
                label: 'Send Interval — Running',
                description: 'How often the pump sends a status update while it is on.',
                controller: _sendOn,
                suffixText: 'sec',
                errorText: _errors['sendOn'],
                allowDecimal: false,
              ),
              LabeledNumberField(
                label: 'Send Interval — Idle',
                description: 'How often the pump sends a status update while it is off.',
                controller: _sendOff,
                suffixText: 'sec',
                errorText: _errors['sendOff'],
                allowDecimal: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Automation',
            subtitle: 'How the pump behaves automatically',
            trailing: TextButton.icon(
              onPressed: () => context.push('/pump/${widget.pumpId}/schedules'),
              icon: const Icon(Icons.schedule, size: 18),
              label: const Text('Schedules'),
            ),
            children: [
              LabeledSwitch(
                label: 'Auto Mode',
                description:
                    'Runs the pump automatically based on electricity availability. Highest priority — overrides both manual control and any active schedules while on.',
                value: _autoModeEnabled,
                onChanged: (v) => setState(() => _autoModeEnabled = v),
              ),
              if (_autoModeEnabled)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: theme.colorScheme.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'While Auto Mode is on, manual On/Off and any schedules for this pump are overridden.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              LabeledNumberField(
                label: 'Auto Delay',
                description: 'Wait time before the pump restarts automatically after stopping.',
                controller: _autoDelay,
                suffixText: 'sec',
                errorText: _errors['autoDelay'],
                allowDecimal: false,
              ),
              LabeledNumberField(
                label: 'Auto Max Duration',
                description: 'Maximum time the pump is allowed to run continuously.',
                controller: _autoMaxDuration,
                suffixText: 'min',
                errorText: _errors['autoMaxDuration'],
                allowDecimal: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Voltage Protection',
            subtitle: 'Automatically stops the pump on unsafe voltage',
            children: [
              LabeledNumberField(
                label: 'Vmin',
                description: 'Pump stops automatically if voltage drops below this value.',
                controller: _vMin,
                suffixText: 'V',
                errorText: _errors['vMin'],
              ),
              LabeledNumberField(
                label: 'Vmax',
                description: 'Pump stops automatically if voltage goes above this value.',
                controller: _vMax,
                suffixText: 'V',
                errorText: _errors['vMax'],
              ),
              LabeledNumberField(
                label: 'Phasedown Voltage',
                description: 'Voltage at which the pump gradually ramps down instead of stopping abruptly.',
                controller: _phasedownVoltage,
                suffixText: 'V',
                errorText: _errors['phasedownVoltage'],
                enabled: _phasedownEnabled,
              ),
              LabeledSwitch(
                label: 'Phasedown Enabled',
                description: 'Ramp the pump down smoothly instead of an abrupt stop near the voltage limit.',
                value: _phasedownEnabled,
                onChanged: (v) => setState(() => _phasedownEnabled = v),
              ),
              LabeledSwitch(
                label: 'Overvoltage Protection',
                description: 'Stop the pump if voltage exceeds Vmax.',
                value: _overVoltageEnabled,
                onChanged: (v) => setState(() => _overVoltageEnabled = v),
              ),
              LabeledSwitch(
                label: 'Undervoltage Protection',
                description: 'Stop the pump if voltage drops below Vmin.',
                value: _underVoltageEnabled,
                onChanged: (v) => setState(() => _underVoltageEnabled = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Current Protection',
            subtitle: 'Automatically stops the pump on unsafe current draw',
            trailing: TextButton.icon(
              onPressed: _openHpCalculator,
              icon: const Icon(Icons.calculate_outlined, size: 18),
              label: const Text('Recalculate from HP'),
            ),
            children: [
              if (_currentAutoCalculated)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Imin/Imax are estimated from ${_motorHp % 1 == 0 ? _motorHp.toInt() : _motorHp} HP · '
                    '${_supplyVoltage.label} · ${_phaseType.label}. Edit the values below to override.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              LabeledNumberField(
                label: 'Imin',
                description: 'Pump stops automatically if current drops below this value (e.g. dry run).',
                controller: _iMin,
                suffixText: 'A',
                errorText: _errors['iMin'],
              ),
              LabeledNumberField(
                label: 'Imax',
                description: 'Pump stops automatically if current exceeds this value (overload).',
                controller: _iMax,
                suffixText: 'A',
                errorText: _errors['iMax'],
              ),
              LabeledSwitch(
                label: 'Overload Protection',
                description: 'Stop the pump if current exceeds Imax.',
                value: _overloadEnabled,
                onChanged: (v) => setState(() => _overloadEnabled = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Other Protections',
            children: [
              LabeledSwitch(
                label: 'Dry Run Protection',
                description: 'Stop the pump if it runs without adequate water flow.',
                value: _dryRunEnabled,
                onChanged: (v) => setState(() => _dryRunEnabled = v),
              ),
              LabeledSwitch(
                label: 'Reverse Phase Protection',
                description: 'Stop the pump if the incoming 3-phase sequence is reversed.',
                value: _reversePhaseEnabled,
                onChanged: (v) => setState(() => _reversePhaseEnabled = v),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Settings'),
            ),
          ),
        ),
      ),
    );
  }
}
