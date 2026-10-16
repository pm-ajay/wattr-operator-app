import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/schedule_limits.dart';
import '../../core/dummy_data/providers.dart';
import '../../core/models/schedule.dart';
import '../../core/utils/schedule_name_suggester.dart';

/// Plain-language time-of-day word so a glance tells you whether the pump
/// would run overnight or during the day — not just literal AM/PM, since
/// e.g. 2 AM and 3 PM would otherwise read the same at a glance.
String _timeOfDayLabel(TimeOfDay t) {
  final minutes = t.hour * 60 + t.minute;
  if (minutes >= 5 * 60 && minutes < 12 * 60) return 'Morning';
  if (minutes >= 12 * 60 && minutes < 17 * 60) return 'Afternoon';
  if (minutes >= 17 * 60 && minutes < 20 * 60) return 'Evening';
  return 'Night';
}

const _stepTitles = ['Days', 'Start Time', 'Duration', 'End Time', 'Name', 'Summary'];

const List<({String label, int minutes})> _durationPresets = [
  (label: '15 min', minutes: 15),
  (label: '30 min', minutes: 30),
  (label: '45 min', minutes: 45),
  (label: '1 hr', minutes: 60),
  (label: '2 hr', minutes: 120),
];

Future<bool> showScheduleFormSheet(
  BuildContext context, {
  required String pumpId,
  Schedule? existing,
  int? initialDurationMinutes,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ScheduleFormContent(
        pumpId: pumpId,
        existing: existing,
        initialDurationMinutes: initialDurationMinutes,
      ),
    ),
  );
  return result ?? false;
}

class _ScheduleFormContent extends ConsumerStatefulWidget {
  const _ScheduleFormContent({required this.pumpId, this.existing, this.initialDurationMinutes});

  final String pumpId;
  final Schedule? existing;

  /// Prefills Duration for a brand-new schedule — e.g. handed off from the
  /// Water Volume Calculator. Ignored when editing an existing schedule.
  final int? initialDurationMinutes;

  @override
  ConsumerState<_ScheduleFormContent> createState() => _ScheduleFormContentState();
}

class _ScheduleFormContentState extends ConsumerState<_ScheduleFormContent> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _hoursController = TextEditingController(text: _initialHoursText);
  late final _minutesController = TextEditingController(text: _initialMinutesText);
  late final Set<int> _days = {...(widget.existing?.repeatDays ?? const <int>{})};

  int get _initialTotalMinutes => widget.existing?.duration.inMinutes ?? widget.initialDurationMinutes ?? 0;
  String get _initialHoursText => _initialTotalMinutes ~/ 60 == 0 ? '' : (_initialTotalMinutes ~/ 60).toString();
  String get _initialMinutesText =>
      (widget.existing == null && widget.initialDurationMinutes == null) ? '' : (_initialTotalMinutes % 60).toString();

  int _currentStep = 0;

  // null until the user explicitly jumps back here from the Summary step's
  // "Edit" links — once set, Back/Next return straight to the Summary
  // instead of continuing the normal linear walk through the steps.
  int? _editingStepReturnTarget;

  // Nothing is pre-picked for a new schedule — the operator must explicitly
  // choose a start time rather than silently inherit a default that could
  // be saved without noticing.
  TimeOfDay? _startTime;

  // The hard-stop safety cutoff. Off by default — most schedules just rely
  // on duration to decide when to stop.
  bool _hardStopEnabled = false;
  TimeOfDay? _endTime;

  // Tracks whether the Name field should keep auto-filling from the
  // suggester, or whether the user has taken over by typing their own text.
  bool _nameManuallyEdited = false;
  bool _isAutoSettingName = false;

  String? _nameError;
  String? _daysError;
  String? _startTimeError;
  String? _durationError;
  String? _minutesError;
  String? _endTimeError;
  String? _overlapError;

  @override
  void initState() {
    super.initState();
    _startTime = widget.existing?.startTime;
    _hardStopEnabled = widget.existing?.hasHardStop ?? false;
    _endTime = widget.existing?.endTime;
    _currentStep = widget.existing != null ? 5 : 0;
    _nameManuallyEdited = _nameController.text.isNotEmpty;
    _nameController.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    if (_isAutoSettingName) {
      _isAutoSettingName = false;
      return;
    }
    _nameManuallyEdited = true;
  }

  int? get _durationMinutes {
    final hoursText = _hoursController.text.trim();
    final minutesText = _minutesController.text.trim();
    if (hoursText.isEmpty && minutesText.isEmpty) return null;
    final hours = int.tryParse(hoursText) ?? 0;
    final minutes = int.tryParse(minutesText) ?? 0;
    return hours * 60 + minutes;
  }

  TimeOfDay? _naturalEndTime() {
    final start = _startTime;
    final minutes = _durationMinutes;
    if (start == null || minutes == null || minutes <= 0) return null;
    final total = (start.hour * 60 + start.minute + minutes) % (24 * 60);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  bool get _hardStopIsEarly {
    final start = _startTime;
    final minutes = _durationMinutes;
    final hardStop = _endTime;
    if (start == null || minutes == null || hardStop == null) return false;
    final startMinutes = start.hour * 60 + start.minute;
    final naturalEndMinutes = startMinutes + minutes;
    var hardStopMinutes = hardStop.hour * 60 + hardStop.minute;
    if (hardStopMinutes < startMinutes) hardStopMinutes += 24 * 60;
    return hardStopMinutes < naturalEndMinutes;
  }

  String get _daysSummary {
    if (_days.length == 7) return 'Every day';
    if (_days.isEmpty) return 'No days selected';
    final sorted = _days.toList()..sort();
    return sorted.map((d) => Schedule.dayLabels[d]).join(', ');
  }

  String _formatTimeWithPeriod(TimeOfDay t) => '${_timeOfDayLabel(t)} · ${Schedule.formatTime(t)}';

  String? _durationErrorFor(int? minutes) {
    if (minutes == null || minutes <= 0) return 'Enter a duration greater than 0';
    if (minutes < scheduleMinDurationMinutes) return 'Minimum run duration is $scheduleMinDurationMinutes min';
    if (minutes > scheduleMaxDurationMinutes) {
      return 'Maximum run duration is ${scheduleMaxDurationMinutes ~/ 60} hr';
    }
    return null;
  }

  /// Catches a malformed Minutes value (e.g. "90") that the combined total
  /// might not otherwise flag — 0 hr 90 min totals a "valid" 90 min, but 90
  /// isn't a sane number of minutes-past-the-hour to have typed.
  String? _minutesFieldError() {
    final text = _minutesController.text.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value != null && value > 59) return 'Minutes must be 0–59';
    return null;
  }

  String? _endTimeValidationError() {
    final start = _startTime;
    final hardStop = _endTime;
    if (start == null || hardStop == null) return 'Select a hard stop time';
    final startMinutes = start.hour * 60 + start.minute;
    var hardStopMinutes = hardStop.hour * 60 + hardStop.minute;
    if (hardStopMinutes < startMinutes) hardStopMinutes += 24 * 60;
    if (hardStopMinutes <= startMinutes) return 'End time must be after the start time';
    return null;
  }

  void _maybeSuggestName() {
    if (_nameManuallyEdited) return;
    final start = _startTime;
    final minutes = _durationMinutes;
    if (_days.isEmpty || start == null || minutes == null || minutes <= 0) return;
    final suggestion = suggestScheduleName(days: _days, startTime: start, duration: Duration(minutes: minutes));
    if (suggestion == null) return;
    _isAutoSettingName = true;
    _nameController.text = suggestion;
  }

  void _applyDayPreset(Set<int> preset) {
    setState(() {
      _days
        ..clear()
        ..addAll(preset);
      _daysError = null;
    });
    _maybeSuggestName();
  }

  void _toggleDay(int day, bool selected) {
    setState(() {
      if (selected) {
        _days.add(day);
      } else {
        _days.remove(day);
      }
      _daysError = null;
    });
    _maybeSuggestName();
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime ?? TimeOfDay.now());
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _startTimeError = null;
      });
      _maybeSuggestName();
    }
  }

  void _applyDurationPreset(int minutes) {
    setState(() {
      _hoursController.text = (minutes ~/ 60).toString();
      _minutesController.text = (minutes % 60).toString();
      _durationError = null;
      _minutesError = null;
    });
    _maybeSuggestName();
  }

  void _onDurationChanged() {
    setState(() {
      _durationError = null;
      _minutesError = _minutesFieldError();
    });
    _maybeSuggestName();
  }

  void _setHardStopEnabled(bool enabled) {
    setState(() {
      _hardStopEnabled = enabled;
      if (!enabled) {
        _endTime = null;
        _endTimeError = null;
      }
    });
  }

  Future<void> _pickHardStopTime() async {
    final initial = _endTime ?? _naturalEndTime() ?? _startTime ?? TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _endTimeError = null;
      });
    }
  }

  void _editStep(int step) {
    setState(() {
      _editingStepReturnTarget = 5;
      _currentStep = step;
    });
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        final ok = _days.isNotEmpty;
        setState(() => _daysError = ok ? null : 'Select at least one day');
        return ok;
      case 1:
        final ok = _startTime != null;
        setState(() => _startTimeError = ok ? null : 'Select a start time');
        return ok;
      case 2:
        final minutesErr = _minutesFieldError();
        final durationErr = _durationErrorFor(_durationMinutes);
        setState(() {
          _minutesError = minutesErr;
          _durationError = durationErr;
        });
        return minutesErr == null && durationErr == null;
      case 3:
        if (!_hardStopEnabled) {
          setState(() => _endTimeError = null);
          return true;
        }
        final err = _endTimeValidationError();
        setState(() => _endTimeError = err);
        return err == null;
      case 4:
        final ok = _nameController.text.trim().isNotEmpty;
        setState(() => _nameError = ok ? null : 'Enter a schedule name');
        return ok;
      default:
        return true;
    }
  }

  void _advance() {
    if (!_validateCurrentStep()) return;
    setState(() {
      if (_editingStepReturnTarget != null) {
        _currentStep = _editingStepReturnTarget!;
        _editingStepReturnTarget = null;
      } else if (_currentStep < 5) {
        _currentStep++;
      }
    });
  }

  void _goBack() {
    setState(() {
      if (_editingStepReturnTarget != null) {
        _currentStep = _editingStepReturnTarget!;
        _editingStepReturnTarget = null;
      } else if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    final minutes = _durationMinutes;
    final startTime = _startTime;

    setState(() {
      _nameError = name.isEmpty ? 'Enter a schedule name' : null;
      _daysError = _days.isEmpty ? 'Select at least one day' : null;
      _startTimeError = startTime == null ? 'Select a start time' : null;
      _minutesError = _minutesFieldError();
      _durationError = _durationErrorFor(minutes);
      _endTimeError = _hardStopEnabled ? _endTimeValidationError() : null;
      _overlapError = null;
    });
    if (_nameError != null ||
        _daysError != null ||
        _startTimeError != null ||
        _minutesError != null ||
        _durationError != null ||
        _endTimeError != null) {
      return;
    }

    final candidate = Schedule(
      id: widget.existing?.id ?? 'sched_${DateTime.now().microsecondsSinceEpoch}',
      pumpId: widget.pumpId,
      name: name,
      repeatDays: _days,
      startTime: startTime!,
      duration: Duration(minutes: minutes!),
      endTime: _hardStopEnabled ? _endTime : null,
      active: widget.existing?.active ?? true,
    );

    final conflict = ref
        .read(schedulesProvider.notifier)
        .findConflict(candidate, excludingId: widget.existing?.id);
    if (conflict != null) {
      final other = conflict.schedule;
      setState(() {
        _overlapError = conflict.isGapViolation
            ? 'Too close to "${other.name}" (${other.repeatSummary}, ${other.timeRangeLabel}) — schedules on the same pump need at least $scheduleMinGapMinutes min between them. Adjust the days or time and try again.'
            : 'Overlaps with "${other.name}" (${other.repeatSummary}, ${other.timeRangeLabel}). Adjust the days or time and try again.';
      });
      return;
    }

    if (widget.existing != null) {
      ref.read(schedulesProvider.notifier).updateSchedule(candidate);
    } else {
      ref.read(schedulesProvider.notifier).addSchedule(candidate);
    }
    Navigator.of(context).pop(true);
  }

  String get _primaryButtonLabel {
    if (_currentStep == 5) return widget.existing != null ? 'Save Changes' : 'Add Schedule';
    if (_editingStepReturnTarget != null) return 'Done';
    return 'Next';
  }

  Widget _errorBanner(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysStep(ThemeData theme) {
    return Column(
      key: const ValueKey('step-days'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Which days should this run on?', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(label: const Text('Weekdays'), onPressed: () => _applyDayPreset({1, 2, 3, 4, 5})),
            ActionChip(label: const Text('Weekends'), onPressed: () => _applyDayPreset({6, 7})),
            ActionChip(label: const Text('Every day'), onPressed: () => _applyDayPreset({1, 2, 3, 4, 5, 6, 7})),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in Schedule.dayLabels.entries)
              FilterChip(
                label: Text(entry.value),
                selected: _days.contains(entry.key),
                onSelected: (selected) => _toggleDay(entry.key, selected),
              ),
          ],
        ),
        if (_daysError != null) ...[
          const SizedBox(height: 8),
          Text(_daysError!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        ],
      ],
    );
  }

  Widget _buildStartTimeStep(ThemeData theme) {
    return Column(
      key: const ValueKey('step-start'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('What time should it start?', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickStartTime,
          icon: const Icon(Icons.schedule, size: 18),
          label: Text(_startTime != null ? _formatTimeWithPeriod(_startTime!) : 'Select time'),
          style: _startTimeError != null
              ? OutlinedButton.styleFrom(side: BorderSide(color: theme.colorScheme.error))
              : null,
        ),
        if (_startTimeError != null) ...[
          const SizedBox(height: 8),
          Text(_startTimeError!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        ],
      ],
    );
  }

  Widget _buildDurationStep(ThemeData theme) {
    return Column(
      key: const ValueKey('step-duration'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('How long should it run?', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Allowed range: $scheduleMinDurationMinutes min – ${scheduleMaxDurationMinutes ~/ 60} hr',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _durationPresets)
              ActionChip(label: Text(preset.label), onPressed: () => _applyDurationPreset(preset.minutes)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _hoursController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                onChanged: (_) => _onDurationChanged(),
                decoration: const InputDecoration(labelText: 'Hours', isDense: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _minutesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                onChanged: (_) => _onDurationChanged(),
                decoration: InputDecoration(
                  labelText: 'Minutes',
                  isDense: true,
                  errorText: _minutesError,
                  helperText: _minutesError == null ? '0–59' : null,
                ),
              ),
            ),
          ],
        ),
        if (_durationError != null) ...[
          const SizedBox(height: 8),
          Text(_durationError!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        ],
      ],
    );
  }

  Widget _buildEndTimeExplanation(ThemeData theme) {
    final start = _startTime;
    final minutes = _durationMinutes;
    if (start == null || minutes == null || minutes <= 0) {
      return Text(
        'Set a start time and duration first to see what this means.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
      );
    }
    final naturalEnd = _naturalEndTime()!;
    final naturalEndLabel = _formatTimeWithPeriod(naturalEnd);
    final durationLabel = formatDurationLabel(minutes);
    final startLabel = _formatTimeWithPeriod(start);

    if (!_hardStopEnabled || _endTime == null) {
      return Text(
        'No hard stop — the pump runs the full $durationLabel, starting $startLabel, and turns off '
        'automatically at $naturalEndLabel.',
        style: theme.textTheme.bodySmall,
      );
    }

    final endLabel = _formatTimeWithPeriod(_endTime!);
    if (_hardStopIsEarly) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This may cut the run short. It\'s set to run $durationLabel (until $naturalEndLabel), but will '
                'always be forced off at $endLabel instead — even if it had to pause and resume partway through.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      'Safety cutoff at $endLabel. Normally the pump finishes its full $durationLabel by $naturalEndLabel, well '
      'before this cutoff — so it only matters if something delays the run (like a power cut) and it\'s still '
      'going at $endLabel.',
      style: theme.textTheme.bodySmall,
    );
  }

  Widget _buildEndTimeStep(ThemeData theme) {
    return Column(
      key: const ValueKey('step-end'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Need a hard stop time?', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Optional. This is a safety cutoff, not the normal end time.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _hardStopEnabled,
          onChanged: _setHardStopEnabled,
          title: const Text('Set a hard stop time'),
        ),
        if (_hardStopEnabled) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _pickHardStopTime,
            icon: const Icon(Icons.schedule, size: 18),
            label: Text(_endTime != null ? _formatTimeWithPeriod(_endTime!) : 'Select time'),
            style: _endTimeError != null
                ? OutlinedButton.styleFrom(side: BorderSide(color: theme.colorScheme.error))
                : null,
          ),
          if (_endTimeError != null) ...[
            const SizedBox(height: 8),
            Text(_endTimeError!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ],
        ],
        const SizedBox(height: 12),
        _buildEndTimeExplanation(theme),
      ],
    );
  }

  Widget _buildNameStep(ThemeData theme) {
    return Column(
      key: const ValueKey('step-name'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Give it a name', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'We suggested one based on your schedule — feel free to change it.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: 'Schedule Name', isDense: true, errorText: _nameError),
        ),
      ],
    );
  }

  Widget _summaryRow(
    ThemeData theme, {
    required String label,
    required String value,
    required VoidCallback onEdit,
    bool warning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (warning) ...[
                      Icon(Icons.warning_amber_rounded, size: 16, color: theme.colorScheme.error),
                      const SizedBox(width: 6),
                    ],
                    Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Edit')),
        ],
      ),
    );
  }

  Widget _buildSummaryStep(ThemeData theme) {
    final minutes = _durationMinutes;
    final naturalEnd = _naturalEndTime();
    final endTimeValue = _hardStopEnabled && _endTime != null
        ? 'Hard stop at ${_formatTimeWithPeriod(_endTime!)}'
        : (naturalEnd != null ? 'No hard stop — stops automatically at ${_formatTimeWithPeriod(naturalEnd)}' : 'Not set');

    return Column(
      key: const ValueKey('step-summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Review & save', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _summaryRow(theme, label: 'Days', value: _daysSummary, onEdit: () => _editStep(0)),
        _summaryRow(
          theme,
          label: 'Start time',
          value: _startTime != null ? _formatTimeWithPeriod(_startTime!) : 'Not set',
          onEdit: () => _editStep(1),
        ),
        _summaryRow(
          theme,
          label: 'Duration',
          value: minutes != null && minutes > 0 ? formatDurationLabel(minutes) : 'Not set',
          onEdit: () => _editStep(2),
        ),
        _summaryRow(
          theme,
          label: 'End time',
          value: endTimeValue,
          onEdit: () => _editStep(3),
          warning: _hardStopEnabled && _hardStopIsEarly,
        ),
        _summaryRow(theme, label: 'Name', value: _nameController.text.trim(), onEdit: () => _editStep(4)),
      ],
    );
  }

  Widget _buildStep(ThemeData theme) {
    switch (_currentStep) {
      case 0:
        return _buildDaysStep(theme);
      case 1:
        return _buildStartTimeStep(theme);
      case 2:
        return _buildDurationStep(theme);
      case 3:
        return _buildEndTimeStep(theme);
      case 4:
        return _buildNameStep(theme);
      default:
        return _buildSummaryStep(theme);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing != null ? 'Edit Schedule' : 'New Schedule',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Step ${_currentStep + 1} of 6 · ${_stepTitles[_currentStep]}',
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: (_currentStep + 1) / 6, minHeight: 4),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildStep(theme),
            ),
            if (_overlapError != null) ...[
              const SizedBox(height: 16),
              _errorBanner(theme, _overlapError!),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (_currentStep > 0 || _editingStepReturnTarget != null)
                  TextButton(onPressed: _goBack, child: const Text('Back')),
                const Spacer(),
                FilledButton(
                  onPressed: _currentStep == 5 ? _save : _advance,
                  child: Text(_primaryButtonLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
