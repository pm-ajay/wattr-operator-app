import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/schedule.dart';

Future<bool> showScheduleFormSheet(
  BuildContext context, {
  required String pumpId,
  Schedule? existing,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ScheduleFormContent(pumpId: pumpId, existing: existing),
    ),
  );
  return result ?? false;
}

class _ScheduleFormContent extends ConsumerStatefulWidget {
  const _ScheduleFormContent({required this.pumpId, this.existing});

  final String pumpId;
  final Schedule? existing;

  @override
  ConsumerState<_ScheduleFormContent> createState() => _ScheduleFormContentState();
}

class _ScheduleFormContentState extends ConsumerState<_ScheduleFormContent> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _durationController =
      TextEditingController(text: (widget.existing?.duration.inMinutes ?? 20).toString());
  late final Set<int> _days = {...(widget.existing?.repeatDays ?? const {1, 2, 3, 4, 5, 6, 7})};
  late TimeOfDay _startTime = widget.existing?.startTime ?? const TimeOfDay(hour: 6, minute: 0);

  String? _nameError;
  String? _daysError;
  String? _durationError;
  String? _overlapError;

  static const _dayLabels = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  TimeOfDay get _endTime {
    final minutes = int.tryParse(_durationController.text) ?? 0;
    final total = (_startTime.hour * 60 + _startTime.minute + minutes) % (24 * 60);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  void _save() {
    final name = _nameController.text.trim();
    final duration = int.tryParse(_durationController.text);

    setState(() {
      _nameError = name.isEmpty ? 'Enter a schedule name' : null;
      _daysError = _days.isEmpty ? 'Select at least one day' : null;
      _durationError = (duration == null || duration <= 0) ? 'Enter minutes greater than 0' : null;
      _overlapError = null;
    });
    if (_nameError != null || _daysError != null || _durationError != null) return;

    final candidate = Schedule(
      id: widget.existing?.id ?? 'sched_${DateTime.now().microsecondsSinceEpoch}',
      pumpId: widget.pumpId,
      name: name,
      repeatDays: _days,
      startTime: _startTime,
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
                      OutlinedButton(
                        onPressed: _pickStartTime,
                        child: Text(_formatTime(_startTime)),
                      ),
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
              'End Time (auto-calculated): ${_formatTime(_endTime)}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
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
