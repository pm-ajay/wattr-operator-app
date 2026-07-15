import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/threshold_settings.dart';
import '../../shared/widgets/section_card.dart';
import 'widgets/labeled_field.dart';

/// Scoped to Automation / Auto Mode only. Protection thresholds
/// (voltage/current) and communication intervals are configured outside
/// this app and shown read-only elsewhere (e.g. Pump Detail's threshold
/// bars) — editing them here is out of scope.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.pumpId});

  final String pumpId;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late ThresholdSettings _original;
  late TextEditingController _autoDelay;
  late TextEditingController _autoMaxDuration;
  late bool _autoModeEnabled;

  bool _isSaving = false;
  bool _initialized = false;
  Map<String, String> _errors = {};

  void _initFrom(ThresholdSettings t) {
    _original = t;
    _autoDelay = TextEditingController(text: t.autoDelaySeconds.toString());
    _autoMaxDuration = TextEditingController(text: t.autoMaxDurationMinutes.toString());
    _autoModeEnabled = t.autoModeEnabled;
    _initialized = true;
  }

  @override
  void dispose() {
    _autoDelay.dispose();
    _autoMaxDuration.dispose();
    super.dispose();
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    final autoDelay = int.tryParse(_autoDelay.text);
    final autoMaxDuration = int.tryParse(_autoMaxDuration.text);

    if (autoDelay == null || autoDelay < 0) errors['autoDelay'] = 'Cannot be negative';
    if (autoMaxDuration == null || autoMaxDuration <= 0) errors['autoMaxDuration'] = 'Enter a positive number of minutes';

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
        autoDelaySeconds: int.tryParse(_autoDelay.text) ?? _original.autoDelaySeconds,
        autoMaxDurationMinutes: int.tryParse(_autoMaxDuration.text) ?? _original.autoMaxDurationMinutes,
        autoModeEnabled: _autoModeEnabled,
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
