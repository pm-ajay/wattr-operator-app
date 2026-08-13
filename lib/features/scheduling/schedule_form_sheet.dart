import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/schedule.dart';

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
  late final _durationController = TextEditingController(
    text: widget.existing?.duration.inMinutes.toString() ?? widget.initialDurationMinutes?.toString() ?? '',
  );
  late final Set<int> _days = {...(widget.existing?.repeatDays ?? const <int>{})};

  // Nothing is pre-picked for a new schedule — the operator must explicitly
  // choose a start time rather than silently inherit a default that could
  // be saved without noticing.
  TimeOfDay? _startTime;

  // Optional, hidden by default — most schedules just use Duration. Expanding
  // this and picking a time re-derives Duration from (end - start) once;
  // it isn't a live two-way link back to the model.
  bool _endTimeExpanded = false;

  String? _nameError;
  String? _daysError;
  String? _startTimeError;
  String? _durationError;
  String? _overlapError;

  static const _dayLabels = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

  @override
  void initState() {
    super.initState();
    _startTime = widget.existing?.startTime;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime ?? TimeOfDay.now());
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _startTimeError = null;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final start = _startTime;
    if (start == null) return;
    final picked = await showTimePicker(context: context, initialTime: _endTime ?? start);
    if (picked == null) return;
    final startMinutes = start.hour * 60 + start.minute;
    final pickedMinutes = picked.hour * 60 + picked.minute;
    var diff = pickedMinutes - startMinutes;
    if (diff <= 0) diff += 24 * 60;
    setState(() {
      _durationController.text = diff.toString();
      _durationError = null;
    });
  }

  TimeOfDay? get _endTime {
    final start = _startTime;
    final minutes = int.tryParse(_durationController.text);
    if (start == null || minutes == null) return null;
    final total = (start.hour * 60 + start.minute + minutes) % (24 * 60);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  String _formatTimeWithPeriod(TimeOfDay t) => '${_timeOfDayLabel(t)} · ${_formatTime(t)}';

  void _save() {
    final name = _nameController.text.trim();
    final duration = int.tryParse(_durationController.text);
    final startTime = _startTime;

    setState(() {
      _nameError = name.isEmpty ? 'Enter a schedule name' : null;
      _daysError = _days.isEmpty ? 'Select at least one day' : null;
      _startTimeError = startTime == null ? 'Select a start time' : null;
      _durationError = (duration == null || duration <= 0) ? 'Enter minutes greater than 0' : null;
      _overlapError = null;
    });
    if (_nameError != null || _daysError != null || _startTimeError != null || _durationError != null) return;

    final candidate = Schedule(
      id: widget.existing?.id ?? 'sched_${DateTime.now().microsecondsSinceEpoch}',
      pumpId: widget.pumpId,
      name: name,
      repeatDays: _days,
      startTime: startTime!,
      duration: Duration(minutes: duration!),
      active: widget.existing?.active ?? true,
    );

    final conflict = ref
        .read(schedulesProvider.notifier)
        .findOverlap(candidate, excludingId: widget.existing?.id);
    if (conflict != null) {
      setState(() {
        _overlapError =
            'Overlaps with "${conflict.name}" (${conflict.repeatSummary}, ${conflict.timeRangeLabel}). Adjust the days or time and try again.';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startTime = _startTime;
    final endTime = _endTime;

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
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Schedule Name',
                isDense: true,
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 16),
            Text('Repeat Days', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _dayLabels.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _days.contains(entry.key),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _days.add(entry.key);
                      } else {
                        _days.remove(entry.key);
                      }
                    }),
                  ),
              ],
            ),
            if (_daysError != null) ...[
              const SizedBox(height: 4),
              Text(_daysError!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start Time', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: _pickStartTime,
                        icon: const Icon(Icons.schedule, size: 18),
                        label: Text(startTime != null ? _formatTimeWithPeriod(startTime) : 'Select time'),
                        style: _startTimeError != null
                            ? OutlinedButton.styleFrom(side: BorderSide(color: theme.colorScheme.error))
                            : null,
                      ),
                      if (_startTimeError != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _startTimeError!,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Duration',
                      suffixText: 'min',
                      isDense: true,
                      errorText: _durationError,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              endTime != null
                  ? 'End Time (auto-calculated): ${_formatTimeWithPeriod(endTime)}'
                  : 'End Time: set a start time and duration first',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            if (startTime != null)
              if (!_endTimeExpanded)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _endTimeExpanded = true),
                    child: const Text('Set a specific end time instead'),
                  ),
                )
              else ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('End Time', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: _pickEndTime,
                            icon: const Icon(Icons.schedule, size: 18),
                            label: Text(endTime != null ? _formatTimeWithPeriod(endTime) : 'Select time'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 28),
                        child: TextButton.icon(
                          onPressed: () => setState(() => _endTimeExpanded = false),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Hide'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            if (_overlapError != null) ...[
              const SizedBox(height: 16),
              Container(
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
                      child: Text(
                        _overlapError!,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(widget.existing != null ? 'Save Changes' : 'Add Schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
